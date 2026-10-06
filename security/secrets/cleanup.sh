#!/usr/bin/env bash
# Permanently remove the local OpenBao installation and its data.
#   bash security/secrets/cleanup.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "${ROOT}/common.sh"

require_tools
require_context

echo "==> Stopping port-forward"
stop_port_forward
rm -f "$LOG_FILE"

if kubectl get clustersecretstore openbao >/dev/null 2>&1; then
  echo "==> Deleting ClusterSecretStore openbao"
  kubectl delete clustersecretstore openbao --wait=true --timeout=3m
fi

if helm status openbao -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "==> Uninstalling OpenBao"
  helm uninstall openbao -n "$NAMESPACE" --wait --timeout 5m
fi
if helm status external-secrets -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "==> Uninstalling External Secrets"
  helm uninstall external-secrets -n "$NAMESPACE" --wait --timeout 5m
fi

if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "==> Deleting namespace ${NAMESPACE}"
  kubectl delete namespace "$NAMESPACE" --wait=true --timeout=10m
fi

echo "==> Deleting External Secrets CRDs"
while IFS= read -r crd; do
  [[ -z "$crd" ]] && continue
  kubectl delete "$crd" --wait=true --timeout=3m || true
done < <(kubectl get crd -o name | grep '\.external-secrets\.io$' || true)

rm -f "$INIT_FILE"
echo "OpenBao, External Secrets, and the local init file have been removed."
