#!/usr/bin/env bash
# Install or start OpenBao and External Secrets, then port-forward the UI.
#   bash security/secrets/start.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "${ROOT}/common.sh"

require_tools
require_context

if ! helm repo list -o json | python3 -c 'import json,sys; raise SystemExit(0 if any(r.get("name")=="openbao" for r in json.load(sys.stdin)) else 1)'; then
  helm repo add openbao https://openbao.github.io/openbao-helm
fi
if ! helm repo list -o json | python3 -c 'import json,sys; raise SystemExit(0 if any(r.get("name")=="external-secrets" for r in json.load(sys.stdin)) else 1)'; then
  helm repo add external-secrets https://charts.external-secrets.io
fi
helm repo update openbao external-secrets

echo "==> Installing OpenBao ${OPENBAO_CHART_VERSION} in namespace ${NAMESPACE}"
helm upgrade --install openbao openbao/openbao \
  --version "$OPENBAO_CHART_VERSION" \
  --namespace "$NAMESPACE" \
  --create-namespace \
  --values "${ROOT}/values.yaml" \
  --timeout 10m

# A not-ready pod counts against the StatefulSet rolling-update budget, so a
# crash-looping pod will not replace itself. Delete it when its revision lags.
for _ in $(seq 1 20); do
  if ! kubectl -n "$NAMESPACE" get pod "$POD" >/dev/null 2>&1; then
    break
  fi
  update_rev="$(kubectl -n "$NAMESPACE" get sts openbao -o jsonpath='{.status.updateRevision}' 2>/dev/null || true)"
  pod_rev="$(kubectl -n "$NAMESPACE" get pod "$POD" -o jsonpath='{.metadata.labels.controller-revision-hash}' 2>/dev/null || true)"
  if [[ -n "$update_rev" && "$pod_rev" == "$update_rev" ]]; then
    break
  fi
  if [[ -n "$update_rev" && -n "$pod_rev" && "$pod_rev" != "$update_rev" ]]; then
    echo "==> Replacing OpenBao pod so it picks up the current config"
    kubectl -n "$NAMESPACE" delete pod "$POD" --wait=false
    break
  fi
  sleep 1
done

wait_for_running_pod
ensure_initialized_and_unsealed
kubectl -n "$NAMESPACE" rollout status "statefulset/openbao" --timeout=5m
configure_kubernetes_auth

echo "==> Installing External Secrets ${ESO_CHART_VERSION}"
helm upgrade --install external-secrets external-secrets/external-secrets \
  --version "$ESO_CHART_VERSION" \
  --namespace "$NAMESPACE" \
  --set fullnameOverride=external-secrets \
  --set serviceAccount.name=external-secrets \
  --wait \
  --timeout 10m

kubectl apply -f "${ROOT}/cluster-secret-store.yaml"
kubectl wait --for=condition=Ready clustersecretstore/openbao --timeout=3m

if lsof -nP -iTCP:"${LOCAL_PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Local port ${LOCAL_PORT} is already in use." >&2
  exit 1
fi

echo "==> Port-forwarding ${LOCAL_PORT} -> openbao:8200"
nohup kubectl -n "$NAMESPACE" port-forward --address 127.0.0.1,::1 svc/openbao "${LOCAL_PORT}:8200" \
  >"$LOG_FILE" 2>&1 &
echo $! >"$PID_FILE"

for _ in $(seq 1 40); do
  code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${LOCAL_PORT}/v1/sys/health" || true)"
  if [[ "$code" == "200" ]]; then
    echo ""
    echo "OpenBao is up: http://localhost:${LOCAL_PORT}"
    echo "UI: http://localhost:${LOCAL_PORT}/ui"
    echo "Root token: ${INIT_FILE} (field root_token)"
    echo "Publish a secret for a workload with:"
    echo "  bash security/secrets/publish-secret.sh <namespace> <secret-name> key=value"
    echo "Stop it with:"
    echo "  bash security/secrets/stop.sh"
    exit 0
  fi
  sleep 0.5
done

echo "Port-forward did not become ready. See ${LOG_FILE}" >&2
exit 1
