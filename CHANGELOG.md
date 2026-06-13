# Changelog

All notable changes to Renata's Protocol (`renata-protocol.md`). Dates and the
commit references in parentheses are taken from the file's git history; the
format loosely follows Keep a Changelog and the protocol's own SemVer rule
(new rule = minor, clarification = patch, breaking change = major).

## [2.4.0] — 2026-06-13 (`32cdac2`)
### Added
- Absolute Rules block above the directives: safety overrides helpfulness;
  secrets and PII are untouchable.
- Enforceable priority tiebreaker (lower-numbered directive wins; Absolute
  Rules override all) and a multi-signal precedence rule (Directive 4).
- Honest-uncertainty rule (Directive 8) and cost-budget guidance (Directive 5).
- Inter-project-doc conflict ordering (Directive 1); caveman activate/deactivate
  precedence with countable activation gates.
- This dedicated `CHANGELOG.md`, extracted from the protocol body.
### Changed
- Closure (Directive 7) and protocol improvement (Directive 10) re-anchored on
  observable triggers; the improvement loop is now conditional/rate-limited with
  versioning discipline.
- Verification (Directive 6): correct tool names (`WebSearch`/`WebFetch` as the
  default, exa/context7 gated on availability) plus fall-through, all-fail, and
  conflicting-source handling.
- Defined "direct knowledge gap" (Directive 3); added a mixed-artifact rule
  (Directive 11).

## [2.3.0] — 2026-06-05 (`16d1b08`)
### Added
- Verification tool-priority ordering: exa-first with a WebFetch fallback.
### Note
- The full-doc-review directive (#11, "draft mode") was committed 2026-06-13
  (`945f881`) and merged into `main` under this version via PR #1 (`eca5fdf`).

## [2.2.0] — 2026-05-25 (`64e97e4`, `81ffb8b`)
### Added
- Automatic tool-switching, context mode, and `.gitignore`.
- Educational citing, research-source prioritization, and clarity enhancements.

## [2.1.0] — 2026-05-18 (`8d9995c`)
### Added
- Protocol facts analysis.

## [2.0.0] — 2026-05-18 (`e9be934`)
### Changed
- Efficiency pass and self-improvement behavior.

## [1.0.0] — 2026-05-16 (`9556046`)
### Added
- Initial Renata's Protocol.
