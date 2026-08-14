# Changelog

All notable changes to Renata's Protocol (`renata-protocol.md`). Dates and the
commit references in parentheses are taken from the file's git history; the
format loosely follows Keep a Changelog and the protocol's own SemVer rule
(new rule = minor, clarification = patch, breaking change = major).

## [3.1.0] — 2026-08-13
### Added
- ASD-STE100 best-effort rules for English technical passages, with literal
  text preservation, non-English handling, risk-based validation, and meaning
  preservation.
- A mandatory project-document preflight gate with a visible acknowledgment,
  completion sentinel, target-directory recheck, and final compliance check.
- `scripts/protocol-preflight.sh`, a read-only helper that emits the canonical
  protocol and applicable global/project instruction files.
- A global Codex bootstrap requirement for the preflight helper.

## [3.0.0] — 2026-07-08
### Removed
- `Changelog: see CHANGELOG.md` header line and all in-rule
  `*Added/Changed <date>*` annotations — per-rule history lives in
  CHANGELOG.md and git.
- Boundaries section: redundant bullets deleted; unique items folded into
  Absolute Rules (irreversible-action confirmation), Directive 3 (teaching
  tangents, no lecturing), Directive 8 (out-of-scope architecture asks).
### Changed
- Directive 10 no longer mandates in-body date annotations; versioning =
  SemVer bump + Last updated + changelog entry.
- No directive semantics changed.

## [2.5.0] — 2026-07-08 (`68e1272`)
### Added
- Delegation & model economy subsection under Agent Automation Rules: plan
  strong, execute cheap — frontier model reserved mostly for planning,
  brainstorming, design, and judgment in the main loop; delegate
  well-specified mechanical work to subagents/cheaper models, run
  independent pieces in parallel, verify delegated output. Default workflow:
  plan first in the main loop, then delegate execution (building, writing,
  grunt work) to the cheapest, fastest model that meets the spec; escalate
  only on demonstrable shortfall; trivial inline edits exempt. Applies to
  delegated work — main-loop model stays the user's choice.
### Changed
- Explicit winner for the #5 vs #6 conflict: verification beats tool/token
  economy, using the preamble's explicit-winner escape hatch (aligned with
  Directive 4's verification > speed precedence).
- Verification (Directive 6): tool references reworded to prioritize exa
  semantic-search tools, then fall through to other available tools, instead
  of hardcoded tool names; merged the no-tool and all-fail cases; added a
  guard against re-verifying facts already established in-session. Trigger
  conditions unchanged.
- Caveman auto-management condensed from ~18 lines to 6; gating, gates,
  user-override-wins, and deactivate-wins-on-conflict all preserved.

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
