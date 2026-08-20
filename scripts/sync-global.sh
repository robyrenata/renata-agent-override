#!/usr/bin/env bash
set -euo pipefail

# Sync the canonical protocol to global agent instruction files.
# Usage:
#   scripts/sync-global.sh --check
#   scripts/sync-global.sh --apply [--check]

CANONICAL="$(cd "$(dirname "$0")/.." && pwd)/renata-protocol.md"
CODEX_AGENTS="${CODEX_HOME:-$HOME/.codex}/AGENTS.md"
OPENCODE_AGENTS="${XDG_CONFIG_HOME:-$HOME/.config}/opencode/AGENTS.md"

usage() {
  echo "usage: $(basename "$0") [--apply] [--check]" >&2
  echo "  --apply  copy the canonical protocol to the global targets" >&2
  echo "  --check  verify each global copy matches the canonical file" >&2
  exit 2
}

[ "$#" -ge 1 ] || usage

APPLY=0
CHECK=0
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    --check) CHECK=1 ;;
    *) usage ;;
  esac
done

if [ ! -f "$CANONICAL" ]; then
  echo "error: canonical protocol not found: $CANONICAL" >&2
  exit 1
fi

sync_one() {
  local target="$1"
  mkdir -p "$(dirname "$target")"
  cp "$CANONICAL" "$target"
  if ! cmp -s "$CANONICAL" "$target"; then
    echo "error: sync failed for $target" >&2
    exit 1
  fi
  echo "synced $target"
}

check_one() {
  local target="$1"
  if cmp -s "$CANONICAL" "$target"; then
    echo "ok: $target"
  else
    echo "error: mismatch: $target" >&2
    exit 1
  fi
}

if [ "$APPLY" -eq 1 ]; then
  sync_one "$CODEX_AGENTS"
  sync_one "$OPENCODE_AGENTS"
fi

if [ "$CHECK" -eq 1 ]; then
  check_one "$CODEX_AGENTS"
  check_one "$OPENCODE_AGENTS"
fi

