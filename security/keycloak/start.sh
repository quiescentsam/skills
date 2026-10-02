#!/usr/bin/env bash
# Install or start Keycloak and port-forward it to localhost:18080.
#   bash security/keycloak/start.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
NAMESPACE="security-keycloak"
EXPECTED_CONTEXT="rancher-desktop"
LOCAL_PORT=18080
PID_FILE="${TMPDIR:-/tmp}/security-keycloak-port-forward.pid"
LOG_FILE="${TMPDIR:-/tmp}/security-keycloak-port-forward.log"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required." >&2
  exit 1
fi

context="$(kubectl config current-context)"
if [[ "$context" != "$EXPECTED_CONTEXT" ]]; then
  echo "Current kubectl context is '${context}'. Expected '${EXPECTED_CONTEXT}'." >&2
  exit 1
fi

echo "==> Applying Keycloak in namespace ${NAMESPACE}"
kubectl apply -f "${ROOT}/keycloak.yaml"
kubectl -n "$NAMESPACE" scale deploy/keycloak --replicas=1
kubectl -n "$NAMESPACE" rollout status deploy/keycloak --timeout=10m

if lsof -nP -iTCP:"${LOCAL_PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Local port ${LOCAL_PORT} is already in use." >&2
  exit 1
fi

echo "==> Port-forwarding ${LOCAL_PORT} -> keycloak:8080"
nohup kubectl -n "$NAMESPACE" port-forward --address 127.0.0.1,::1 svc/keycloak "${LOCAL_PORT}:8080" \
  >"$LOG_FILE" 2>&1 &
echo $! >"$PID_FILE"

for _ in $(seq 1 40); do
  if curl -sf -o /dev/null "http://127.0.0.1:${LOCAL_PORT}/realms/master"; then
    echo ""
    echo "Keycloak is up: http://localhost:${LOCAL_PORT}"
    echo "Admin console: http://localhost:${LOCAL_PORT}/admin"
    echo "Username: admin"
    echo "Password: admin"
    echo "Create the Jarvis realm with:"
    echo "  bash security/keycloak/setup-realm.sh"
    echo "Stop it with:"
    echo "  bash security/keycloak/stop.sh"
    exit 0
  fi
  sleep 0.5
done

echo "Port-forward did not become ready. See ${LOG_FILE}" >&2
exit 1
