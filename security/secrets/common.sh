# Shared helpers for the local OpenBao install. Source this; do not execute it.

NAMESPACE="security-secrets"
EXPECTED_CONTEXT="rancher-desktop"
OPENBAO_CHART_VERSION="0.30.1"
ESO_CHART_VERSION="2.11.0"
LOCAL_PORT=18200
PID_FILE="${TMPDIR:-/tmp}/security-secrets-port-forward.pid"
LOG_FILE="${TMPDIR:-/tmp}/security-secrets-port-forward.log"
INIT_FILE="${ROOT}/.bao-init.json"
POD="openbao-0"

require_tools() {
  local cmd
  for cmd in kubectl helm python3; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      echo "${cmd} is required." >&2
      exit 1
    fi
  done
}

require_context() {
  local context
  context="$(kubectl config current-context)"
  if [[ "$context" != "$EXPECTED_CONTEXT" ]]; then
    echo "Current kubectl context is '${context}'. Expected '${EXPECTED_CONTEXT}'." >&2
    exit 1
  fi
}

stop_port_forward() {
  if [[ -f "$PID_FILE" ]]; then
    local pid
    pid="$(cat "$PID_FILE")"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null || true
    fi
    rm -f "$PID_FILE"
  fi
  local existing
  existing="$(pgrep -f "kubectl -n ${NAMESPACE} port-forward " || true)"
  if [[ -n "$existing" ]]; then
    # shellcheck disable=SC2086
    kill $existing 2>/dev/null || true
  fi
}

root_token() {
  if [[ ! -f "$INIT_FILE" ]]; then
    echo "Missing ${INIT_FILE}. Start OpenBao first: bash security/secrets/start.sh" >&2
    exit 1
  fi
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["root_token"])' "$INIT_FILE"
}

unseal_key() {
  python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["unseal_keys_b64"][0])' "$INIT_FILE"
}

# bao status exits 2 while sealed. Callers must tolerate that.
bao_status_json() {
  kubectl -n "$NAMESPACE" exec "$POD" -- \
    env BAO_ADDR="http://127.0.0.1:8200" \
    bao status -format=json 2>/dev/null || true
}

bao_field() {
  local json="$1"
  local field="$2"
  python3 -c 'import json,sys
raw = sys.argv[1].strip()
start = raw.find("{")
end = raw.rfind("}")
if start < 0 or end < start:
    sys.exit(2)
print(json.loads(raw[start:end + 1])[sys.argv[2]])' "$json" "$field"
}

bao_exec() {
  kubectl -n "$NAMESPACE" exec "$POD" -- \
    env BAO_ADDR="http://127.0.0.1:8200" BAO_TOKEN="$(root_token)" \
        VAULT_ADDR="http://127.0.0.1:8200" VAULT_TOKEN="$(root_token)" \
    bao "$@"
}

wait_for_running_pod() {
  local _ running waiting crashes=0
  for _ in $(seq 1 90); do
    running="$(kubectl -n "$NAMESPACE" get pod "$POD" -o jsonpath='{.status.containerStatuses[0].state.running.startedAt}' 2>/dev/null || true)"
    waiting="$(kubectl -n "$NAMESPACE" get pod "$POD" -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || true)"
    if [[ -n "$running" ]]; then
      sleep 3
      waiting="$(kubectl -n "$NAMESPACE" get pod "$POD" -o jsonpath='{.status.containerStatuses[0].state.waiting.reason}' 2>/dev/null || true)"
      if [[ "$waiting" != "CrashLoopBackOff" ]]; then
        return 0
      fi
    fi
    if [[ "$waiting" == "CrashLoopBackOff" ]]; then
      crashes=$((crashes + 1))
      if [[ "$crashes" -ge 15 ]]; then
        echo "OpenBao is crash-looping. Recent logs:" >&2
        kubectl -n "$NAMESPACE" logs "$POD" --tail=40 >&2 || true
        exit 1
      fi
    else
      crashes=0
    fi
    sleep 2
  done
  echo "OpenBao pod ${POD} did not start." >&2
  kubectl -n "$NAMESPACE" get pods >&2 || true
  kubectl -n "$NAMESPACE" logs "$POD" --tail=40 >&2 || true
  exit 1
}

ensure_initialized_and_unsealed() {
  local status initialized sealed
  status=""
  local _
  for _ in $(seq 1 60); do
    status="$(bao_status_json)"
    if initialized="$(bao_field "$status" initialized 2>/dev/null)"; then
      break
    fi
    status=""
    sleep 2
  done
  if [[ -z "$status" ]]; then
    echo "OpenBao did not answer bao status." >&2
    exit 1
  fi
  if [[ "$initialized" != "True" ]]; then
    echo "==> Initializing OpenBao"
    local json
    json="$(kubectl -n "$NAMESPACE" exec "$POD" -- \
      env BAO_ADDR="http://127.0.0.1:8200" \
      bao operator init -key-shares=1 -key-threshold=1 -format=json)"
    umask 077
    printf '%s\n' "$json" >"$INIT_FILE"
    echo "Unseal key and root token written to ${INIT_FILE}"
  elif [[ ! -f "$INIT_FILE" ]]; then
    echo "OpenBao is already initialized, but ${INIT_FILE} is missing." >&2
    echo "Restore that file, or run cleanup.sh and start again." >&2
    exit 1
  fi

  status="$(bao_status_json)"
  sealed="$(bao_field "$status" sealed)"
  if [[ "$sealed" == "True" ]]; then
    echo "==> Unsealing OpenBao"
    kubectl -n "$NAMESPACE" exec "$POD" -- \
      env BAO_ADDR="http://127.0.0.1:8200" \
      bao operator unseal "$(unseal_key)" >/dev/null
  fi
}

configure_kubernetes_auth() {
  echo "==> Configuring Kubernetes auth and the External Secrets policy"
  if ! bao_exec secrets list -format=json | python3 -c 'import json,sys; raise SystemExit(0 if "secret/" in json.load(sys.stdin) else 1)'; then
    bao_exec secrets enable -path=secret kv-v2
  fi
  if ! bao_exec auth list -format=json | python3 -c 'import json,sys; raise SystemExit(0 if "kubernetes/" in json.load(sys.stdin) else 1)'; then
    bao_exec auth enable kubernetes
  fi

  kubectl -n "$NAMESPACE" exec "$POD" -- \
    env BAO_ADDR="http://127.0.0.1:8200" BAO_TOKEN="$(root_token)" \
        VAULT_ADDR="http://127.0.0.1:8200" VAULT_TOKEN="$(root_token)" \
    sh -c 'bao write auth/kubernetes/config \
      kubernetes_host="https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}" \
      kubernetes_ca_cert=@/var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
      disable_iss_validation=true'

  kubectl -n "$NAMESPACE" exec -i "$POD" -- \
    env BAO_ADDR="http://127.0.0.1:8200" BAO_TOKEN="$(root_token)" \
        VAULT_ADDR="http://127.0.0.1:8200" VAULT_TOKEN="$(root_token)" \
    bao policy write eso-reader - <<'EOF'
path "secret/data/*" {
  capabilities = ["read"]
}
path "secret/metadata/*" {
  capabilities = ["read", "list"]
}
EOF

  bao_exec write auth/kubernetes/role/external-secrets \
    bound_service_account_names=external-secrets \
    bound_service_account_namespaces="$NAMESPACE" \
    policies=eso-reader \
    audience=vault \
    ttl=1h
}
