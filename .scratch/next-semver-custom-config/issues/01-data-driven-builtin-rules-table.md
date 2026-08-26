# 01 — Extract built-in Bump Type rules into a data-driven table

**What to build:** Refactor `next-semver.sh`'s Bump Type derivation so the built-in `feat`→minor / `fix`→patch mappings come from a lookup table rather than a hardcoded sequential `elif` chain, with no change in observable behavior. This is a pure prefactor that creates the seam ticket 02 will merge custom config rules into — breaking-change detection (`BREAKING CHANGE:` footer / `!` suffix) stays a separate, untouched code path since it isn't a `type:` prefix lookup.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] `bump_type_for_range`'s `feat:`/`fix:` detection is driven by a table/lookup of type-keyword → Bump Type level, not separate hardcoded `elif` branches per type.
- [ ] Breaking-change detection (`BREAKING CHANGE:` footer, `!` suffix) is unchanged and remains independent of the new lookup table.
- [ ] The running "highest Bump Type wins" precedence behavior across a commit range (major > minor > patch) is unchanged.
- [ ] The existing `test/next-semver.bats` suite passes unmodified — no behavior change, no new tests required for this ticket.
