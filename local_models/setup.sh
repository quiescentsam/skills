#!/usr/bin/env bash
# Install both local runtimes (Ollama chat + Ollaya decisions).
# Usage: bash local_models/setup.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "=== Ollama (chat LLMs on :11434) ==="
bash "${ROOT}/setup-ollama.sh"

echo ""
echo "=== Ollaya (Jev-style decisions on :11435) ==="
bash "${ROOT}/setup-ollaya.sh" "${1:-laya}"

echo ""
echo "Both servers can run side by side. See local_models/README.md."
