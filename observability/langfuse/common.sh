# Shared helpers for the local Langfuse stack. Source this; do not execute it.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ROOT}/.env"
COMPOSE_FILE="${ROOT}/docker-compose.yml"

require_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    echo "docker is required." >&2
    exit 1
  fi
  if ! docker compose version >/dev/null 2>&1; then
    echo "docker compose is required." >&2
    exit 1
  fi
  if ! docker info >/dev/null 2>&1; then
    echo "Docker is not running. Start Docker Desktop and try again." >&2
    exit 1
  fi
}

compose() {
  docker compose --project-directory "$ROOT" -f "$COMPOSE_FILE" "$@"
}

env_value() {
  local key="$1"
  awk -F= -v key="$key" '
    $1 == key {
      sub(/^[^=]*=/, "")
      print
      exit
    }
  ' "$ENV_FILE"
}
