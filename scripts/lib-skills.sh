#!/usr/bin/env bash
# Shared helpers for Renata's Protocol skill management and tests.

die() {
  echo "error: $*" >&2
  exit 1
}

hash_file() {
  local f="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print $1}'
  else
    shasum -a 256 "$f" | awk '{print $1}'
  fi
}

hash_stdin() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    shasum -a 256 | awk '{print $1}'
  fi
}

# Checksum binds normalized relative paths and top-level file contents.
# Nested directories (examples/, references/) are content directories and are
# intentionally excluded from the checksum so docs can be updated without a
# lockfile bump. sha256 over sorted lines of "<file sha256>  <relative path>".
compute_checksum() {
  local dir="$1"
  (cd "$dir" && find . -type f \
      -not -path './.git/*' -not -path './.renata-managed*' \
      -not -path './examples/*' -not -path './references/*' \
      | LC_ALL=C sort \
      | while IFS= read -r f; do
          printf '%s  %s\n' "$(hash_file "$f")" "${f#./}"
        done) | hash_stdin
}

require_lock() {
  [ -f "$LOCK_FILE" ] || die "lock file not found: $LOCK_FILE"
}

get_skill_count() {
  python3 -c "import json; d=json.load(open('$LOCK_FILE')); print(len(d['skills']))"
}

get_skill_field() {
  local idx="$1" field="$2"
  python3 -c "
import json
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

validate_frontmatter() {
  local skill_md="$1/SKILL.md"
  [ -f "$skill_md" ] || die "missing SKILL.md in $1"
  head -1 "$skill_md" | grep -q '^---' || die "missing frontmatter in $skill_md"
  sed -n '2p' "$skill_md" | grep -q 'name:' || die "missing name field in $skill_md"
  grep -q 'description:' "$skill_md" || die "missing description field in $skill_md"
}

validate_allowed_paths() {
  local dir="$1" idx="$2" expected actual allowed
  while IFS= read -r expected; do
    [ -z "$expected" ] && continue
    [ -f "$dir/$expected" ] || die "missing required path: $expected"
  done < <(get_skill_allowed_paths "$idx")
  while IFS= read -r actual; do
    [ -z "$actual" ] && continue
    actual="${actual#./}"
    allowed=0
    while IFS= read -r expected; do
      [ -z "$expected" ] && continue
      if [ "$actual" = "$expected" ]; then
        allowed=1
        break
      fi
    done < <(get_skill_allowed_paths "$idx")
    if [ "$allowed" -eq 0 ]; then
      die "unexpected file in skill: $actual (not in allowed_paths)"
    fi
  done < <(cd "$dir" && find . -type f \
      -not -path './.git/*' -not -path './.renata-managed*' | LC_ALL=C sort)
}

# Fetch an exact pinned commit, even when it is no longer the branch tip.
download_skill() {
  local idx="$1" dest="$2"
  local repo sub sha name clone_dir
  name=$(get_skill_field "$idx" "name")
  repo=$(get_skill_field "$idx" "repository_url")
  sub=$(get_skill_field "$idx" "subdirectory")
  sha=$(get_skill_field "$idx" "commit_sha")
  dest="$dest/$name"
  mkdir -p "$dest"
  clone_dir="$dest/.clone"
  rm -rf "$clone_dir"
  git init -q "$clone_dir"
  # Local or file:// remotes are used verbatim; GitHub URLs get .git appended.
  case "$repo" in
    http://*|https://*|git@*) repo="${repo}.git" ;;
  esac
  git -C "$clone_dir" remote add origin "$repo"
  git -C "$clone_dir" fetch -q --depth 1 origin "$sha" \
    || { rm -rf "$clone_dir"; die "cannot fetch pinned commit $sha for $name"; }
  git -C "$clone_dir" checkout -q FETCH_HEAD
  rm -rf "$clone_dir/.git"
  if [ -n "$sub" ]; then
    [ -d "$clone_dir/$sub" ] || { rm -rf "$dest"; die "missing subdirectory $sub in $name"; }
    (shopt -s dotglob && cp -R "$clone_dir/$sub/"* "$dest/")
    rm -rf "$clone_dir"
  else
    (shopt -s dotglob && mv "$clone_dir/"* "$dest/") \
      || { rm -rf "$dest"; die "empty download for $name"; }
  fi
}
