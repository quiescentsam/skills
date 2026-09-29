#!/usr/bin/env bash
# Install, start, and stop Jarvis Registry on local Kubernetes.
# Usage:
#   bash registry/jarvis/setup.sh install
#   bash registry/jarvis/setup.sh start
#   bash registry/jarvis/setup.sh stop
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
RELEASE="jarvis-registry"
NAMESPACE="jarvis"
OPERATOR_RELEASE="community-operator"
OPERATOR_NAMESPACE="mongodb-operator"
OPERATOR_CHART="mongodb/community-operator"
OPERATOR_VERSION="${JARVIS_MONGODB_OPERATOR_VERSION:-0.13.0}"
EXPECTED_CONTEXT="rancher-desktop"
CHART="oci://ghcr.io/ascending-llc/jarvis-chart/jarvis-registry"
# Pin recorded at first install. Override with JARVIS_CHART_VERSION.
CHART_VERSION="${JARVIS_CHART_VERSION:-0.2.4}"
SECRET_NAME="registry-env"
PID_FILE="${TMPDIR:-/tmp}/jarvis-port-forward.pid"
LOG_FILE="${TMPDIR:-/tmp}/jarvis-port-forward.log"
# Local ports. 18080 is often taken by an existing SSH tunnel on this machine.
# The in-cluster services stay on 80 / 7860 / 8888.
UI_PORT=19080
BACKEND_PORT=17860
AUTH_PORT=18888

usage() {
  cat <<EOF
Usage: bash registry/jarvis/setup.sh <install|start|stop>

  install  Helm-install the chart into namespace ${NAMESPACE}
  start    Scale the registry up and port-forward the UI (${UI_PORT})
  stop     Stop the port-forward and scale the registry to zero
EOF
}

require_kubectl() {
  if ! command -v kubectl >/dev/null 2>&1; then
    echo "kubectl is required." >&2
    exit 1
  fi
}

require_helm() {
  if ! command -v helm >/dev/null 2>&1; then
    echo "helm is required." >&2
    exit 1
  fi
}

require_openssl() {
  if ! command -v openssl >/dev/null 2>&1; then
    echo "openssl is required." >&2
    exit 1
  fi
}

require_context() {
  local context
  context="$(kubectl config current-context)"
  if [[ "$context" != "$EXPECTED_CONTEXT" ]]; then
    echo "Current kubectl context is '${context}'. Expected '${EXPECTED_CONTEXT}'." >&2
    echo "Switch context, or set the cluster you intend, then re-run." >&2
    exit 1
  fi
}

release_installed() {
  helm status "$RELEASE" -n "$NAMESPACE" >/dev/null 2>&1
}

operator_deploy_name() {
  kubectl -n "$OPERATOR_NAMESPACE" get deploy \
    -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true
}

install_operator() {
  echo "==> Installing MongoDB Community Operator ${OPERATOR_VERSION}"
  helm repo add mongodb https://mongodb.github.io/helm-charts >/dev/null
  helm repo update mongodb >/dev/null
  helm upgrade --install "$OPERATOR_RELEASE" "$OPERATOR_CHART" \
    --version "$OPERATOR_VERSION" \
    --namespace "$OPERATOR_NAMESPACE" \
    --create-namespace \
    --set operator.watchNamespace='*' \
    --set database.namespace="$NAMESPACE" \
    --wait \
    --timeout 10m
}

ensure_namespace() {
  kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
}

