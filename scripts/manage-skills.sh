#!/usr/bin/env bash
set -euo pipefail

# Manage pinned upstream skills for Renata's Protocol.
# Usage:
#   scripts/manage-skills.sh --apply
#   scripts/manage-skills.sh --check
#   scripts/manage-skills.sh --refresh-lock
#   scripts/manage-skills.sh --replace <skill>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
LOCK_FILE="$REPO_ROOT/skills.lock.json"
SKILLS_DIR="${HOME}/.agents/skills"
MANAGED_MARKER=".renata-managed"

die() {
  echo "error: $*" >&2
  exit 1
}

require_lock() {
  [ -f "$LOCK_FILE" ] || die "lock file not found: $LOCK_FILE"
}

get_skill_count() {
  python3 -c "import json,sys; d=json.load(open('$LOCK_FILE')); print(len(d['skills']))"
}

get_skill_field() {
  local idx="$1" field="$2"
  python3 -c "
import json,sys
d=json.load(open('$LOCK_FILE'))
s=d['skills'][$idx]
print(s.get('$field',''))
"
}

get_skill_allowed_paths() {
  local idx="$1"
  python3 -c "
import json
d=json.load(open('$LOCK_FILE'))
for p in d['skills'][$idx].get('allowed_paths',[]):
    print(p)
"
}

compute_checksum() {
  local dir="$1"
  (cd "$dir" && find . -type f -not -path './.git/*' -not -path './.renata-managed*' | sort | while read -r f; do shasum -a 256 "$f" | awk '{print $1}'; done) | shasum -a 256 | awk '{print $1}'
}

validate_frontmatter() {
  local skill_md="$1"
  head -1 "$skill_md" | grep -q '^---' || die "missing frontmatter in $skill_md"
  sed -n '2p' "$skill_md" | grep -q 'name:' || die "missing name field in $skill_md"
  grep -q 'description:' "$skill_md" || die "missing description field in $skill_md"
}

validate_allowed_paths() {
  local dir="$1" idx="$2"
  while IFS= read -r expected; do
    [ -z "$expected" ] && continue
    [ -f "$dir/$expected" ] || die "missing required path: $expected"
  done < <(get_skill_allowed_paths "$idx")
  # Reject any file not in allowed_paths
  while IFS= read -r actual; do
    [ -z "$actual" ] && continue
    allowed=0
    while IFS= read -r expected; do
      [ -z "$expected" ] && continue
      if [ "$(echo "$actual" | sed 's|^./||')" = "$expected" ]; then
        allowed=1
        break
      fi
    done < <(get_skill_allowed_paths "$idx")
    if [ "$allowed" -eq 0 ]; then
      die "unexpected file in skill: $actual (not in allowed_paths)"
    fi
  done < <(cd "$dir" && find . -type f -not -path './.git/*' -not -path './.renata-managed*' | sort)
}

download_skill() {
  local idx="$1" tmp_base="$2"
  local repo sub branch sha name
  name=$(get_skill_field "$idx" "name")
  repo=$(get_skill_field "$idx" "repository_url")
  sub=$(get_skill_field "$idx" "subdirectory")
  branch=$(get_skill_field "$idx" "branch")
  sha=$(get_skill_field "$idx" "commit_sha")

  local dest="$tmp_base/$name"
  mkdir -p "$dest"

  local clone_dir="$dest/.clone"
  rm -rf "$clone_dir"

  if [ -z "$sub" ]; then
    git clone --depth 1 "${repo}.git" "$clone_dir" 2>/dev/null
    (cd "$clone_dir" && git checkout -q "$sha" && rm -rf .git)
    cp -R "$clone_dir/"* "$dest/"
    rm -rf "$clone_dir"
  else
    git clone --depth 1 --filter=blob:none --sparse "${repo}.git" "$clone_dir" 2>/dev/null
    (cd "$clone_dir" && git checkout -q "$sha" && git sparse-checkout set "$sub")
    cp -R "$clone_dir/$sub/"* "$dest/"
    rm -rf "$clone_dir"
  fi
}

install_skill() {
  local src="$1" name="$2" idx="$3"
  local target="$SKILLS_DIR/$name"

  validate_frontmatter "$src/SKILL.md"
  validate_allowed_paths "$src" "$idx"

  mkdir -p "$SKILLS_DIR"

  if [ -d "$target" ] && [ ! -f "$target/$MANAGED_MARKER" ]; then
    echo "warning: unmanaged skill exists at $target" >&2
    return 1
  fi

  rm -rf "$target"
  cp -R "$src" "$target"
  touch "$target/$MANAGED_MARKER"
  echo "installed $name -> $target"
}

backup_existing() {
  local target="$1"
  if [ -d "$target" ] && [ ! -f "$target/$MANAGED_MARKER" ]; then
    local backup="${target}.bak.$(date +%Y%m%d%H%M%S)"
    mv "$target" "$backup"
    echo "backed up $target -> $backup"
  fi
}

ACTION=""
REPLACE_SKILL=""

while [ "$#" -ge 1 ]; do
  case "$1" in
    --apply) ACTION="apply" ;;
    --check) ACTION="check" ;;
    --refresh-lock) ACTION="refresh-lock" ;;
    --replace)
      ACTION="replace"
      shift
      REPLACE_SKILL="${1:-}"
      ;;
    *) echo "usage: $(basename "$0") [--apply] [--check] [--refresh-lock] [--replace <skill>]" >&2; exit 2 ;;
  esac
  shift
done

[ -n "$ACTION" ] || { echo "usage: $(basename "$0") [--apply] [--check] [--refresh-lock] [--replace <skill>]" >&2; exit 2; }
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

  refresh-lock)
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
    [ -n "$REPLACE_SKILL" ] || die "--replace requires a skill name"
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
        echo "replaced $NAME with managed version."
        FOUND=1
        break
      fi
    done
    [ "$FOUND" -eq 1 ] || die "skill not found in lock: $REPLACE_SKILL"
    ;;
esac
