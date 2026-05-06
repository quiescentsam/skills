#!/usr/bin/env bash
# Add or update an MCP server in the current (or chosen) project using definitions
# from this skills repo. Run from any project root, or pass -C <dir>.
#
# Usage:
#   /path/to/skills/mcps/scripts/project-pick-mcp.sh
#   /path/to/skills/mcps/scripts/project-pick-mcp.sh chrome-devtools
#   /path/to/skills/mcps/scripts/project-pick-mcp.sh -C ~/code/my-app chrome-devtools
#
# Optional: SKILLS_ROOT overrides the skills repo location (default: derived from this script).
#
# Run with bash or execute directly (./project-pick-mcp.sh). If you use `sh`, macOS /bin/sh
# is bash in POSIX mode and disallows some bash syntax; this script avoids process substitution
# so `sh …/project-pick-mcp.sh` still works.

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
DEFAULT_SKILLS_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SKILLS_ROOT="${SKILLS_ROOT:-$DEFAULT_SKILLS_ROOT}"
EMIT="$SKILLS_ROOT/mcps/scripts/emit-mcp-json.cjs"

usage() {
  sed -n '1,12p' "$SCRIPT_PATH" | tail -n +2
  echo "Options:"
  echo "  -C DIR   project root (default: git toplevel or cwd)"
  echo "  -h       help"
  echo "Env: SKILLS_ROOT — path to this skills repo if the script was moved."
}

PROJECT_ROOT=""
POSITIONAL=()
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
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

if [[ ! -f "$EMIT" ]]; then
  echo "error: emitter not found: $EMIT" >&2
  echo "Set SKILLS_ROOT to your skills repo clone." >&2
  exit 1
fi

if [[ -z "$PROJECT_ROOT" ]]; then
  if git rev-parse --show-toplevel &>/dev/null; then
    PROJECT_ROOT="$(git rev-parse --show-toplevel)"
  else
    PROJECT_ROOT="$(pwd)"
  fi
fi

PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
OUT="$PROJECT_ROOT/.cursor/mcp.json"

pick_interactive() {
  # Writes chosen server id into CHOSEN_MCP (no stdout) so nothing from select/readline
  # can be captured and re-parsed as shell code (command substitution is unsafe here).
  local servers=()
  local line
  local list_tmp
  list_tmp="$(mktemp "${TMPDIR:-/tmp}/mcp-servers.XXXXXX")"
  node "$EMIT" --list >"$list_tmp"
  while IFS= read -r line; do
    [[ -n "$line" ]] && servers+=("$line")
  done <"$list_tmp"
  rm -f "$list_tmp"

  if [[ ${#servers[@]} -eq 0 ]]; then
    echo "error: no server definitions in $SKILLS_ROOT/mcps/servers/" >&2
    exit 1
  fi

  echo "Project: $PROJECT_ROOT" >&2
  echo "Output:  $OUT" >&2
  echo >&2
  PS3="MCP server (number): "
  select choice in "${servers[@]}" "Quit"; do
    case "$choice" in
      Quit|"")
        echo "Aborted." >&2
        exit 0
        ;;
      *)
        if [[ -n "$choice" ]]; then
          CHOSEN_MCP="$choice"
          return 0
        fi
        echo "Invalid choice." >&2
        ;;
    esac
  done
}

SERVER_ID=""
if [[ ${#POSITIONAL[@]} -gt 0 ]]; then
  SERVER_ID="${POSITIONAL[0]}"
  if [[ "${#POSITIONAL[@]}" -gt 1 ]]; then
    echo "error: pass a single server id, or none for interactive mode." >&2
    exit 1
  fi
else
  CHOSEN_MCP=""
  pick_interactive
  SERVER_ID="$CHOSEN_MCP"
fi

mkdir -p "$PROJECT_ROOT/.cursor"

MERGE_ARGS=()
if [[ -f "$OUT" ]]; then
  MERGE_ARGS=(--merge "$OUT")
  echo "Merging into existing $OUT"
else
  echo "Creating $OUT"
fi

TMP="${OUT}.tmp.$$"
if [[ ${#MERGE_ARGS[@]} -gt 0 ]]; then
  node "$EMIT" "${MERGE_ARGS[@]}" "$SERVER_ID" >"$TMP"
else
  node "$EMIT" "$SERVER_ID" >"$TMP"
fi
mv "$TMP" "$OUT"

echo "Wrote MCP server '$SERVER_ID' for this project. Reload MCP in Cursor if needed."
