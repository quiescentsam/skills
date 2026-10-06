#!/usr/bin/env bash
# Stop the OpenBao port-forward and scale the workloads to zero.
# The namespace, volume, and init file stay in place.
#   bash security/secrets/stop.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "${ROOT}/common.sh"

require_tools
require_context

echo "==> Stopping port-forward"
stop_port_forward

if kubectl get namespace "$NAMESPACE" >/dev/null 2>&1; then
  echo "==> Scaling OpenBao and External Secrets to zero"
  kubectl -n "$NAMESPACE" scale statefulset --all --replicas=0
  kubectl -n "$NAMESPACE" scale deploy --all --replicas=0
fi

echo "OpenBao is stopped. Data remains in namespace ${NAMESPACE}."
