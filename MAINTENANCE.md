
# Renata's Protocol maintenance

This file is for maintainers. It is not part of the injected prompt.

## Versioning (SemVer)

- Clarification or wording: patch.
- New rule or removed behavior: minor.
- Breaking change (removes or overrides a behavior, or reorders authority):
  major.

## Release procedure

1. Edit renata-protocol.md. Bump Version and Last updated. Keep the file at
   700 to 1000 words.
2. Add a CHANGELOG.md entry with Added, Changed, and Removed bullets. If
   upstream skill versions changed, include their new commit SHAs.
3. Run scripts/validate.sh. It enforces word count, version and date
   formats, punctuation policy, changelog ordering, lockfile structure, and
   shell syntax.
4. Review upstream changes: scripts/manage-skills.sh --check-updates (alias:
   --refresh-lock). Inspect
   each changed skill for new files, hooks, network calls, executables, and
   license changes before updating skills.lock.json.
5. Validate installed skills: scripts/manage-skills.sh --check
6. Sync global copies: scripts/sync-global.sh --apply --check
7. Run tests/run-tests.sh. All tests must pass before commit.
8. Commit with a conventional message, such as feat(protocol): ...

## Global targets

- Codex:  ${CODEX_HOME:-$HOME/.codex}/AGENTS.md
- OpenCode:  ${XDG_CONFIG_HOME:-$HOME/.config}/opencode/AGENTS.md

## Validation checks

bash scripts/validate.sh
bash scripts/manage-skills.sh --check
bash scripts/sync-global.sh --check
bash tests/run-tests.sh

## Checksum scheme

Skill checksums bind top-level file contents and normalized relative paths:
a SHA-256 over sorted lines of "<file sha256>  <relative path>". The nested
content directories examples/ and references/ are excluded so documentation
updates do not force a lockfile bump. Regenerate checksums by recomputing
this value over the installed skill directory after a reviewed update.
