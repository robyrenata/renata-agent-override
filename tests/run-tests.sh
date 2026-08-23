#!/usr/bin/env bash
set -euo pipefail

# Test suite for Renata's Protocol maintenance scripts. Network-free.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
TMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMP_ROOT"' EXIT

pass() { echo "PASS: $*"; }
fail_test() { echo "FAIL: $*" >&2; exit 1; }

make_lock() {
  local dest="$1" ck="$2" paths="$3"
  python3 - "$dest" "$ck" "$paths" <<'PY'
import json, sys
dest, ck, paths = sys.argv[1], sys.argv[2], json.loads(sys.argv[3])
lock = {
    "version": "test",
    "skills": [{
        "name": "fixture-skill",
        "repository_url": "unused",
        "subdirectory": "",
        "branch": "main",
        "commit_sha": "0000000000000000000000000000000000000000",
        "license": "MIT",
        "content_checksum_sha256": ck,
        "checksum_method": "sha256 of sorted '<file-sha256>  <path>' lines",
        "allowed_paths": paths,
    }],
}
with open(dest, "w", encoding="utf-8") as fh:
    json.dump(lock, fh)
PY
}

source_lib() {
  export LOCK_FILE="$TMP_ROOT/lock.json"
  export SKILLS_DIR="$TMP_ROOT/skills"
  . "$REPO_ROOT/scripts/lib-skills.sh"
}

# --- checksum binds content -------------------------------------------------

mkdir -p "$TMP_ROOT/content-a/fixture-skill"
printf 'fixture' > "$TMP_ROOT/content-a/fixture-skill/SKILL.md"
CK_A=$(source_lib && compute_checksum "$TMP_ROOT/content-a/fixture-skill")
make_lock "$TMP_ROOT/lock.json" "$CK_A" '["SKILL.md"]'
pass "compute_checksum produced fixture checksum"

printf 'changed' > "$TMP_ROOT/content-a/fixture-skill/SKILL.md"
ALT_CK=$(source_lib && compute_checksum "$TMP_ROOT/content-a/fixture-skill")
[ "$ALT_CK" != "$CK_A" ] || fail_test "content change did not alter checksum"
pass "content change alters checksum"

mv "$TMP_ROOT/content-a/fixture-skill/SKILL.md" "$TMP_ROOT/content-a/fixture-skill/OTHER.md"
CK_B=$(source_lib && compute_checksum "$TMP_ROOT/content-a/fixture-skill")
[ "$CK_B" != "$CK_A" ] || fail_test "path change did not alter checksum"
pass "path change alters checksum"

# --- allowed-path enforcement ----------------------------------------------

rm -rf "$TMP_ROOT/bad-extra"
mkdir -p "$TMP_ROOT/bad-extra"
printf 'fixture' > "$TMP_ROOT/bad-extra/SKILL.md"
echo extra > "$TMP_ROOT/bad-extra/extra.txt"
if ! (source_lib; validate_allowed_paths "$TMP_ROOT/bad-extra" 0) >/dev/null 2>&1; then :; else
  fail_test "validate_allowed_paths accepted an unexpected file"
fi
pass "unexpected file rejected"

rm -rf "$TMP_ROOT/good-skill"
mkdir -p "$TMP_ROOT/good-skill"
printf 'fixture' > "$TMP_ROOT/good-skill/SKILL.md"
echo readme > "$TMP_ROOT/good-skill/README.md"
make_lock "$TMP_ROOT/lock.json" "$CK_A" '["SKILL.md", "README.md"]'
if (source_lib; validate_allowed_paths "$TMP_ROOT/good-skill" 0) >/dev/null 2>&1; then :; else
  fail_test "valid skill rejected by validate_allowed_paths"
fi
pass "valid skill accepted"

# --- install refuses unmanaged target --------------------------------------

make_lock "$TMP_ROOT/lock.json" "$CK_A" '["SKILL.md"]'
mkdir -p "$TMP_ROOT/src-good" "$TMP_ROOT/skills/fixture-skill"
printf 'fixture' > "$TMP_ROOT/src-good/SKILL.md"
echo rogue > "$TMP_ROOT/skills/fixture-skill/SKILL.md"
if RENATA_LOCK_FILE="$TMP_ROOT/lock.json" RENATA_SKILLS_DIR="$TMP_ROOT/skills"     bash "$REPO_ROOT/scripts/manage-skills.sh" --apply >/dev/null 2>&1; then
  fail_test "install overwrote an unmanaged skill without --replace"
fi
[ "$(cat "$TMP_ROOT/skills/fixture-skill/SKILL.md")" = "rogue" ] || fail_test "unmanaged skill was modified"
pass "unmanaged skill not overwritten"

# --- sync behavior in temporary directories --------------------------------

CODEX_TARGET="$TMP_ROOT/codex/AGENTS.md"
OPENCODE_TARGET="$TMP_ROOT/opencode/AGENTS.md"

if RENATA_CODEX_AGENTS="$CODEX_TARGET" RENATA_OPENCODE_AGENTS="$OPENCODE_TARGET"     bash "$REPO_ROOT/scripts/sync-global.sh" --check >/dev/null 2>&1; then
  fail_test "sync --check passed with missing targets"
fi
pass "missing targets rejected"

