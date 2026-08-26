# next-semver custom Bump Type rules via `.semver.json`

Status: ready-for-agent

## Problem Statement

`next-semver.sh` derives its Bump Type entirely from a fixed set of Conventional Commits prefixes: `fix:` → patch, `feat:` → minor, `BREAKING CHANGE:`/`!` → major. Teams that use additional commit types (`perf:`, `refactor:`, `docs:`, etc.) or disagree with the built-in mapping have no way to express that — the README's Limitations section already documents this as a known, deferred gap ("Bump Type rules are fixed... no custom rules via a config file yet"). Without a way to customize this, those teams either can't adopt the tool or have to fork it.

## Solution

An optional `.semver.json` config file at the repo root that lets a project define its own commit-type → Bump Type mapping. Its `rules` object is keyed by commit-type keyword (e.g. `"perf"`, `"docs"`), each mapped to one of `"major"`, `"minor"`, `"patch"`, or `"none"`. Entries for `feat`/`fix` override the built-in defaults; entries for new keywords add to them. The file is entirely optional — when absent, `next-semver.sh` behaves exactly as it does today. A companion `semver.schema.json` at the repo root gives editors autocomplete/validation via an optional `"$schema"` key.

## User Stories

1. As a developer, I want to add a `.semver.json` file to my repo, so that I can customize which commit types produce which Bump Type without forking the script.
2. As a developer, I want `next-semver.sh` to work exactly as it does today when no `.semver.json` is present, so that adopting this feature is entirely opt-in and existing consumers are unaffected.
3. As a developer, I want to add a brand-new commit-type keyword (e.g. `"perf": "patch"`) that isn't one of the built-in `feat`/`fix` types, so that I can extend the tool's vocabulary to match my team's commit conventions.
4. As a developer, I want to redefine one of the built-in mappings (e.g. `"feat": "major"`), so that I can make the tool match my team's own semver policy rather than the Conventional Commits default.
5. As a developer, I want any commit-type mapping not mentioned in my `.semver.json` to keep its built-in default (`feat`→minor, `fix`→patch), so that I only have to specify what I want to change or add, not the whole rule set.
6. As a developer, I want to map a commit type to `"none"`, so that I can explicitly declare that a type (e.g. `docs:`, `chore:`) never triggers a version bump, rather than relying on it being silently ignored by omission.
7. As a developer, I want commit-type matching from `.semver.json` to be case-sensitive and lowercase-only (matching the existing hardcoded `feat:`/`fix:` checks), so that behavior is consistent regardless of whether a type came from the built-in rules or my config.
8. As a developer, I want the highest-precedence Bump Type across the whole commit range (major > minor > patch > none) to still win when custom rules are in play, unchanged from today's precedence behavior, so that a single breaking-change commit in a batch of lower-precedence commits still produces a major bump.
9. As a developer, I want `BREAKING CHANGE:` footer / `!` suffix detection to remain fixed and independent of `.semver.json`, so that the ceiling Bump Type (major) always means what it says regardless of config, since a `type:` prefix key can't represent that different detection mechanism anyway.
10. As a developer, I want the schema to reject `"breaking"` as a rules key, so that I don't mistakenly believe breaking-change detection is configurable through the same mechanism as ordinary commit types.
11. As a developer, I want `next-semver.sh` to fail with a clear, non-zero-exit error when `.semver.json` contains invalid JSON, so that a syntax typo in my config is caught immediately rather than silently falling back to defaults or computing a wrong version.
12. As a developer, I want `next-semver.sh` to fail with a clear, non-zero-exit error when `.semver.json` contains a rules value outside `"major"`/`"minor"`/`"patch"`/`"none"`, or a rules key that doesn't match `^[a-z]+$`, so that malformed config is caught rather than silently ignored.
13. As a developer, I want `.semver.json` to always be read from the repo root with no override mechanism (env var, CLI flag, Action input), so that behavior stays predictable and consistent with the script's existing zero-argument, zero-input design.
14. As a developer using the GitHub Action, I want `.semver.json` support to work automatically with no changes to how I invoke the Action, so that the Action's existing zero-input contract (README's "Usage as a GitHub Action" section) is unaffected.
15. As a developer, I want a `semver.schema.json` file shipped alongside the script, so that I can reference it via an optional `"$schema"` key in my `.semver.json` for editor autocomplete and validation.
16. As a developer, I want `"$schema"` to be entirely optional in `.semver.json`, so that I'm not forced to adopt schema tooling just to use custom rules.
17. As a maintainer reading the README, I want the Limitations section updated to reflect that custom Bump Type rules are now supported, while noting that type-and-scope combinations (e.g. rules scoped to `feat(api):` specifically) remain a deferred future possibility, so that the documented scope of this feature is accurate and its natural next step is signposted.
18. As a maintainer, I want an ADR recording the decision to scope custom rules to commit-type → Bump Type mapping only (not tag-pattern or initial-version customization), so that future contributors understand why those adjacent asks are out of scope for this pass.

## Implementation Decisions