ensure_secret() {
  if kubectl -n "$NAMESPACE" get secret "$SECRET_NAME" >/dev/null 2>&1; then
    echo "==> Secret ${SECRET_NAME} already exists"
    return 0
  fi

  echo "==> Creating ${SECRET_NAME} with generated local keys"
  local tmp mongo_password admin_password secret_key creds_key client_secret weaviate_key
  tmp="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN

  mongo_password="$(openssl rand -hex 24)"
  admin_password="$(openssl rand -hex 16)"
  secret_key="$(openssl rand -base64 64 | tr -d '\n')"
  creds_key="$(openssl rand -hex 32)"
  client_secret="$(openssl rand -hex 32)"
  weaviate_key="$(openssl rand -hex 24)"

  openssl genpkey -algorithm RSA -pkeyopt rsa_keygen_bits:2048 -out "${tmp}/jwt-private.pem" >/dev/null 2>&1
  openssl pkey -in "${tmp}/jwt-private.pem" -pubout -out "${tmp}/jwt-public.pem" >/dev/null 2>&1

  kubectl -n "$NAMESPACE" create secret generic "$SECRET_NAME" \
    --from-literal=DEPLOYMENT_ENVIRONMENT=local \
    --from-literal=ADMIN_USER=admin \
    --from-literal=ADMIN_PASSWORD="$admin_password" \
    --from-literal=SECRET_KEY="$secret_key" \
    --from-literal=CREDS_KEY="$creds_key" \
    --from-literal=REGISTRY_CLIENT_SECRET="$client_secret" \
    --from-literal=REGISTRY_APP_NAME=registry-client \
    --from-literal=REGISTRY_URL="http://127.0.0.1:${BACKEND_PORT}" \
    --from-literal=REGISTRY_CLIENT_URL="http://127.0.0.1:${UI_PORT}" \
    --from-literal=AUTH_SERVER_URL=http://auth-server:8888 \
    --from-literal=AUTH_SERVER_EXTERNAL_URL="http://127.0.0.1:${AUTH_PORT}" \
    --from-literal=AUTH_PROVIDER=keycloak \
    --from-literal=KEYCLOAK_URL=http://keycloak.jarvis.svc.cluster.local:8080 \
    --from-literal=KEYCLOAK_EXTERNAL_URL="http://127.0.0.1:${UI_PORT}" \
    --from-literal=KEYCLOAK_REALM=mcp-gateway \
    --from-literal=KEYCLOAK_CLIENT_ID=mcp-gateway-m2m \
    --from-literal=KEYCLOAK_CLIENT_SECRET="$client_secret" \
    --from-literal=KEYCLOAK_M2M_CLIENT_ID=mcp-gateway-m2m \
    --from-literal=KEYCLOAK_M2M_CLIENT_SECRET="$client_secret" \
    --from-literal=JWT_AUDIENCE=jarvis-services \
    --from-literal=JWT_SELF_SIGNED_KID=self-signed-key-v1 \
    --from-file=JWT_PRIVATE_KEY="${tmp}/jwt-private.pem" \
    --from-file=JWT_PUBLIC_KEY="${tmp}/jwt-public.pem" \
    --from-literal=SESSION_COOKIE_SECURE=false \
    --from-literal=MONGODB_ADMIN_PASSWORD="$mongo_password" \
    --from-literal=MONGO_URI="mongodb://mongodb-admin:${mongo_password}@mongodb-svc:27017/jarvis?authSource=admin&replicaSet=mongodb&authMechanism=SCRAM-SHA-256" \
    --from-literal=REDIS_URI=redis://redis:6379/1 \
    --from-literal=REDIS_KEY_PREFIX=jarvis-registry \
    --from-literal=AUTH_SERVER_REDIS_KEY_PREFIX=jarvis-auth-server \
    --from-literal=WEAVIATE_HOST=jarvis-registry-weaviate \
    --from-literal=WEAVIATE_PORT=8080 \
    --from-literal=WEAVIATE_API_KEY="$weaviate_key" \
    --from-literal=VECTOR_STORE_TYPE=weaviate \
    --from-literal=TOOL_DISCOVERY_MODE=external \
    --from-literal=LOCAL_EMBEDDINGS_MODEL_NAME=all-MiniLM-L6-v2 \
    --from-literal=LOCAL_EMBEDDINGS_MODEL_DIMENSIONS=384 \
    --from-literal=RERANK_ENABLED=false \
    --from-literal=PERSISTENCE_DATA_PATH=/var/lib/weaviate \
    --from-literal=QUERY_DEFAULTS_LIMIT=25 \
    --from-literal=DEFAULT_VECTORIZER_MODULE=none \
    --from-literal=AUTHENTICATION_ANONYMOUS_ACCESS_ENABLED=false \
    --from-literal=AUTHENTICATION_APIKEY_ENABLED=true \
    --from-literal=AUTHENTICATION_APIKEY_ALLOWED_KEYS="$weaviate_key" \
    --from-literal=AUTHENTICATION_APIKEY_USERS=admin \
    --from-literal=AUTHORIZATION_ADMINLIST_ENABLED=true \
    --from-literal=AUTHORIZATION_ADMINLIST_USERS=admin \
    --from-literal=ENABLE_AUTO_SCHEMA=true \
    --from-literal=LOG_LEVEL=info \
    --from-literal=MCPGW_ENABLE_DNS_REBINDING_PROTECTION=true \
    --from-literal=MCPGW_ALLOWED_HOSTS="127.0.0.1,127.0.0.1:*,localhost,localhost:*,[::1],[::1]:*" \
    --from-literal=MCPGW_ALLOWED_ORIGINS="http://127.0.0.1,http://127.0.0.1:*,http://localhost,http://localhost:*,http://[::1],http://[::1]:*" \
    --from-literal=WORKFLOW_WORKER_MAX_SLEEP_SECONDS=30 \
    --from-literal=WORKFLOW_WORKER_MAX_CONCURRENT_RUNS=1 \
    --from-literal=WORKFLOW_WORKER_MAX_CLAIMED_RUNS=2 \
    --from-literal=WORKFLOW_WORKER_LEASE_DURATION_SECONDS=300

  echo "Admin user: admin"
  echo "Read the generated admin password with:"
  echo "  kubectl -n ${NAMESPACE} get secret ${SECRET_NAME} -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 -d; echo"
}

