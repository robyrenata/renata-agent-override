#!/usr/bin/env bash
set -euo pipefail

# Manage pinned upstream skills for Renata's Protocol.
# Usage:
#   scripts/manage-skills.sh --apply
#   scripts/manage-skills.sh --check
#   scripts/manage-skills.sh --check-updates
#   scripts/manage-skills.sh --replace <skill>
#
# Environment overrides (intended for tests):
#   RENATA_LOCK_FILE   lockfile path (default: <repo>/skills.lock.json)
#   RENATA_SKILLS_DIR  installation root (default: ~/.agents/skills)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
LOCK_FILE="$REPO_ROOT/skills.lock.json"
LOCK_FILE="${RENATA_LOCK_FILE:-$LOCK_FILE}"
SKILLS_DIR="${RENATA_SKILLS_DIR:-$HOME/.agents/skills}"
MANAGED_MARKER=".renata-managed"

source "$SCRIPT_DIR/lib-skills.sh"

usage() {
  echo "usage: $(basename "$0") [--apply] [--check] [--check-updates] [--replace <skill>]" >&2
}

backup_existing() {
  local target="$1"
  if [ -d "$target" ] && [ ! -f "$target/$MANAGED_MARKER" ]; then
    local backup
    backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
    mv "$target" "$backup"
    echo "backed up $target -> $backup"
  fi
}

install_skill() {
  local src="$1" name="$2" idx="$3"
  local target="$SKILLS_DIR/$name"

  validate_frontmatter "$src"
  validate_allowed_paths "$src" "$idx"

  mkdir -p "$SKILLS_DIR"
  if [ -d "$target" ] && [ ! -f "$target/$MANAGED_MARKER" ]; then
    die "unmanaged skill exists at $target; use --replace to back it up"
  fi
  rm -rf "$target"
  cp -R "$src" "$target"
  touch "$target/$MANAGED_MARKER"
  echo "installed $name -> $target"
}

ACTION=""
REPLACE_SKILL=""

while [ "$#" -ge 1 ]; do
  case "$1" in
    --apply) ACTION="apply" ;;
    --check) ACTION="check" ;;
    --refresh-lock|--check-updates) ACTION="check-updates" ;;
    --replace)
      ACTION="replace"
      shift
      REPLACE_SKILL="${1:-}"
      ;;
    *) usage; exit 2 ;;
  esac
  shift
done

[ -n "$ACTION" ] || { usage; exit 2; }
require_lock

case "$ACTION" in
  apply)
    TMP_SKILL_DIR=$(mktemp -d)
    trap 'rm -rf "$TMP_SKILL_DIR"' EXIT
    COUNT=$(get_skill_count)
    for i in $(seq 0 $((COUNT-1))); do
      NAME=$(get_skill_field "$i" "name")
      download_skill "$i" "$TMP_SKILL_DIR"
      SKILL_SRC="$TMP_SKILL_DIR/$NAME"
      ACTUAL=$(compute_checksum "$SKILL_SRC")
      EXPECTED=$(get_skill_field "$i" "content_checksum_sha256")
      if [ "$ACTUAL" != "$EXPECTED" ]; then
        die "checksum mismatch for $NAME: expected $EXPECTED, got $ACTUAL"
      fi
      install_skill "$SKILL_SRC" "$NAME" "$i"
    done
    echo "all skills applied."
    ;;

  check)
    COUNT=$(get_skill_count)
    FAIL=0
    for i in $(seq 0 $((COUNT-1))); do
      NAME=$(get_skill_field "$i" "name")
      TARGET="$SKILLS_DIR/$NAME"
      EXPECTED_CK=$(get_skill_field "$i" "content_checksum_sha256")
      MARKER="$TARGET/$MANAGED_MARKER"
      if [ ! -d "$TARGET" ]; then
        echo "MISSING: $NAME ($TARGET does not exist)" >&2
        FAIL=1
        continue
      fi
      if [ ! -f "$MARKER" ]; then
        echo "UNMANAGED: $NAME (no marker at $MARKER)" >&2
        FAIL=1
        continue
      fi
      ACTUAL=$(compute_checksum "$TARGET")
      if [ "$ACTUAL" != "$EXPECTED_CK" ]; then
        echo "CHECKSUM MISMATCH: $NAME expected $EXPECTED_CK got $ACTUAL" >&2
        FAIL=1
        continue
      fi
      echo "OK: $NAME"
    done
    exit "$FAIL"
    ;;

  check-updates)
    COUNT=$(get_skill_count)
    for i in $(seq 0 $((COUNT-1))); do
      NAME=$(get_skill_field "$i" "name")
      REPO_URL=$(get_skill_field "$i" "repository_url")
      OLD_SHA=$(get_skill_field "$i" "commit_sha")
      BRANCH=$(get_skill_field "$i" "branch")
      NEW_SHA=$(git ls-remote "${REPO_URL}.git" "refs/heads/$BRANCH" | awk '{print $1}')
      if [ "$OLD_SHA" = "$NEW_SHA" ]; then
        echo "UP TO DATE: $NAME ($OLD_SHA)"
      else
        echo "UPDATE AVAILABLE: $NAME"
        echo "  old: $OLD_SHA"
        echo "  new: $NEW_SHA"
        echo "  review: ${REPO_URL}/compare/${OLD_SHA:0:12}...${NEW_SHA:0:12}"
      fi
    done
    echo ""
    echo "Review each change before updating skills.lock.json."
    ;;

  replace)
    [ -n "$REPLACE_SKILL" ] || { usage >&2; exit 2; }
    TARGET="$SKILLS_DIR/$REPLACE_SKILL"
    backup_existing "$TARGET"
    COUNT=$(get_skill_count)
    FOUND=0
    for i in $(seq 0 $((COUNT-1))); do
      NAME=$(get_skill_field "$i" "name")
      if [ "$NAME" = "$REPLACE_SKILL" ]; then
        TMP_SKILL_DIR=$(mktemp -d)
        trap 'rm -rf "$TMP_SKILL_DIR"' EXIT
        download_skill "$i" "$TMP_SKILL_DIR"
        SKILL_SRC="$TMP_SKILL_DIR/$NAME"
        ACTUAL=$(compute_checksum "$SKILL_SRC")
        EXPECTED=$(get_skill_field "$i" "content_checksum_sha256")
        if [ "$ACTUAL" != "$EXPECTED" ]; then
          die "checksum mismatch for $NAME"
        fi
        install_skill "$SKILL_SRC" "$NAME" "$i"
        echo "replaced $REPLACE_SKILL with managed version."
        FOUND=1
        break
      fi
    done
    [ "$FOUND" -eq 1 ] || die "skill not found in lock: $REPLACE_SKILL"
    ;;
esac
