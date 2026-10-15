# Shared helpers for the local agentgateway process. Source this; do not execute it.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${ROOT}/LLM/.env"
ENV_EXAMPLE="${ROOT}/LLM/.env.example"
CONFIG_FILE="${ROOT}/LLM/config.yaml"
DATA_DIR="${ROOT}/data"
BIN_DIR="${ROOT}/bin"
BIN="${BIN_DIR}/agentgateway"
VERSION="v1.6.0"
LOCAL_PORT=4000
PID_FILE="${DATA_DIR}/agentgateway.pid"
LOG_FILE="${DATA_DIR}/agentgateway.log"

env_value() {
  local key="$1"
  awk -F= -v key="$key" '
    $0 ~ /^[[:space:]]*#/ { next }
    $1 == key {
      sub(/^[^=]*=/, "")
      print
      exit
    }
  ' "$ENV_FILE"
}

asset_name() {
  local os arch
  os="$(uname -s)"
  arch="$(uname -m)"
  case "${os}-${arch}" in
    Darwin-arm64) echo "agentgateway-darwin-arm64" ;;
    Linux-x86_64) echo "agentgateway-linux-amd64" ;;
    Linux-aarch64|Linux-arm64) echo "agentgateway-linux-arm64" ;;
    *)
      echo "No agentgateway ${VERSION} build for ${os} ${arch}." >&2
      exit 1
      ;;
  esac
}
