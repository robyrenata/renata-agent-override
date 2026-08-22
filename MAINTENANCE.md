
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
3. Validate the protocol. See the checks below.
4. Review upstream changes: scripts/manage-skills.sh --refresh-lock. Inspect
   each changed skill for new files, hooks, network calls, executables, and
   license changes before updating skills.lock.json.
5. Validate installed skills: scripts/manage-skills.sh --check
6. Sync global copies: scripts/sync-global.sh --apply --check
7. Commit with a conventional message, such as feat(protocol): ...

## Global targets

- Codex:  ${CODEX_HOME:-$HOME/.codex}/AGENTS.md
- OpenCode:  ${XDG_CONFIG_HOME:-$HOME/.config}/opencode/AGENTS.md

## Validation checks

wc -w renata-protocol.md
rg -n '[\u2014\u2013\u201c\u201d\u2018\u2019]' renata-protocol.md
python3 -m json.tool skills.lock.json >/dev/null
scripts/manage-skills.sh --check
scripts/sync-global.sh --check
