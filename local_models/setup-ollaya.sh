#!/usr/bin/env bash
# Install Ollaya and pull a Jev-compatible decision model (macOS / Linux).
# Usage: bash local_models/setup-ollaya.sh [model]
# Default model: laya (CPU-friendly). Use winnow:e4b for closer-to-Jev accuracy.
set -euo pipefail

MODEL="${1:-laya}"

if [[ "$(uname -s)" == "Darwin" ]]; then
  arch="$(uname -m)"
  if [[ "$arch" != "arm64" ]]; then
    echo "Ollaya on macOS expects Apple silicon (arm64). Got: $arch" >&2
    exit 1
  fi
fi

if ! command -v ollaya >/dev/null 2>&1; then
  echo "==> Installing Ollaya CLI"
  curl -fsSL https://ollaya.dev/install.sh | sh
  export PATH="${HOME}/.local/bin:${PATH}"
fi

if ! command -v ollaya >/dev/null 2>&1; then
  echo "ollaya not on PATH after install. Open a new shell or add ~/.local/bin to PATH." >&2
  exit 1
fi

echo "==> Ollaya $(ollaya -v 2>/dev/null || true)"
echo "==> Ensuring server is up on 127.0.0.1:11435"
if ! curl -sf "http://127.0.0.1:11435/v1/models" -H "Authorization: Bearer local" >/dev/null 2>&1; then
  ollaya serve >/dev/null 2>&1 &
  for _ in $(seq 1 30); do
    if curl -sf "http://127.0.0.1:11435/v1/models" -H "Authorization: Bearer local" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
fi

echo "==> Pulling model: ${MODEL}"
ollaya pull "${MODEL}"

echo ""
echo "Ready. Try:"
echo "  ollaya run ${MODEL} --preset triage \"I was charged twice and want a refund.\""
echo ""
echo "Point TypeSafe / Jev clients at the local server:"
echo "  export TYPESAFE_BASE_URL=http://localhost:11435"
echo "  export TYPESAFE_API_KEY=local"
echo "  export TYPESAFE_DEFAULT_MODEL=${MODEL}"
echo ""
echo "See local_models/README.md (Part B) for API examples."
