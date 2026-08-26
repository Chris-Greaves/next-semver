# 02 — Support custom Bump Type rules via `.semver.json`

**What to build:** An optional `.semver.json` file at the repo root that lets a developer customize which commit types produce which Bump Type. `next-semver.sh` uses `jq` to load and validate it, merges its `rules` object into the built-in table from ticket 01 (config entries override a built-in of the same key; new keys are added), and the computed Bump Type reflects the merged rules. The file's absence is not an error — behavior is identical to today. Malformed config fails the script loudly.

**Blocked by:** 01 — Extract built-in Bump Type rules into a data-driven table

**Status:** ready-for-agent

- [ ] With no `.semver.json` present, behavior is unchanged from today (regression-covered explicitly, not just implied).
- [ ] `jq` is used to parse and read `.semver.json`; only the `rules` key is consulted — any other top-level keys (including `"$schema"`) are never inspected or validated, so their presence never causes a failure.
- [ ] A `rules` entry for a new commit-type keyword (e.g. `"perf": "patch"`) causes a matching commit (`perf:`) to produce that Bump Type.
- [ ] A `rules` entry that redefines a built-in keyword (e.g. `"feat": "major"`) overrides the default for that keyword.
- [ ] Any built-in keyword not mentioned in `.semver.json` keeps its default mapping (`feat`→minor, `fix`→patch).
- [ ] A `rules` value of `"none"` means that commit type contributes no bump — a commit range containing only that type produces an unchanged version, identical to an unrecognized type.
- [ ] Rules matching is case-sensitive, lowercase-only, consistent with the existing hardcoded `feat:`/`fix:` checks.
- [ ] The highest-precedence Bump Type across the full commit range (major > minor > patch, with `"none"`/unmatched contributing nothing) still wins when custom and built-in rules are mixed in the same range.
- [ ] `BREAKING CHANGE:` footer / `!` suffix detection still always yields `major` and is unaffected by `.semver.json`, even when the config defines unrelated custom rules.
- [ ] A `rules` key is rejected (script exits non-zero with a clear stderr message, no `.VERSION` mutation) if it doesn't match `^[a-z]+$`, including the literal key `"breaking"`.
- [ ] A `rules` value is rejected (same failure treatment) if it isn't one of `"major"`, `"minor"`, `"patch"`, `"none"`.
- [ ] Invalid JSON in `.semver.json` is rejected (same failure treatment).
- [ ] New `test/next-semver.bats` cases cover: no config (regression), new custom keyword, override of a built-in, `"none"` level, mixed-precedence with custom + built-in types, invalid JSON, invalid rules value, invalid rules key (including `"breaking"`), breaking-change detection staying independent of config, and a valid config with an unrelated `"$schema"` key present having no effect on behavior.
- [ ] The full bats suite continues to pass in CI on both `ubuntu-latest` and `macos-latest` (both images ship `jq` preinstalled — no CI workflow changes expected, but confirm).
