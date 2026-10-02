#!/usr/bin/env bash
# Stop the Keycloak port-forward and scale the deployment to zero.
# The namespace and data volume stay in place.
#   bash security/keycloak/stop.sh
set -euo pipefail

NAMESPACE="security-keycloak"
EXPECTED_CONTEXT="rancher-desktop"
PID_FILE="${TMPDIR:-/tmp}/security-keycloak-port-forward.pid"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required." >&2
  exit 1
fi

context="$(kubectl config current-context)"
if [[ "$context" != "$EXPECTED_CONTEXT" ]]; then
  echo "Current kubectl context is '${context}'. Expected '${EXPECTED_CONTEXT}'." >&2
  exit 1
fi

echo "==> Stopping port-forward"
if [[ -f "$PID_FILE" ]]; then
  pid="$(cat "$PID_FILE")"
  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
  fi
  rm -f "$PID_FILE"
fi
existing="$(pgrep -f "kubectl -n ${NAMESPACE} port-forward " || true)"
if [[ -n "$existing" ]]; then
  # shellcheck disable=SC2086
  kill $existing 2>/dev/null || true
fi

if kubectl -n "$NAMESPACE" get deploy/keycloak >/dev/null 2>&1; then
  echo "==> Scaling Keycloak to zero"
  kubectl -n "$NAMESPACE" scale deploy/keycloak --replicas=0
fi

echo "Keycloak is stopped. Data remains in namespace ${NAMESPACE}."
