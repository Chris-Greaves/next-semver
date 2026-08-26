# next-semver

A standalone bash script that inspects a git repository's commit history and tags to determine the next Semantic Version, writing the result to a `.VERSION` file.

## Language

**Release Tag**:
A git tag whose name is a Semantic Version (`MAJOR.MINOR.PATCH`, per semver.org), with an optional leading lowercase `v` — no pre-release or build-metadata suffix either way. Both `1.2.0` and `v1.2.0` are recognized as Release Tags; the `v` prefix affects only recognition, never the computed output (see `.VERSION` file). The most recent Release Tag reachable from the current commit is the baseline for the next version.
_Avoid_: version tag, semver tag

**Bump Type**:
One of `major`, `minor`, or `patch` — the size of version increment implied by a commit's message. A `BREAKING CHANGE:` footer or `!` after the type/scope always → major, and is never configurable. Otherwise, a commit's `type:` prefix (e.g. `feat`, `fix`) is looked up in the Bump Type Rules table to find its Bump Type; an unmatched type, or a rule of `none`, contributes no Bump Type. Any other message (no `type:` prefix at all) also contributes no Bump Type. When a commit range contains multiple Bump Types, the highest-precedence one (major > minor > patch) determines the release.
_Avoid_: version bump, increment level

**Bump Type Rules**:
The table mapping a commit-type keyword to the Bump Type it produces (e.g. `feat` → `minor`, `fix` → `patch`). Built in by default; a repo can extend or override it with an optional `.semver.json` file at the repo root (see README). Keys are lowercase-only (`^[a-z]+$`) and matched case-sensitively; `breaking` is reserved and can't be used as a key, since breaking-change detection is a separate, unconfigurable code path.
_Avoid_: rules table, config rules

**`.VERSION` file**:
The script's sole output artifact: a single-line file at the repo root containing just the next version string, always bare (no `v` prefix) regardless of whether the matched Release Tag was bare or `v`-prefixed. The interface other tooling reads to consume the computed version ("baking the version into the build").
_Avoid_: version file, output file
