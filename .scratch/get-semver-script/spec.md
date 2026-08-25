# get-semver.sh — compute the next Semantic Version from git history

Status: ready-for-agent

## Problem Statement

Anyone working in a repo that wants to release Semantically Versioned artifacts currently has to work out the next version number by hand: find the last release, read through the commits since then, and decide whether the change is a major, minor, or patch bump. That's error-prone and inconsistent between people, and there's no simple, tool-agnostic way to get that answer into a build script.

## Solution

A standalone bash script, `get-semver.sh`, that inspects the current git repository, finds the last Release Tag, scans the commits since then for Conventional Commits-style messages, computes the resulting Bump Type, and writes the next version to a `.VERSION` file at the repo root. Any build tooling — CI or local — can then read `.VERSION` to bake the version into its output.

## User Stories

1. As a developer, I want to run a single script in my repo, so that I get the next semantic version without doing the git archaeology myself.
2. As a developer, I want the script to find the most recent Release Tag automatically, so that I don't have to tell it where the last release was.
3. As a developer, I want the script to work the first time I ever run it, when no Release Tag exists yet, so that I can adopt it on a brand-new repo.
4. As a developer, I want a repo with no prior Release Tag to unconditionally start at `0.1.0`, so that the first release has a predictable, documented version regardless of what the initial commits contain.
5. As a developer, I want the script to only recognize bare `MAJOR.MINOR.PATCH` tags (no `v` prefix) as Release Tags, so that tag matching stays simple and unambiguous.
6. As a developer, I want commits tagged with a `v`-prefixed or pre-release/build-metadata tag to be ignored as Release Tags in this version of the script, so that the matching logic doesn't have to implement semver precedence rules.
7. As a developer, I want a `fix:` commit since the last Release Tag to produce a patch bump, so that bug fixes are versioned correctly.
8. As a developer, I want a `feat:` commit since the last Release Tag to produce a minor bump, so that new features are versioned correctly.
9. As a developer, I want a commit with a `BREAKING CHANGE:` footer or a `!` after the type/scope (e.g. `feat!:`) to produce a major bump, so that breaking changes are versioned correctly.
10. As a developer, I want the highest-precedence Bump Type across all commits in range to win when multiple qualifying commits exist, so that a single breaking change in a batch of fixes still produces a major bump.
11. As a developer, I want commits that don't match any recognized type prefix to be silently ignored for bump purposes, so that unrelated commit message hygiene doesn't break the script.
12. As a developer, I want merge commits excluded from the scanned range, so that they don't introduce noise into bump determination.
13. As a developer, I want the script to scan commits reachable from whatever is currently checked out (`<last-release-tag>..HEAD`), so that it behaves consistently whether I run it locally or in CI, on any branch.
14. As a developer, I want the result written to a `.VERSION` file containing only the version string on a single line, so that any tool can consume it with something as simple as `$(cat .VERSION)`.
15. As a developer, I want `.VERSION` to be written even when there are no new commits since the last Release Tag (containing the unchanged current version), so that the file's presence and format are always reliable for downstream consumers and builds stay reproducible.
16. As a developer, I want the script to work identically whether it's invoked locally or from any CI system, so that I'm not locked into GitHub Actions to use it.
17. As a developer using an older macOS machine, I want the script to run under bash 3.2, so that I don't need to install a newer bash just to use it.
18. As a developer, I want the script to detect when my git checkout is shallow and fail with a clear error rather than silently computing a wrong answer, so that I know to fetch full history instead of getting a misleading version.
19. As a developer, I want the script to make no network calls (no auto-fetching), so that its behavior is predictable and side-effect-free wherever it runs.
20. As a maintainer reading the README, I want to see documented limitations for the strict tag format and fixed bump rules, so that I understand what this first version does and doesn't support, and know it's not a bug.

## Implementation Decisions

