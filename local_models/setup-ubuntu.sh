#!/usr/bin/env bash
# Install both local runtimes on Ubuntu / Debian (Ollama chat + Ollaya decisions).
# Usage: bash local_models/setup-ubuntu.sh [ollaya-model]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This script is for Linux (Ubuntu/Debian). On macOS use local_models/setup.sh." >&2
  exit 1
fi

echo "=== Ollama (chat LLMs on :11434) ==="
bash "${ROOT}/setup-ollama-ubuntu.sh"

echo ""
echo "=== Ollaya (Jev-style decisions on :11435) ==="
bash "${ROOT}/setup-ollaya.sh" "${1:-laya}"

echo ""
echo "Both servers can run side by side. See local_models/README.md."
