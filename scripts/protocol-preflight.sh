#!/bin/sh

# Read-only instruction preflight for Renata's Protocol.
# Usage: protocol-preflight.sh [target-directory ...]

set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
protocol_path="$script_dir/../renata-protocol.md"
workdir=$(pwd -P)
codex_home_dir=${CODEX_HOME:-"${HOME}/.codex"}
manifest_path=$(mktemp "${TMPDIR:-/tmp}/renata-preflight.XXXXXX")
trap 'rm -f "$manifest_path"' EXIT HUP INT TERM

if [ ! -s "$protocol_path" ] || [ ! -r "$protocol_path" ]; then
  printf '%s\n' "PREFLIGHT_ERROR: canonical protocol is missing or unreadable: $protocol_path" >&2
  exit 1
fi

add_file() {
  file_path=$1
  source_label=$2

  if [ ! -f "$file_path" ]; then
    return 0
  fi
  if [ ! -r "$file_path" ]; then
    printf '%s\n' "PREFLIGHT_ERROR: discovered file is unreadable: $file_path" >&2
    exit 1
  fi
  if ! grep -Fqx "$file_path" "$manifest_path" 2>/dev/null; then
    printf '%s\n' "$file_path" >> "$manifest_path"
    printf '%s\n' "PREFLIGHT_SOURCE: $source_label"
    printf '%s\n' "PREFLIGHT_PATH: $file_path"
    printf '%s\n' "PREFLIGHT_BYTES: $(wc -c < "$file_path" | tr -d ' ')"
    printf '%s\n' 'PREFLIGHT_CONTENT_BEGIN'
    cat "$file_path"
    printf '\n'
    printf '%s\n' 'PREFLIGHT_CONTENT_END'
  fi
}

select_instruction() {
  if [ -s "$1/AGENTS.override.md" ]; then
    add_file "$1/AGENTS.override.md" "$1/AGENTS.override.md"
  elif [ -s "$1/AGENTS.md" ]; then
    add_file "$1/AGENTS.md" "$1/AGENTS.md"
  fi
}

project_root_for() {
  target_path=$1
  if root_path=$(git -C "$target_path" rev-parse --show-toplevel 2>/dev/null); then
    printf '%s\n' "$root_path"
  else
    printf '%s\n' "$target_path"
  fi
}

walk_project_chain() {
  if [ "$1" != "$2" ]; then
    parent_path=$(dirname -- "$1")
    walk_project_chain "$parent_path" "$2"
  fi
  select_instruction "$1"
}

if [ -s "$codex_home_dir/AGENTS.override.md" ]; then
  global_instruction="$codex_home_dir/AGENTS.override.md"
elif [ -s "$codex_home_dir/AGENTS.md" ]; then
  global_instruction="$codex_home_dir/AGENTS.md"
else
  global_instruction=''
fi

protocol_version=$(sed -n 's/^Version: //p' "$protocol_path" | sed -n '1p')
printf '%s\n' "PREFLIGHT_PROTOCOL: Renata v${protocol_version:-unknown}"
add_file "$protocol_path" 'renata-protocol.md'

if [ -n "$global_instruction" ]; then
  add_file "$global_instruction" 'global instruction file'
fi

if [ "$#" -eq 0 ]; then
  set -- "$workdir"
fi

for target_path in "$@"; do
  if [ ! -d "$target_path" ]; then
    printf '%s\n' "PREFLIGHT_ERROR: target is not a readable directory: $target_path" >&2
    exit 1
  fi
  target_path=$(CDPATH= cd -- "$target_path" && pwd -P)
  project_root=$(project_root_for "$target_path")
  case "$target_path/" in
    "$project_root"/*) ;;
    "$project_root") ;;
    *)
      printf '%s\n' "PREFLIGHT_ERROR: target is outside its project root: $target_path" >&2
      exit 1
      ;;
  esac

  walk_project_chain "$target_path" "$project_root"
  for root_doc in CLAUDE.md GEMINI.md README.md package.json; do
    if [ -e "$project_root/$root_doc" ] && [ ! -r "$project_root/$root_doc" ]; then
      printf '%s\n' "PREFLIGHT_ERROR: root document is unreadable: $project_root/$root_doc" >&2
      exit 1
    fi
    add_file "$project_root/$root_doc" "$root_doc"
  done
done

printf '%s\n' 'PREFLIGHT_COMPLETE'