- **New file**: `get-semver.sh` at the repo root. Zero-argument CLI — no flags in this pass (`--help`, `--dry-run`, etc. are out of scope).
- **Bash target**: bash 3.2-compatible (no associative arrays, no `mapfile`, no `${var,,}`), for portability to macOS's default `/bin/bash` as well as Linux CI runners. Coreutils (`grep`, `sed`, `awk`, `cut`) may be used freely.
- **Release Tag lookup**: find the most recent git tag reachable from `HEAD` matching bare `MAJOR.MINOR.PATCH` (semver.org, numeric only — no `v` prefix, no pre-release/build-metadata suffix). Tags in any other format are not considered Release Tags.
- **No prior Release Tag**: next version is unconditionally `0.1.0`.
- **Commit range**: `git log --no-merges <last-release-tag>..HEAD` (or all non-merge history when there's no prior Release Tag).
- **Bump Type derivation**: for each commit in range, inspect the full commit message (subject + body) for Conventional Commits markers: `fix:` → patch, `feat:` → minor, `BREAKING CHANGE:` footer or `!` after type/scope → major. Non-matching messages contribute nothing. The resulting version applies the highest-precedence Bump Type found (major > minor > patch) to the last Release Tag.
- **Output contract**: `.VERSION` at the repo root, single line, containing only the computed version string — nothing else. Written unconditionally, including when the commit range is empty (in which case it's the unchanged current version).
- **Shallow-clone handling**: check `git rev-parse --is-shallow-repository` before relying on tag/commit history; if shallow, exit non-zero with a clear error message. No `git fetch` is performed by the script.
- **Domain vocabulary**: see `CONTEXT.md` for the definitions of Release Tag, Bump Type, and `.VERSION` file used throughout this spec. See `docs/adr/0001-strict-semver-tags-no-v-prefix.md` and `docs/adr/0002-version-file-is-plain-version-string.md` for the reasoning behind the two most consequential decisions above.
- **README updates**: change the fallback example from `v0.1.0` to `0.1.0`, and add a Limitations section documenting (a) only strict `MAJOR.MINOR.PATCH` Release Tags are recognized — no `v` prefix, pre-release, or build metadata yet, and (b) Bump Type rules are fixed for this version — no custom rules via a config file yet.

## Testing Decisions

- **Seam**: black-box only, at the CLI boundary. Tests invoke `get-semver.sh` as a subprocess against a fixture git repository (created fresh per test in a temp directory: `git init`, crafted commits and tags) and assert on the resulting `.VERSION` contents, exit code, and stderr. No internal shell functions are unit-tested separately — this is the one and only seam.
- **Test runner**: bats-core. Add it as the project's test dependency (no prior art in this repo — this is the first test tooling added).
- **Coverage** should include, at minimum, one fixture/test per: no prior Release Tag (→ `0.1.0`), `fix:`-only range (→ patch bump), `feat:`-only range (→ minor bump), a `BREAKING CHANGE:` footer or `!` commit (→ major bump), a mixed range where the highest-precedence bump wins, a range with only non-conforming commits (→ no bump, unchanged version), an empty range since the last Release Tag (→ `.VERSION` written with unchanged current version), a merge commit present in range (→ excluded, doesn't affect outcome), a `v`-prefixed or pre-release-tagged repo (→ tag not recognized, falls through to next matching or no-prior-tag behavior), and a shallow clone (→ non-zero exit, clear stderr message, no `.VERSION` mutation).
- **What makes a good test here**: assert on `.VERSION`'s file contents and the script's exit code/stderr — never on internal implementation (e.g. don't assert specific git plumbing commands were run). Each test's fixture repo should be minimal — only the commits/tags needed to exercise that one behavior.

## Out of Scope

- `action.yml` / GitHub Action wrapper (script only, for now).
- `v`-prefixed tag support.
- Pre-release (`-rc.1`) and build-metadata (`+build.5`) tag recognition, and semver precedence rules.
- Custom Bump Type rules via a config file.
- Any CLI flags (`--help`, `--dry-run`, output format options, etc.).
- Auto-fetching or otherwise deepening a shallow git checkout.
- Structured/richer `.VERSION` output (previous version, Bump Type, considered commits) — single version string only.

## Further Notes

This spec was produced from a `/grilling` design session (see `CONTEXT.md` and the two ADRs in `docs/adr/` for the domain vocabulary and the two most consequential decisions). The deferred items in Out of Scope (`v` prefix, pre-release tags, config-driven rules) are explicitly intended as future follow-ups, not rejections — the README's Limitations section should reflect that framing rather than reading as permanent constraints.
