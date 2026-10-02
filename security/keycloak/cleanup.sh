#!/usr/bin/env bash
# Permanently remove the local Keycloak installation and all of its data.
#   bash security/keycloak/cleanup.sh
set -euo pipefail

NAMESPACE="security-keycloak"
EXPECTED_CONTEXT="rancher-desktop"
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
rm -f "$LOG_FILE"

if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "==> Deleting namespace ${NAMESPACE} and all Keycloak data"
  kubectl delete namespace "$NAMESPACE" --wait=true --timeout=10m
else
  echo "Namespace ${NAMESPACE} does not exist."
fi

echo "Keycloak and its persistent data have been removed."
