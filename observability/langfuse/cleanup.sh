#!/usr/bin/env bash
# Stop Langfuse and delete its volumes. .env is kept.
#   bash observability/langfuse/cleanup.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "${ROOT}/common.sh"

require_docker

echo "==> Removing Langfuse containers and volumes"
compose down --remove-orphans --volumes

echo "Langfuse containers and volumes have been removed."
echo "Credentials in ${ENV_FILE} were kept. The next start recreates the same user and API keys."
echo "Delete that file before the next start if you want new secrets."
