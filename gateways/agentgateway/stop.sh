#!/usr/bin/env bash
# Stop the local agentgateway process. Config, .env, and SQLite data stay.
#   bash gateways/agentgateway/stop.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=common.sh
source "${ROOT}/common.sh"

if [[ -f "$PID_FILE" ]]; then
  pid="$(cat "$PID_FILE")"
  if kill -0 "$pid" 2>/dev/null; then
    echo "==> Stopping agentgateway (${pid})"
    kill "$pid"
    for _ in $(seq 1 40); do
      if ! kill -0 "$pid" 2>/dev/null; then
        break
      fi
      sleep 0.25
    done
    if kill -0 "$pid" 2>/dev/null; then
      kill -9 "$pid" 2>/dev/null || true
    fi
  fi
  rm -f "$PID_FILE"
else
  echo "agentgateway is not running."
fi

echo "agentgateway is stopped."
echo "Config remains in gateways/agentgateway/LLM/."
echo "SQLite data remains in gateways/agentgateway/data/."
