#!/usr/bin/env bash
# Install this repo's skills/ into another project's .cursor/skills by copy or symlink.
# Run from any project root, or pass -C <dir>.
#
# Usage:
#   /path/to/skills/mcps/scripts/project-setup-cursor-skills.sh
#   /path/to/skills/mcps/scripts/project-setup-cursor-skills.sh -C ~/code/my-app
#   /path/to/skills/mcps/scripts/project-setup-cursor-skills.sh -m symlink -y
#
# Optional: SKILLS_ROOT overrides the skills repo location (default: derived from this script).
#
# Run with bash or execute directly. Avoid bash 4+ features so macOS /bin/bash 3.2 works.

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
DEFAULT_SKILLS_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILLS_ROOT="${SKILLS_ROOT:-$DEFAULT_SKILLS_ROOT}"

usage() {
  sed -n '1,12p' "$SCRIPT_PATH" | tail -n +2
  echo "Options:"
  echo "  -C DIR       project root (default: git toplevel or cwd)"
  echo "  -m MODE      copy | symlink — skip interactive method prompt"
  echo "  -y           replace existing .cursor/skills without asking"
  echo "  -h           help"
  echo "Env: SKILLS_ROOT — path to this skills repo if the script was moved."
}

PROJECT_ROOT=""
METHOD=""
ASSUME_YES=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    -C)
      PROJECT_ROOT="${2:?-C requires a directory}"
      shift 2
      ;;
    -m)
      METHOD="${2:?-m requires copy or symlink}"
      shift 2
      ;;
    -y)
      ASSUME_YES=1
      shift
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -n "$METHOD" ]]; then
  case "$METHOD" in
    copy|symlink) ;;
    *)
      echo "error: -m must be copy or symlink (got: $METHOD)" >&2
      exit 1
      ;;
  esac
fi

if [[ -z "$PROJECT_ROOT" ]]; then
  if git rev-parse --show-toplevel &>/dev/null; then
    PROJECT_ROOT="$(git rev-parse --show-toplevel)"
  else
    PROJECT_ROOT="$(pwd)"
  fi
fi

PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
SOURCE="$(cd "$SKILLS_ROOT/skills" && pwd)"
DEST="$PROJECT_ROOT/.cursor/skills"

if [[ ! -d "$SOURCE" ]]; then
  echo "error: skills directory not found: $SKILLS_ROOT/skills" >&2
  echo "Set SKILLS_ROOT to your skills repo clone." >&2
  exit 1
fi

prompt_replace() {
  if [[ $ASSUME_YES -eq 1 ]]; then
    return 0
  fi
  local r
  printf "Destination already exists:\\n  %s\\nRemove it and reinstall? [y/N]: " "$DEST" >&2
  read -r r || true
  case "$(printf '%s' "$r" | tr '[:upper:]' '[:lower:]')" in
    y|yes) return 0 ;;
    *) echo "Aborted." >&2; exit 0 ;;
  esac
}

prompt_method() {
  if [[ -n "$METHOD" ]]; then
    return 0
  fi
  local a
  while true; do
    printf "Install Cursor project skills from:\\n  %s\\ninto:\\n  %s\\n\\nUse (c)opy or (s)ymlink? [c/s]: " "$SOURCE" "$DEST" >&2
    read -r a || true
    case "$(printf '%s' "$a" | tr '[:upper:]' '[:lower:]')" in
      c|copy)
        METHOD=copy
        return 0
        ;;
      s|symlink|l|link)
        METHOD=symlink
        return 0
        ;;
      "")
        echo "Please enter c (copy) or s (symlink)." >&2
        ;;
      *)
        echo "Invalid choice; enter c or s." >&2
        ;;
    esac
  done
}

prompt_method

if [[ -e "$DEST" ]] || [[ -L "$DEST" ]]; then
  prompt_replace
  rm -rf "$DEST"
fi

mkdir -p "$PROJECT_ROOT/.cursor"

case "$METHOD" in
  copy)
    cp -a "$SOURCE" "$DEST"
    echo "Copied skills to $DEST"
    ;;
  symlink)
    ln -s "$SOURCE" "$DEST"
    echo "Symlinked $DEST -> $SOURCE"
    ;;
esac

echo "Restart Cursor or reload the window if skills do not appear immediately."