install_registry() {
  require_kubectl
  require_helm
  require_openssl
  require_context

  install_operator
  ensure_namespace
  ensure_secret

  echo "==> Installing ${RELEASE} ${CHART_VERSION} into namespace ${NAMESPACE}"
  helm upgrade --install "$RELEASE" "$CHART" \
    --version "$CHART_VERSION" \
    --namespace "$NAMESPACE" \
    --create-namespace \
    --values "${ROOT}/values.yaml" \
    --wait \
    --timeout 15m

  echo "==> Waiting for pods"
  kubectl -n "$NAMESPACE" rollout status deploy/jarvis-registry-backend --timeout=15m
  kubectl -n "$NAMESPACE" rollout status deploy/jarvis-registry-frontend --timeout=10m
  kubectl -n "$NAMESPACE" rollout status deploy/jarvis-registry-auth-server --timeout=10m
  kubectl -n "$NAMESPACE" rollout status sts/jarvis-registry-redis --timeout=10m
  kubectl -n "$NAMESPACE" rollout status sts/jarvis-registry-weaviate --timeout=10m
  kubectl -n "$NAMESPACE" rollout status sts/mongodb --timeout=15m
  kubectl -n "$NAMESPACE" get pods
}

scale_operator() {
  local replicas="$1"
  local name
  name="$(operator_deploy_name)"
  if [[ -z "$name" ]]; then
    return 0
  fi
  kubectl -n "$OPERATOR_NAMESPACE" scale "deploy/${name}" --replicas="$replicas"
  if [[ "$replicas" != "0" ]]; then
    kubectl -n "$OPERATOR_NAMESPACE" rollout status "deploy/${name}" --timeout=5m
  fi
}

scale_workloads() {
  local replicas="$1"
  local deploy name
  local deploys=(
    jarvis-registry-backend
    jarvis-registry-frontend
    jarvis-registry-auth-server
    jarvis-registry-workflow-worker
    jarvis-registry-reloader
  )
  local statefulsets=(
    jarvis-registry-redis
    jarvis-registry-weaviate
    mongodb
  )

  if [[ "$replicas" == "0" ]]; then
    for deploy in "${deploys[@]}"; do
      if kubectl -n "$NAMESPACE" get "deploy/${deploy}" >/dev/null 2>&1; then
        kubectl -n "$NAMESPACE" scale "deploy/${deploy}" --replicas=0
      fi
    done
    for name in "${statefulsets[@]}"; do
      if kubectl -n "$NAMESPACE" get "sts/${name}" >/dev/null 2>&1; then
        kubectl -n "$NAMESPACE" scale "sts/${name}" --replicas=0
      fi
    done
    # The operator reconciles MongoDB back to one member. Stop it after the
    # StatefulSet is scaled down so the replica stays at zero.
    scale_operator 0
    if kubectl -n "$NAMESPACE" get sts/mongodb >/dev/null 2>&1; then
      kubectl -n "$NAMESPACE" scale sts/mongodb --replicas=0
    fi
    return 0
  fi

  scale_operator 1
  for name in "${statefulsets[@]}"; do
    if kubectl -n "$NAMESPACE" get "sts/${name}" >/dev/null 2>&1; then
      kubectl -n "$NAMESPACE" scale "sts/${name}" --replicas=1
    fi
  done
  for deploy in "${deploys[@]}"; do
    if kubectl -n "$NAMESPACE" get "deploy/${deploy}" >/dev/null 2>&1; then
      kubectl -n "$NAMESPACE" scale "deploy/${deploy}" --replicas=1
    fi
  done

  if kubectl -n "$NAMESPACE" get sts/mongodb >/dev/null 2>&1; then
    kubectl -n "$NAMESPACE" rollout status sts/mongodb --timeout=15m
  fi
  kubectl -n "$NAMESPACE" rollout status sts/jarvis-registry-redis --timeout=10m
  kubectl -n "$NAMESPACE" rollout status sts/jarvis-registry-weaviate --timeout=10m
  kubectl -n "$NAMESPACE" rollout status deploy/jarvis-registry-backend --timeout=15m
  kubectl -n "$NAMESPACE" rollout status deploy/jarvis-registry-frontend --timeout=10m
  kubectl -n "$NAMESPACE" rollout status deploy/jarvis-registry-auth-server --timeout=10m
}

