# 03 — Ship `semver.schema.json`

**What to build:** A JSON Schema document, `semver.schema.json`, at the repo root (flat, sibling to `.semver.json`/`next-semver.sh` — no `schema/` subdirectory) describing the shape of `.semver.json`, so a developer can reference it via an optional `"$schema"` key for editor autocomplete/validation.

**Blocked by:** None — can start immediately (the config shape is already fully specified in the spec); may land before, after, or in parallel with ticket 02.

**Status:** ready-for-agent

- [ ] `semver.schema.json` exists at the repo root and is valid JSON / a valid JSON Schema document.
- [ ] It describes a top-level object with an optional `"$schema"` string property and a `rules` object property.
- [ ] `rules` property names are constrained to the pattern `^[a-z]+$`.
- [ ] `rules` property values are constrained to the enum `["major", "minor", "patch", "none"]`.
- [ ] The schema does not need to specifically special-case forbidding `"breaking"` as a `rules` key beyond the `^[a-z]+$` pattern already allowing it lexically — reject it only if that's expressible without materially complicating the schema; otherwise document in ticket 04 that this remains a script-level (not schema-level) validation rule.
- [ ] A `.semver.json` matching the shape agreed in the spec (e.g. `{"rules": {"feat": "minor", "fix": "patch", "perf": "patch", "docs": "none"}}`) validates successfully against this schema when spot-checked (manually, or via any JSON Schema validator available locally — no new automated test dependency is required for this ticket).