- **New file**: `.semver.json` at the repo root — optional. Its absence is not an error; `next-semver.sh` runs with the built-in fixed rules exactly as it does today.
- **New file**: `semver.schema.json` at the repo root (flat, sibling to `.semver.json` and `next-semver.sh`, matching this repo's existing flat layout — no `schema/` subdirectory).
- **Config shape**: a single top-level `rules` object, type-keyed:
  ```json
  {
    "rules": {
      "feat": "minor",
      "fix": "patch",
      "perf": "patch",
      "docs": "none"
    }
  }
  ```
  - Keys: commit-type keywords, must match `^[a-z]+$` (lowercase letters only).
  - Values: one of `"major"`, `"minor"`, `"patch"`, `"none"`.
  - `"breaking"` is disallowed as a key — the schema must reject it. Breaking-change detection (`BREAKING CHANGE:` footer / `!` suffix) is a structurally different, fixed mechanism, not a `type:` prefix, and always resolves to `major` regardless of config.
- **Merge semantics**: the effective rule set is the built-in defaults (`feat`→minor, `fix`→patch) merged with `.semver.json`'s `rules`, where config entries override a built-in of the same key and any other config keys add new type keywords. Keys not mentioned anywhere keep no mapping (i.e. behave as before — unmatched types contribute nothing to the bump decision).
- **`next-semver.sh` change**: generalize `bump_type_for_range`'s current sequential elif chain (breaking → feat → fix) into: for each commit, detect breaking-change (fixed, always yields `major` and short-circuits, as today) — otherwise look up the commit's leading `type:` keyword against the merged rules table and take the corresponding level (or nothing, if unmatched or explicitly `"none"`). Track the running best Bump Type by rank `major > minor > patch` across the whole range, exactly as today's precedence behavior, with `"none"` never contributing (equivalent to no match).
- **Config loading and validation**: performed once near the start of `main`, before commit-range scanning. If `.semver.json` exists:
  - Invalid JSON → exit non-zero with a clear error to stderr, no `.VERSION` mutation, consistent with the existing shallow-clone failure style (`next-semver.sh:64-67`).
  - A `rules` value outside the four-item enum, or a key not matching `^[a-z]+$`, or a `"breaking"` key present → same failure treatment.
  - A `"$schema"` key, if present, is ignored for behavior purposes (it's for editor tooling only) but must not cause a validation failure.
- **No new inputs anywhere**: `action.yml` requires no changes — it already calls `next-semver.sh` unchanged and reads `.VERSION`; config discovery happens inside the script itself via the fixed `.semver.json` repo-root path. No Action input, env var, or CLI flag is added for an alternate config path.
- **Domain vocabulary**: add a `Bump Type Rule` (or similarly-named) term to `CONTEXT.md` if the implementer judges the existing `Bump Type` definition insufficient to describe the type-keyword-to-level association now that it's config-driven — otherwise extend the existing `Bump Type` entry in place.
- **New ADR**: record the decision that this pass scopes custom rules strictly to commit-type → Bump Type mapping (explicitly excluding Release Tag pattern customization and initial-version override, both considered and deferred during design).
- **README updates**: replace the "Bump Type rules are fixed... no custom rules via a config file yet" Limitations bullet with documentation of `.semver.json` (shape, merge behavior, `"none"` level, optional `"$schema"`), and add a note that type-and-scope combinations (e.g. `feat(api):`-specific rules) are a possible future extension, not supported now.

## Testing Decisions

- **What makes a good test here**: assert on `.VERSION` contents, exit code, and stderr only — never on internal implementation (e.g. don't assert the merged rules table's internal representation, or that a specific jq/grep/sed invocation ran).
- **Seam (reused, no new seam)**: the existing black-box CLI seam in `test/next-semver.bats` — a fresh fixture git repo per test in a temp directory (`git init`, crafted commits/tags), now also with a `.semver.json` file written into that same fixture directory before invoking `next-semver.sh`. Prior art: every existing test in `test/next-semver.bats` already follows this fixture-per-test pattern (`setup`/`teardown` with `mktemp -d`).
- **Coverage** should include, at minimum, one fixture/test per:
  - No `.semver.json` present → behavior identical to today (regression coverage, not new coverage, but worth an explicit assertion that presence/absence toggles nothing else).
  - A new custom type keyword (e.g. `"perf": "patch"`) → a `perf:` commit produces the mapped bump.
  - An override of a built-in (e.g. `"feat": "major"`) → a `feat:` commit produces `major`, not the default `minor`.
  - A type mapped to `"none"` (e.g. `"docs": "none"`) → a `docs:`-only commit range produces no bump (unchanged version).
  - A mixed range where a custom-mapped type and a built-in-mapped type are both present → highest-precedence bump wins, unchanged precedence behavior.
  - `.semver.json` present but invalid JSON → non-zero exit, clear stderr, no `.VERSION` mutation.
  - `.semver.json` with an invalid rules value (e.g. `"feat": "huge"`) → non-zero exit, clear stderr.
  - `.semver.json` with an invalid key (e.g. uppercase, or `"breaking"`) → non-zero exit, clear stderr.
  - A `BREAKING CHANGE:` footer commit still produces `major` even when `.semver.json` is present and defines unrelated custom rules, confirming breaking-change detection stays independent of config.
  - `"$schema"` key present in an otherwise-valid `.semver.json` → no effect on behavior, still succeeds.

## Out of Scope

- Release Tag pattern customization (e.g. monorepo tag prefixes) via config.
- Initial-version override (currently hardcoded `0.1.0`) via config.
- Type-and-scope combination rules (e.g. rules scoped to `feat(api):` specifically) — noted in the README as a possible future extension.
- Making breaking-change detection itself configurable (custom footer keywords, disabling `!` detection, etc.) — it remains fixed.
- A CLI flag or Action input for an alternate config file path/location.
- Any CLI flags unrelated to this feature (`--help`, `--dry-run`, etc.).
- Support for arbitrary regex-based custom rules (only literal lowercase type keywords are supported).

## Further Notes

This spec was produced from a `/grilling` design session (see the conversation's settled decisions). It builds on `.scratch/get-semver-script/spec.md`'s original Out-of-Scope item "Custom Bump Type rules via a config file," which this spec now brings into scope. The deferred items above (tag-pattern customization, initial-version override, type+scope combinations) are intended as future follow-ups, not rejections, consistent with how this repo's existing ADRs and README Limitations section frame deferred scope.
