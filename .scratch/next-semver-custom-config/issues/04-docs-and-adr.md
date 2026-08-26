# 04 — Documentation and ADR for custom Bump Type rules

**What to build:** Update the project's documentation and domain records to reflect that custom Bump Type rules are now supported, and record the scope decision behind this feature.

**Blocked by:** 02 — Support custom Bump Type rules via `.semver.json`; 03 — Ship `semver.schema.json`

**Status:** ready-for-agent

- [ ] README's Limitations bullet "Bump Type rules are fixed... no custom rules via a config file yet" is replaced with documentation of `.semver.json`: its shape, that it's optional, the override/add merge behavior, the `"none"` level, the optional `"$schema"` key, and that `jq` is now a required dependency for this feature.
- [ ] README notes that type-and-scope combination rules (e.g. rules scoped to `feat(api):` specifically) are a possible future extension, not currently supported.
- [ ] `CONTEXT.md`'s domain vocabulary is updated if the existing `Bump Type` definition doesn't adequately describe the now-config-driven type-keyword-to-level association (extend in place, or add a new term — implementer's judgment).
- [ ] A new ADR is added recording the decision to scope custom rules strictly to commit-type → Bump Type mapping for this pass, explicitly excluding Release Tag pattern customization and initial-version override (both considered and deferred during design).
