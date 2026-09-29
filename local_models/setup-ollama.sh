#!/usr/bin/env bash
# Install and start Ollama for local chat LLMs on macOS (Apple Silicon).
# Usage: bash local_models/setup-ollama.sh
set -euo pipefail

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required. Install from https://brew.sh then re-run." >&2
  exit 1
fi

echo "==> Installing Ollama (official macOS app via Homebrew cask)"
if brew list --cask ollama-app &>/dev/null || brew list --cask ollama &>/dev/null; then
  echo "    Ollama cask already installed"
else
  if brew list ollama &>/dev/null; then
    echo "    Removing Homebrew formula 'ollama' (use the app cask instead)"
    brew uninstall ollama || true
  fi
  brew install --cask ollama-app
fi

if ! command -v ollama >/dev/null 2>&1; then
  echo "ollama binary not on PATH after install. Open /Applications/Ollama.app once, then re-run." >&2
  exit 1
fi

echo "==> Starting Ollama"
if [[ -d /Applications/Ollama.app ]]; then
  open -a Ollama
else
  brew services start ollama 2>/dev/null || ollama serve &
fi

echo "==> Waiting for API at http://127.0.0.1:11434"
for _ in $(seq 1 30); do
  if curl -sf http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    echo "    Ollama is up"
    ollama --version 2>/dev/null || true
    echo ""
    echo "Next: pull a model, e.g."
    echo "  ollama pull llama3.2:3b"
    echo "  ollama run llama3.2:3b"
    echo "See local_models/README.md (Part A) for Cursor / API setup."
    exit 0
  fi
  sleep 1
done

echo "Ollama did not respond on :11434. Open the Ollama app from Applications and try again." >&2
exit 1
