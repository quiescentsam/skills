#!/usr/bin/env bash
# Patch Azure embedding settings from a local .env into secret registry-env.
# Weaviate 1.32 reads that same secret. It needs the text2vec-openai module
# and AZURE_APIKEY before the registry can create the A2a_agents collection.
# Then restart Weaviate and the backend so both read the new values.
#
#   cp registry/jarvis/.env.example registry/jarvis/.env
#   bash registry/jarvis/set-embedding.sh
#   bash registry/jarvis/set-embedding.sh /path/to/.env
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${1:-${ROOT}/.env}"
NAMESPACE="jarvis"
SECRET_NAME="registry-env"
EXPECTED_CONTEXT="rancher-desktop"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required." >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required." >&2
  exit 1
fi

context="$(kubectl config current-context)"
if [[ "$context" != "$EXPECTED_CONTEXT" ]]; then
  echo "Current kubectl context is '${context}'. Expected '${EXPECTED_CONTEXT}'." >&2
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Env file not found: ${ENV_FILE}" >&2
  echo "Copy registry/jarvis/.env.example to registry/jarvis/.env and fill it in." >&2
  exit 1
fi

patch="$(
  ENV_FILE="$ENV_FILE" python3 - <<'PY'
import json
import os
from pathlib import Path

values = {}
for raw in Path(os.environ["ENV_FILE"]).read_text().splitlines():
    line = raw.strip()
    if not line or line.startswith("#") or "=" not in line:
        continue
    key, value = line.split("=", 1)
    value = value.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
        value = value[1:-1]
    values[key.strip()] = value

required = (
    "EMBEDDING_PROVIDER",
    "AZURE_OPENAI_API_KEY",
    "AZURE_OPENAI_ENDPOINT",
    "AZURE_OPENAI_EMBEDDING_DEPLOYMENT",
)
missing = [key for key in required if not values.get(key)]
if missing:
    raise SystemExit("Missing or empty in env file: " + ", ".join(missing))

endpoint = values["AZURE_OPENAI_ENDPOINT"]
host = endpoint.removeprefix("https://").split("/", 1)[0]
if not endpoint.startswith("https://") or not host.endswith(".openai.azure.com"):
    raise SystemExit(
        "AZURE_OPENAI_ENDPOINT must be https://<resource>.openai.azure.com. "
        f"Got: {endpoint}"
    )

string_data = {key: values[key] for key in required}
string_data["AZURE_OPENAI_API_VERSION"] = values.get("AZURE_OPENAI_API_VERSION") or "2024-06-01"
# The Azure vectorizer is the text2vec-openai module. The registry client
# does not send the Azure key, so the module reads AZURE_APIKEY.
string_data["ENABLE_MODULES"] = "text2vec-openai"
string_data["AZURE_APIKEY"] = values["AZURE_OPENAI_API_KEY"]
print(json.dumps({"stringData": string_data}))
PY
)"

echo "==> Patching secret ${SECRET_NAME} in namespace ${NAMESPACE}"
kubectl -n "$NAMESPACE" patch secret "$SECRET_NAME" --type merge -p "$patch"

echo "==> Restarting Weaviate"
kubectl -n "$NAMESPACE" rollout restart sts/jarvis-registry-weaviate
kubectl -n "$NAMESPACE" rollout status sts/jarvis-registry-weaviate --timeout=10m

echo "==> Restarting backend"
kubectl -n "$NAMESPACE" rollout restart deploy/jarvis-registry-backend
kubectl -n "$NAMESPACE" rollout status deploy/jarvis-registry-backend --timeout=15m
