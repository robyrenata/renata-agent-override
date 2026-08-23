#!/usr/bin/env bash
set -euo pipefail

# Deterministic validation for Renata's Protocol. No network access.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$REPO_ROOT"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

[ -f renata-protocol.md ] || fail "missing renata-protocol.md"

# Word count: MAINTENANCE.md requires 700 to 1000 words.
WORDS=$(wc -w < renata-protocol.md | tr -d ' ')
if [ "$WORDS" -lt 700 ] || [ "$WORDS" -gt 1000 ]; then
  fail "protocol word count out of range: $WORDS (allowed 700..1000)"
fi

# Version and date formats.
grep -Eq '^Version: [0-9]+\.[0-9]+\.[0-9]+$' renata-protocol.md \
  || fail "missing or malformed Version line"
grep -Eq '^Last updated: [0-9]{4}-[0-9]{2}-[0-9]{2}$' renata-protocol.md \
  || fail "missing or malformed Last updated line"
VERSION=$(sed -n 's/^Version: //p' renata-protocol.md)
DATE=$(sed -n 's/^Last updated: //p' renata-protocol.md)
grep -qF "## [$VERSION] - $DATE" CHANGELOG.md \
  || fail "changelog has no entry matching protocol version and date"

# Punctuation policy: no em dashes, en dashes, or curly quotes.
if rg -n '[\u2014\u2013\u201c\u201d\u2018\u2019]' renata-protocol.md >/dev/null 2>&1; then
  fail "forbidden punctuation found in renata-protocol.md"
fi

# Changelog ordering: newest release heading first, no duplicate versions.
python3 - <<'PY'
import json, re, sys

text = open("CHANGELOG.md", encoding="utf-8").read()
versions = re.findall(r"^## \[([^]]+)\]", text, re.M)
if not versions:
    print("FAIL: no changelog releases found")
    sys.exit(1)
if len(versions) != len(set(versions)):
    print("FAIL: duplicate changelog release headings")
    sys.exit(1)

def key(v):
    m = re.match(r"(\d+)\.(\d+)\.(\d+)$", v)
    if not m:
        return None
    return tuple(map(int, m.groups()))

parsed = [key(v) for v in versions]
if any(p is None for p in parsed):
    print("FAIL: changelog contains an unparsable semantic version")
    sys.exit(1)
if parsed != sorted(parsed, reverse=True):
    print("FAIL: changelog releases are not in descending order")
    sys.exit(1)
PY

# Lockfile structure and allowed-path uniqueness.
python3 - <<'PY'
import json, re, sys

REQUIRED_FIELDS = [
    "name",
    "repository_url",
    "subdirectory",
    "branch",
    "commit_sha",
    "license",
    "content_checksum_sha256",
    "checksum_method",
    "allowed_paths",
]

try:
    with open("skills.lock.json", encoding="utf-8") as fh:
        lock = json.load(fh)
except Exception as exc:
    print(f"FAIL: cannot parse skills.lock.json: {exc}")
    sys.exit(1)

skills = lock.get("skills")
if not isinstance(skills, list) or not skills:
    print("FAIL: lockfile has no skills list")
    sys.exit(1)
names = set()
shas = set()
for i, skill in enumerate(skills):
    label = f"skill[{i}]"
    missing = [f for f in REQUIRED_FIELDS if f not in skill]
    if missing:
        print(f"FAIL: {label} missing fields: {', '.join(missing)}")
        sys.exit(1)
    sha = skill["commit_sha"]
    if not re.fullmatch(r"[0-9a-f]{40}", sha):
        print(f"FAIL: {label} commit_sha is not a full 40-character SHA")
        sys.exit(1)
    ck = skill["content_checksum_sha256"]
    if not re.fullmatch(r"[0-9a-f]{64}", ck):
        print(f"FAIL: {label} checksum is malformed")
        sys.exit(1)
    paths = skill["allowed_paths"]
    if len(paths) != len(set(paths)):
        print(f"FAIL: {label} has duplicate allowed_paths entries")
        sys.exit(1)
    if any(p.startswith("/") or ".." in p.split("/") for p in paths):
        print(f"FAIL: {label} allowed_paths must be repo-relative without traversal")
        sys.exit(1)
    if skill["name"] in names:
        print(f"FAIL: duplicate skill name {skill['name']}")
        sys.exit(1)
    names.add(skill["name"])
    shas.add((skill["repository_url"], sha))
PY

# Shell syntax.
bash -n scripts/lib-skills.sh || fail "scripts/lib-skills.sh fails bash -n"
bash -n scripts/manage-skills.sh || fail "scripts/manage-skills.sh fails bash -n"
bash -n scripts/sync-global.sh || fail "scripts/sync-global.sh fails bash -n"
bash -n scripts/validate.sh || fail "scripts/validate.sh fails bash -n"

echo "validation passed."
