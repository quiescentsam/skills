#!/usr/bin/env bash
# Pick skills from this library and install them into a project's .cursor/skills.
# Run from the other repo's root, or pass -C <dir>.
#
# Usage:
#   /path/to/skills/skills/setup.sh
#   /path/to/skills/skills/setup.sh -C ~/code/my-app
#   /path/to/skills/skills/setup.sh default next-js
#   /path/to/skills/skills/setup.sh -m symlink -y default
#
# Optional: SKILLS_ROOT overrides the skills repo location (default: derived from this script).
#
# Run with bash or execute directly. Avoid bash 4+ features so macOS /bin/bash 3.2 works.

set -euo pipefail

SCRIPT_PATH="${BASH_SOURCE[0]:-$0}"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
DEFAULT_SKILLS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SKILLS_ROOT="${SKILLS_ROOT:-$DEFAULT_SKILLS_ROOT}"
SOURCE="$SKILLS_ROOT/skills"

usage() {
  sed -n '1,14p' "$SCRIPT_PATH" | tail -n +2
  echo "Options:"
  echo "  -C DIR       project root (default: git toplevel or cwd)"
  echo "  -m MODE      copy | symlink (default: copy)"
  echo "  -a           install every skill in the library"
  echo "  -l           list skills and exit"
  echo "  -y           replace an existing skill directory without asking"
  echo "  -h           help"
  echo "Args: skill ids, file names, or paths under skills/ (for example default or general/DEFAULT.md)."
  echo "Env: SKILLS_ROOT — path to this skills repo if the script was moved."
}

PROJECT_ROOT=""
METHOD="copy"
ASSUME_YES=0
LIST_ONLY=0
INSTALL_ALL=0
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
    -m)
      METHOD="${2:?-m requires copy or symlink}"
      shift 2
      ;;
    -a|--all)
      INSTALL_ALL=1
      shift
      ;;
    -l|--list)
      LIST_ONLY=1
      shift
      ;;
    -y)
      ASSUME_YES=1
      shift
      ;;
    --)
      shift
      POSITIONAL+=("$@")
      break
      ;;
    -*)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

case "$METHOD" in
  copy|symlink) ;;
  *)
    echo "error: -m must be copy or symlink (got: $METHOD)" >&2
    exit 1
    ;;
esac

if [[ ! -d "$SOURCE" ]]; then
  echo "error: skills directory not found: $SOURCE" >&2
  echo "Set SKILLS_ROOT to your skills repo clone." >&2
  exit 1
fi
SOURCE="$(cd "$SOURCE" && pwd)"

slugify() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//'
}

