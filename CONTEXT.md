# next-semver

A standalone bash script that inspects a git repository's commit history and tags to determine the next Semantic Version, writing the result to a `.VERSION` file.

## Language

**Release Tag**:
A git tag whose name is a Semantic Version (`MAJOR.MINOR.PATCH`, per semver.org), with an optional leading lowercase `v` — no pre-release or build-metadata suffix either way. Both `1.2.0` and `v1.2.0` are recognized as Release Tags; the `v` prefix affects only recognition, never the computed output (see `.VERSION` file). The most recent Release Tag reachable from the current commit is the baseline for the next version.
_Avoid_: version tag, semver tag

**Bump Type**:
One of `major`, `minor`, or `patch` — the size of version increment implied by a commit's message. Derived from Conventional Commits-style prefixes: `fix:` → patch, `feat:` → minor, a `BREAKING CHANGE:` footer or `!` after the type/scope → major. Any other message contributes no Bump Type. When a commit range contains multiple Bump Types, the highest-precedence one (major > minor > patch) determines the release.
_Avoid_: version bump, increment level

**`.VERSION` file**:
The script's sole output artifact: a single-line file at the repo root containing just the next version string, always bare (no `v` prefix) regardless of whether the matched Release Tag was bare or `v`-prefixed. The interface other tooling reads to consume the computed version ("baking the version into the build").
_Avoid_: version file, output file