port_forward_pids() {
  pgrep -f "kubectl -n ${NAMESPACE} port-forward " || true
}

require_local_port() {
  local port="$1"
  if lsof -nP -iTCP:"${port}" -sTCP:LISTEN >/dev/null 2>&1; then
    echo "Local port ${port} is already in use." >&2
    exit 1
  fi
}

start_port_forward() {
  local existing
  existing="$(port_forward_pids)"
  if [[ -n "$existing" ]]; then
    echo "Port-forward already running (pid ${existing//$'\n'/, })"
    return 0
  fi

  require_local_port "$UI_PORT"
  require_local_port "$BACKEND_PORT"
  require_local_port "$AUTH_PORT"

  echo "==> Port-forwarding UI ${UI_PORT}, backend ${BACKEND_PORT}, auth ${AUTH_PORT}"
  : >"$PID_FILE"
  nohup kubectl -n "$NAMESPACE" port-forward --address 127.0.0.1 svc/registry-frontend "${UI_PORT}:80" \
    >"$LOG_FILE" 2>&1 &
  echo $! >>"$PID_FILE"
  nohup kubectl -n "$NAMESPACE" port-forward --address 127.0.0.1 svc/registry-backend "${BACKEND_PORT}:7860" \
    >>"$LOG_FILE" 2>&1 &
  echo $! >>"$PID_FILE"
  nohup kubectl -n "$NAMESPACE" port-forward --address 127.0.0.1 svc/auth-server "${AUTH_PORT}:8888" \
    >>"$LOG_FILE" 2>&1 &
  echo $! >>"$PID_FILE"

  local _
  for _ in $(seq 1 40); do
    if curl -sf -o /dev/null "http://127.0.0.1:${UI_PORT}/"; then
      return 0
    fi
    sleep 0.5
  done

  echo "Port-forward did not become ready. See ${LOG_FILE}" >&2
  exit 1
}

stop_port_forward() {
  local pid
  if [[ -f "$PID_FILE" ]]; then
    while IFS= read -r pid; do
      if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        kill "$pid" 2>/dev/null || true
      fi
    done <"$PID_FILE"
    rm -f "$PID_FILE"
  fi

  local existing
  existing="$(port_forward_pids)"
  if [[ -n "$existing" ]]; then
    # shellcheck disable=SC2086
    kill $existing 2>/dev/null || true
  fi
}

cmd_install() {
  install_registry
  echo ""
  echo "Registry is installed in namespace ${NAMESPACE}."
  echo "Start it with:"
  echo "  bash registry/jarvis/setup.sh start"
}

cmd_start() {
  require_kubectl
  require_helm
  require_openssl
  require_context

  if ! release_installed; then
    install_registry
  else
    echo "==> Starting ${RELEASE} in namespace ${NAMESPACE}"
    scale_workloads 1
    kubectl -n "$NAMESPACE" get pods
  fi

  start_port_forward
  echo ""
  echo "Registry is up: http://localhost:${UI_PORT}"
  echo "Backend: http://localhost:${BACKEND_PORT}"
  echo "Auth server: http://localhost:${AUTH_PORT}"
  echo "Stop it with:"
  echo "  bash registry/jarvis/setup.sh stop"
}

cmd_stop() {
  require_kubectl
  require_context

  echo "==> Stopping port-forward"
  stop_port_forward

  if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1 && release_installed; then
    echo "==> Scaling ${RELEASE} to zero"
    scale_workloads 0
  fi

  echo "Registry is stopped. The Helm release and data volumes are still in ${NAMESPACE}."
  echo "Start it again with:"
  echo "  bash registry/jarvis/setup.sh start"
}

case "${1:-install}" in
  install) cmd_install ;;
  start) cmd_start ;;
  stop) cmd_stop ;;
  -h|--help|help) usage ;;
  *)
    usage >&2
    exit 1
    ;;
esac