RENATA_CODEX_AGENTS="$CODEX_TARGET" RENATA_OPENCODE_AGENTS="$OPENCODE_TARGET"   bash "$REPO_ROOT/scripts/sync-global.sh" --apply >/dev/null
cmp -s renata-protocol.md "$CODEX_TARGET" || fail_test "codex copy mismatch after apply"
cmp -s renata-protocol.md "$OPENCODE_TARGET" || fail_test "opencode copy mismatch after apply"
RENATA_CODEX_AGENTS="$CODEX_TARGET" RENATA_OPENCODE_AGENTS="$OPENCODE_TARGET"   bash "$REPO_ROOT/scripts/sync-global.sh" --check >/dev/null
pass "apply then check matches canonical protocol"

printf 'stale' > "$CODEX_TARGET"
if RENATA_CODEX_AGENTS="$CODEX_TARGET" RENATA_OPENCODE_AGENTS="$OPENCODE_TARGET"     bash "$REPO_ROOT/scripts/sync-global.sh" --check >/dev/null 2>&1; then
  fail_test "sync --check passed with a stale codex copy"
fi
pass "stale copy rejected"

# --- validator rejects broken artifacts ------------------------------------

SCRATCH="$TMP_ROOT/repo-copy"
run_validator_in_copy() {
  (cd "$SCRATCH" && bash scripts/validate.sh >/dev/null 2>&1)
}

mkdir -p "$SCRATCH/scripts"
cp -R "$REPO_ROOT/scripts/." "$SCRATCH/scripts/"
cp "$REPO_ROOT/skills.lock.json" "$REPO_ROOT/renata-protocol.md" "$REPO_ROOT/CHANGELOG.md" "$SCRATCH/"

run_validator_in_copy || fail_test "validator failed on unmodified copy"
pass "validator passes on clean copy"

head -n 5 renata-protocol.md > "$SCRATCH/renata-protocol.md"
if run_validator_in_copy; then
  fail_test "validator accepted out-of-range word count"
fi
pass "out-of-range word count rejected"

cp renata-protocol.md "$SCRATCH/renata-protocol.md"

python3 - "$SCRATCH/CHANGELOG.md" <<'PY'
import sys
path = sys.argv[1]
text = open(path, encoding="utf-8").read()
first = text.find("## [")
second = text.find("\n## [", first + 1)
dup = text[first:second]
open(path, "w", encoding="utf-8").write(text[:second] + "\n" + dup + text[second:])
PY
if run_validator_in_copy; then
  fail_test "validator accepted duplicate changelog release"
fi
pass "duplicate changelog release rejected"

# --- pinned-SHA fetch from a local fixture repository ----------------------

UPSTREAM="$TMP_ROOT/upstream.git"
git init -q --bare "$UPSTREAM"
WORK="$TMP_ROOT/work"
git init -q "$WORK"
git -C "$WORK" remote add origin "$UPSTREAM"
cat > "$WORK/SKILL.md" <<'EOF'
---
name: pinned-fixture
description: fixture skill for pinned-SHA fetch test
---
base
EOF
printf 'readme\n' > "$WORK/README.md"
git -C "$WORK" add .
git -C "$WORK" -c user.email=t@t -c user.name=t commit -qm pinned
PINNED_SHA=$(git -C "$WORK" rev-parse HEAD)
git -C "$WORK" push -q origin main
printf 'newer
' >> "$WORK/SKILL.md"
git -C "$WORK" add .
git -C "$WORK" -c user.email=t@t -c user.name=t commit -qm newer
git -C "$WORK" push -q origin main

git clone -q "$UPSTREAM" "$TMP_ROOT/pin-clone"
git -C "$TMP_ROOT/pin-clone" checkout -q "$PINNED_SHA"
PIN_CK=$(source_lib && compute_checksum "$TMP_ROOT/pin-clone")

python3 - "$TMP_ROOT/pinned-lock.json" "$UPSTREAM" "$PINNED_SHA" "$PIN_CK" <<'PY'
import json, sys
dest, url, sha, ck = sys.argv[1:]
lock = {
    "version": "test",
    "skills": [{
        "name": "pinned-fixture",
        "repository_url": url,
        "subdirectory": "",
        "branch": "main",
        "commit_sha": sha,
        "license": "MIT",
        "content_checksum_sha256": ck,
        "checksum_method": "sha256 of sorted '<file-sha256>  <path>' lines",
        "allowed_paths": ["SKILL.md", "README.md"],
    }],
}
with open(dest, "w", encoding="utf-8") as fh:
    json.dump(lock, fh)
PY

RENATA_LOCK_FILE="$TMP_ROOT/pinned-lock.json" RENATA_SKILLS_DIR="$TMP_ROOT/pinned-skills"   bash "$REPO_ROOT/scripts/manage-skills.sh" --apply >/dev/null
grep -q '^base$' "$TMP_ROOT/pinned-skills/pinned-fixture/SKILL.md"   || fail_test "installed content is not the pinned commit"
if grep -q '^newer$' "$TMP_ROOT/pinned-skills/pinned-fixture/SKILL.md"; then
  fail_test "installed content contains commits newer than the pin"
fi
pass "pinned SHA fetched after branch advanced"

echo "ALL TESTS PASSED."
