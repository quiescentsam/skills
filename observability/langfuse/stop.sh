#!/usr/bin/env bash
# Stop Langfuse and remove its containers. Volumes and .env stay in place.
#   bash observability/langfuse/stop.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "${ROOT}/common.sh"

require_docker

echo "==> Stopping Langfuse"
compose down --remove-orphans

echo "Langfuse is stopped. Data remains in the Docker volumes."
echo "Remove the data with:"
echo "  bash observability/langfuse/cleanup.sh"
