#!/usr/bin/env bash
# Install and start Ollama for local chat LLMs on Ubuntu / Debian (Linux).
# Usage: bash local_models/setup-ollama-ubuntu.sh
set -euo pipefail

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "This script is for Linux (Ubuntu/Debian). On macOS use local_models/setup-ollama.sh." >&2
  exit 1
fi

if [[ -r /etc/os-release ]]; then
  # shellcheck source=/dev/null
  . /etc/os-release
  case "${ID:-}" in
    ubuntu | debian | pop | linuxmint | elementary) ;;
    *)
      echo "Warning: untested on ${PRETTY_NAME:-Linux}. Continuing anyway." >&2
      ;;
  esac
fi

install_ollama() {
  echo "==> Installing Ollama (official Linux install script)"
  if [[ "$(id -u)" -eq 0 ]]; then
    curl -fsSL https://ollama.com/install.sh | sh
  elif command -v sudo >/dev/null 2>&1; then
    curl -fsSL https://ollama.com/install.sh | sudo sh
  else
    echo "Need root to install Ollama. Run: curl -fsSL https://ollama.com/install.sh | sh" >&2
    exit 1
  fi
}

if ! command -v ollama >/dev/null 2>&1; then
  install_ollama
else
  echo "==> Ollama CLI already installed"
fi

if ! command -v ollama >/dev/null 2>&1; then
  echo "ollama binary not on PATH after install. Open a new shell and re-run." >&2
  exit 1
fi

start_ollama() {
  echo "==> Starting Ollama"
  if command -v systemctl >/dev/null 2>&1 && systemctl list-unit-files ollama.service &>/dev/null 2>&1; then
    if [[ "$(id -u)" -eq 0 ]]; then
      systemctl enable ollama 2>/dev/null || true
      systemctl start ollama
    elif command -v sudo >/dev/null 2>&1; then
      sudo systemctl enable ollama 2>/dev/null || true
      sudo systemctl start ollama
    else
      ollama serve >/dev/null 2>&1 &
    fi
  else
    ollama serve >/dev/null 2>&1 &
  fi
}

if curl -sf http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
  echo "    Ollama is already up"
else
  start_ollama
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

echo "Ollama did not respond on :11434. Try: sudo systemctl status ollama" >&2
exit 1
