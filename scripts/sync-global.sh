#!/usr/bin/env bash
set -euo pipefail

# Sync the canonical protocol to global agent instruction files.
# Usage:
#   scripts/sync-global.sh --check
#   scripts/sync-global.sh --apply [--check]
#
# Environment overrides (intended for tests):
#   RENATA_CODEX_AGENTS    target path for the Codex copy
#   RENATA_OPENCODE_AGENTS target path for the OpenCode copy

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CANONICAL="$(dirname "$SCRIPT_DIR")/renata-protocol.md"
CODEX_AGENTS="${RENATA_CODEX_AGENTS:-${CODEX_HOME:-$HOME/.codex}/AGENTS.md}"
OPENCODE_AGENTS="${RENATA_OPENCODE_AGENTS:-${XDG_CONFIG_HOME:-$HOME/.config}/opencode/AGENTS.md}"

usage() {
  echo "usage: $(basename "$0") [--apply] [--check]" >&2
  echo "  --apply  copy the canonical protocol to the global targets" >&2
  echo "  --check  verify each global copy matches the canonical file" >&2
}

[ "$#" -ge 1 ] || { usage; exit 2; }

APPLY=0
CHECK=0
for arg in "$@"; do
  case "$arg" in
    --apply) APPLY=1 ;;
    --check) CHECK=1 ;;
    *) usage; exit 2 ;;
  esac
done

if [ ! -f "$CANONICAL" ]; then
  die "canonical protocol not found: $CANONICAL"
fi

sync_one() {
  local target="$1"
  mkdir -p "$(dirname "$target")"
  cp "$CANONICAL" "$target"
  if ! cmp -s "$CANONICAL" "$target"; then
    die "sync failed for $target"
  fi
  echo "synced $target"
}

check_one() {
  local target="$1"
  if cmp -s "$CANONICAL" "$target"; then
    echo "ok: $target"
  else
    die "mismatch: $target"
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