frontmatter_field() {
  local file="$1"
  local field="$2"
  awk -v field="$field" '
    BEGIN { fm = 0 }
    NR == 1 && $0 !~ /^---[[:space:]]*$/ { exit }
    /^---[[:space:]]*$/ { if (fm) exit; fm = 1; next }
    fm && index($0, field ":") == 1 {
      val = substr($0, length(field) + 2)
      sub(/^[[:space:]]+/, "", val)
      if (val == ">" || val == ">-" || val == "|" || val == "|-" || val == "") {
        if (getline <= 0) exit
        sub(/^[[:space:]]+/, "", $0)
        val = $0
      }
      sub(/^["'\'']/, "", val)
      sub(/["'\''][[:space:]]*$/, "", val)
      print val
      exit
    }
  ' "$file"
}

skill_meta_file() {
  local path="$1"
  local kind="$2"
  if [[ "$kind" == "dir" ]]; then
    printf '%s\n' "$path/SKILL.md"
  else
    printf '%s\n' "$path"
  fi
}

SKILL_IDS=()
SKILL_KINDS=()
SKILL_PATHS=()
SKILL_DESCS=()

add_skill() {
  local path="$1"
  local kind="$2"
  local meta id desc rel i
  meta="$(skill_meta_file "$path" "$kind")"
  id="$(frontmatter_field "$meta" "name")"
  if [[ -z "$id" ]]; then
    id="$(basename "$path" .md)"
  fi
  id="$(slugify "$id")"
  if [[ -z "$id" ]]; then
    echo "error: could not derive a skill id from $path" >&2
    exit 1
  fi
  for ((i = 0; i < ${#SKILL_IDS[@]}; i++)); do
    if [[ "${SKILL_IDS[$i]}" == "$id" ]]; then
      echo "error: duplicate skill id '$id'" >&2
      echo "  ${SKILL_PATHS[$i]}" >&2
      echo "  $path" >&2
      exit 1
    fi
  done
  desc="$(frontmatter_field "$meta" "description")"
  desc="${desc//$'\n'/ }"
  if [[ ${#desc} -gt 88 ]]; then
    desc="${desc:0:85}..."
  fi
  rel="${path#"$SOURCE"/}"
  SKILL_IDS+=("$id")
  SKILL_KINDS+=("$kind")
  SKILL_PATHS+=("$path")
  SKILL_DESCS+=("$desc")
  SKILL_RELS+=("$rel")
}

SKILL_RELS=()

inside_skill_dir() {
  local dir="$1"
  while [[ "$dir" != "$SOURCE" && "$dir" != "/" ]]; do
    if [[ -f "$dir/SKILL.md" ]]; then
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

collect_skills() {
  local path
  local list_tmp
  list_tmp="$(mktemp "${TMPDIR:-/tmp}/skill-library.XXXXXX")"
  find "$SOURCE" \( -type d -name '.git' -prune \) -o -type f -name 'SKILL.md' -print | sort >"$list_tmp"
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    add_skill "$(dirname "$path")" "dir"
  done <"$list_tmp"

  find "$SOURCE" \( -type d -name '.git' -prune \) -o -type f -name '*.md' -print | sort >"$list_tmp"
  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    [[ "$(basename "$path")" == "README.md" ]] && continue
    [[ "$(basename "$path")" == "SKILL.md" ]] && continue
    if inside_skill_dir "$(dirname "$path")"; then
      continue
    fi
    add_skill "$path" "file"
  done <"$list_tmp"
  rm -f "$list_tmp"
}

collect_skills

if [[ ${#SKILL_IDS[@]} -eq 0 ]]; then
  echo "error: no skills found in $SOURCE" >&2
  echo "Add skills/<name>/SKILL.md or a markdown file under skills/." >&2
  exit 1
fi

print_catalog() {
  local i rel desc
  for ((i = 0; i < ${#SKILL_IDS[@]}; i++)); do
    rel="${SKILL_RELS[$i]}"
    desc="${SKILL_DESCS[$i]}"
    if [[ -n "$desc" ]]; then
      printf '%s\t%s\t%s\n' "${SKILL_IDS[$i]}" "$rel" "$desc"
    else
      printf '%s\t%s\n' "${SKILL_IDS[$i]}" "$rel"
    fi
  done
}

if [[ $LIST_ONLY -eq 1 ]]; then
  print_catalog
  exit 0
fi

resolve_token() {
  local token="$1"
  local i rel base file_slug want matches=()
  token="${token#./}"
  token="${token#skills/}"
  want="$(slugify "$token")"
  for ((i = 0; i < ${#SKILL_IDS[@]}; i++)); do
    rel="${SKILL_RELS[$i]}"
    base="$(basename "$rel")"
    file_slug="$(slugify "${base%.md}")"
    if [[ "$want" == "${SKILL_IDS[$i]}" || "$want" == "$file_slug" || "$want" == "$(slugify "$rel")" ]]; then
      matches+=("$i")
    fi
  done
  if [[ ${#matches[@]} -eq 1 ]]; then
    printf '%s\n' "${matches[0]}"
    return 0
  fi
  if [[ ${#matches[@]} -gt 1 ]]; then
    echo "error: '$1' matches more than one skill; use the skill id" >&2
    exit 1
  fi
  echo "error: unknown skill: $1" >&2
  echo "Known skills:" >&2
  print_catalog >&2
  exit 1
}

SELECTED=()

select_indexes() {
  local token
  for token in "$@"; do
    SELECTED+=("$(resolve_token "$token")")
  done
}

if [[ $INSTALL_ALL -eq 1 ]]; then
  local_i=0
  while [[ $local_i -lt ${#SKILL_IDS[@]} ]]; do
    SELECTED+=("$local_i")
    local_i=$((local_i + 1))
  done
elif [[ ${#POSITIONAL[@]} -gt 0 ]]; then
  select_indexes "${POSITIONAL[@]}"
else
  if [[ ! -t 0 ]]; then
    echo "error: no skill names given and stdin is not a terminal." >&2
    echo "Pass skill ids, -a, or run from a terminal to pick." >&2
    exit 1
  fi
  echo "Skill library: $SOURCE" >&2
  echo "Install mode: $METHOD" >&2
  echo >&2
  i=0
  while [[ $i -lt ${#SKILL_IDS[@]} ]]; do
    printf '  %d) %s\n' $((i + 1)) "${SKILL_IDS[$i]}" >&2
    printf '     %s' "${SKILL_RELS[$i]}" >&2
    if [[ -n "${SKILL_DESCS[$i]}" ]]; then
      printf ' — %s' "${SKILL_DESCS[$i]}" >&2
    fi
    printf '\n' >&2
    i=$((i + 1))
  done
  echo >&2
  printf "Enter numbers (1,3 or 1-3), skill ids, 'a' for all, or 'q' to quit: " >&2
  IFS= read -r answer || true
  answer="$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')"
  case "$answer" in
    ""|q|quit)
      echo "Aborted." >&2
      exit 0
      ;;
    a|all|\*)
      i=0
      while [[ $i -lt ${#SKILL_IDS[@]} ]]; do
        SELECTED+=("$i")
        i=$((i + 1))
      done
      ;;
    *)
      normalized="$(printf '%s' "$answer" | tr ',' ' ')"
      for token in $normalized; do
        if [[ "$token" =~ ^[0-9]+-[0-9]+$ ]]; then
          start="${token%-*}"
          end="${token#*-}"
          if [[ "$start" -gt "$end" ]]; then
            echo "error: invalid range: $token" >&2
            exit 1
          fi
          n="$start"
          while [[ "$n" -le "$end" ]]; do
            if [[ "$n" -lt 1 || "$n" -gt ${#SKILL_IDS[@]} ]]; then
              echo "error: selection out of range: $n" >&2
              exit 1
            fi
            SELECTED+=("$((n - 1))")
            n=$((n + 1))
          done
        elif [[ "$token" =~ ^[0-9]+$ ]]; then
          if [[ "$token" -lt 1 || "$token" -gt ${#SKILL_IDS[@]} ]]; then
            echo "error: selection out of range: $token" >&2
            exit 1
          fi
          SELECTED+=("$((token - 1))")
        else
          SELECTED+=("$(resolve_token "$token")")
        fi
      done
      ;;
  esac
fi

if [[ ${#SELECTED[@]} -eq 0 ]]; then
  echo "Aborted." >&2
  exit 0
fi

if [[ -z "$PROJECT_ROOT" ]]; then
  if git rev-parse --show-toplevel &>/dev/null; then
    PROJECT_ROOT="$(git rev-parse --show-toplevel)"
  else
    PROJECT_ROOT="$(pwd)"
  fi
fi
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"
DEST="$PROJECT_ROOT/.cursor/skills"

if [[ -L "$DEST" ]]; then
  echo "error: $DEST is a symlink to the whole library." >&2
  echo "Remove it, then re-run so you can install individual skills." >&2
  exit 1
fi

EXISTING=()
for idx in "${SELECTED[@]}"; do
  id="${SKILL_IDS[$idx]}"
  if [[ -e "$DEST/$id" || -L "$DEST/$id" ]]; then
    EXISTING+=("$id")
  fi
done

if [[ ${#EXISTING[@]} -gt 0 && $ASSUME_YES -eq 0 ]]; then
  echo "These skills already exist in $DEST:" >&2
  for id in "${EXISTING[@]}"; do
    echo "  $id" >&2
  done
  if [[ ! -t 0 ]]; then
    echo "error: pass -y to replace them." >&2
    exit 1
  fi
  printf "Replace them? [y/N]: " >&2
  read -r replace || true
  case "$(printf '%s' "$replace" | tr '[:upper:]' '[:lower:]')" in
    y|yes) ;;
    *)
      echo "Aborted." >&2
      exit 0
      ;;
  esac
fi

mkdir -p "$DEST"

install_one() {
  local idx="$1"
  local id kind src dest meta
  id="${SKILL_IDS[$idx]}"
  kind="${SKILL_KINDS[$idx]}"
  src="${SKILL_PATHS[$idx]}"
  dest="$DEST/$id"
  meta="$(skill_meta_file "$src" "$kind")"
  if [[ -z "$(frontmatter_field "$meta" "name")" ]]; then
    echo "warning: ${SKILL_RELS[$idx]} has no YAML name; Cursor may not list '$id'" >&2
  fi
  rm -rf "$dest"
  if [[ "$kind" == "dir" ]]; then
    if [[ "$METHOD" == "symlink" ]]; then
      ln -s "$src" "$dest"
    else
      mkdir -p "$dest"
      cp -a "$src/." "$dest/"
    fi
  else
    mkdir -p "$dest"
    if [[ "$METHOD" == "symlink" ]]; then
      ln -s "$src" "$dest/SKILL.md"
    else
      cp -a "$src" "$dest/SKILL.md"
    fi
  fi
  echo "Installed $id -> $dest"
}

for idx in "${SELECTED[@]}"; do
  install_one "$idx"
done

echo "Cursor loads these from $DEST. Reload the window if they do not appear immediately."
