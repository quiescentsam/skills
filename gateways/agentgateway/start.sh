#!/usr/bin/env bash
# Download agentgateway if needed, then start it and wait for the LLM URL.
#   bash gateways/agentgateway/start.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "${ROOT}/common.sh"

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required." >&2
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  umask 077
  cp "$ENV_EXAMPLE" "$ENV_FILE"
  echo "==> Wrote ${ENV_FILE}"
  echo "    Set FOUNDRY_API_KEY there before calling Foundry models."
fi

foundry_key="$(env_value FOUNDRY_API_KEY || true)"
if [[ -z "$foundry_key" ]]; then
  echo "==> FOUNDRY_API_KEY is empty in ${ENV_FILE}."
  echo "    Ollama models still work. Foundry models work after you set the key and restart."
fi

if grep -q 'your-resource-name\|your-project-name' "$CONFIG_FILE"; then
  echo "==> LLM/config.yaml still has Foundry placeholders."
  echo "    Set azureResourceName and azureProjectName before calling Foundry models."
fi

if curl -sf -o /dev/null "http://127.0.0.1:${LOCAL_PORT}/v1/models"; then
  echo "agentgateway is already up: http://127.0.0.1:${LOCAL_PORT}/v1"
  exit 0
fi

if lsof -nP -iTCP:"${LOCAL_PORT}" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "Local port ${LOCAL_PORT} is already in use." >&2
  exit 1
fi

mkdir -p "$BIN_DIR" "$DATA_DIR"

installed="$(cat "${BIN_DIR}/VERSION" 2>/dev/null || true)"
if [[ ! -x "$BIN" || "$installed" != "$VERSION" ]]; then
  asset="$(asset_name)"
  base="https://github.com/agentgateway/agentgateway/releases/download/${VERSION}"
  tmp="$(mktemp)"
  echo "==> Downloading agentgateway ${VERSION} (${asset})"
  curl -fL --retry 3 -o "$tmp" "${base}/${asset}"
  expected="$(curl -fsSL "${base}/${asset}.sha256" | awk '{print $1}')"
  actual="$(shasum -a 256 "$tmp" | awk '{print $1}')"
  if [[ "$actual" != "$expected" ]]; then
    rm -f "$tmp"
    echo "Checksum mismatch for ${asset}." >&2
    exit 1
  fi
  mv "$tmp" "$BIN"
  chmod +x "$BIN"
  echo "$VERSION" >"${BIN_DIR}/VERSION"
fi

set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

echo "==> Starting agentgateway"
(
  cd "$ROOT"
  nohup "$BIN" -f "$CONFIG_FILE" >"$LOG_FILE" 2>&1 &
  echo $! >"$PID_FILE"
)

ready=0
for _ in $(seq 1 60); do
  code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:${LOCAL_PORT}/v1/models" || true)"
  if [[ "$code" == "200" ]]; then
    ready=1
    break
  fi
  if [[ -f "$PID_FILE" ]] && ! kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
    echo "agentgateway exited. Recent logs:" >&2
    tail -n 80 "$LOG_FILE" >&2 || true
    exit 1
  fi
  sleep 0.5
done

if [[ "$ready" -ne 1 ]]; then
  echo "agentgateway did not become ready. Recent logs:" >&2
  tail -n 80 "$LOG_FILE" >&2 || true
  exit 1
fi

echo ""
echo "LLM URL: http://127.0.0.1:${LOCAL_PORT}/v1"
echo "UI:      http://127.0.0.1:${LOCAL_PORT}/ui"
echo "Ollama model names look like ollama/llama3.2 or ollama-lan/llama3.2"
echo "Foundry model names look like foundry/<deployment>"
echo "Stop it with:"
echo "  bash gateways/agentgateway/stop.sh"
