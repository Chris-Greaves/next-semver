# 01 — Widen Release Tag recognition to accept optional `v` prefix

**What to build:** `get-semver.sh` recognizes a Release Tag whether it's bare (`1.2.0`) or `v`-prefixed (`v1.2.0`) — the bump arithmetic runs the same either way, and the `.VERSION` output is always bare regardless of which style matched. A repo with no tags at all still starts at `0.1.0`, unchanged. A repo with both a bare and a `v`-prefixed Release Tag on different commits still picks whichever is most recent by history, not by prefix style. Strict `MAJOR.MINOR.PATCH` digit rules (e.g. no leading zeros) apply identically with or without the `v`. Uppercase or non-standard prefixes (`V1.2.0`, `ver1.2.0`) are still not recognized. Pre-release/build-metadata suffixes remain unrecognized either way.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] `SEMVER_RE` accepts an optional leading lowercase `v`
- [ ] The matched `v` prefix (if any) is stripped before the version is passed into `bump_version`, so both the arithmetic and the value written to `.VERSION` are always bare
- [ ] `find_last_release_tag`'s traversal order is unchanged — nearest tag to HEAD wins regardless of prefix style
- [ ] `bump_type_for_range`'s logic is unchanged
- [ ] New bats test: a `v`-prefixed tag is recognized as a Release Tag, bump applies, output stays bare
- [ ] New bats test: a repo with both a bare and a `v`-prefixed Release Tag on different commits picks the most-recent-by-history one regardless of style
- [ ] New bats test: a `v`-prefixed tag with a leading-zero segment (e.g. `v1.0.08`) is still rejected
- [ ] New bats test: a non-standard prefix (e.g. `V1.0.0`) is still not recognized as a Release Tag
- [ ] README's Limitations section no longer lists "no `v` prefix" as a restriction
