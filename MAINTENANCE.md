
# Renata's Protocol maintenance

This file is for maintainers. It is not part of the injected prompt.

## Versioning (SemVer)

- Clarification or wording: patch.
- New rule or removed behavior: minor.
- Breaking change (removes or overrides a behavior, or reorders authority):
  major.

## Release procedure

1. Edit renata-protocol.md. Bump Version and Last updated. Keep the file at
   700 to 900 words.
2. Add a CHANGELOG.md entry with Added, Changed, and Removed bullets.
3. Validate the protocol. See the checks below.
4. Sync global copies: scripts/sync-global.sh --apply --check
5. Commit with a conventional message, such as feat(protocol): ...

## Global target paths

- Codex:  ${CODEX_HOME:-$HOME/.codex}/AGENTS.md
- OpenCode:  ${XDG_CONFIG_HOME:-$HOME/.config}/opencode/AGENTS.md
- Claude: references the canonical file from the repository.

## Validation checks

wc -w renata-protocol.md
rg -n '[\u2014\u2013\u201c\u201d\u2018\u2019]' renata-protocol.md
rg -n 'Protocol context' renata-protocol.md

