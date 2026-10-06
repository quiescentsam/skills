#!/usr/bin/env bash
# Write a KV secret into OpenBao and sync it to a Kubernetes Secret.
#   bash security/secrets/publish-secret.sh <namespace> <secret-name> key=value ...
#
# The Kubernetes Secret gets the same name in that namespace. A workload uses it
# with secretKeyRef or envFrom. Re-running this updates the OpenBao value and
# refreshes the Kubernetes Secret.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "${ROOT}/common.sh"

require_tools
require_context

if [[ $# -lt 3 ]]; then
  echo "Usage: bash security/secrets/publish-secret.sh <namespace> <secret-name> key=value ..." >&2
  exit 1
fi

ns="$1"
name="$2"
shift 2

if ! kubectl get namespace "$ns" >/dev/null 2>&1; then
  echo "Namespace ${ns} does not exist." >&2
  exit 1
fi

for pair in "$@"; do
  if [[ "$pair" != *=* || "$pair" == =* ]]; then
    echo "Expected key=value arguments. Got: ${pair}" >&2
    exit 1
  fi
done

path="secret/workloads/${ns}/${name}"
echo "==> Writing ${path}"
bao_exec kv put "$path" "$@"

stamp="$(date +%s)"
kubectl apply -f - <<EOF
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: ${name}
  namespace: ${ns}
  annotations:
    security.local/published-at: "${stamp}"
spec:
  refreshInterval: 1m
  secretStoreRef:
    name: openbao
    kind: ClusterSecretStore
  target:
    name: ${name}
    creationPolicy: Owner
  dataFrom:
    - extract:
        key: workloads/${ns}/${name}
EOF

if ! kubectl -n "$ns" wait --for=condition=Ready "externalsecret/${name}" --timeout=2m; then
  kubectl -n "$ns" describe "externalsecret/${name}" >&2 || true
  exit 1
fi

echo "Kubernetes Secret ${ns}/${name} is ready."
echo "Mount it from a workload with secretKeyRef or envFrom."
