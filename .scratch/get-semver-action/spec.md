# get-semver as a GitHub Action, with `v`-prefixed Release Tag support

Status: ready-for-agent

## Problem Statement

`get-semver.sh` today can only be consumed by manually checking it out and invoking it as a shell step — there's no versioned, reusable way to pull it into a GitHub Actions workflow, and no clean way to read the computed version other than opening `.VERSION` off disk. Separately, the script's strict bare-semver-only Release Tag matching (ADR 0001) means this repo can't tag its own releases the way GitHub Actions consumers expect (`v`-prefixed tags, e.g. `v1.2.0`, plus a floating `v1`) without running two parallel, disconnected tagging schemes — one for the script's own versioning and one for Action consumption.

## Solution

Package `get-semver.sh` as a composite GitHub Action (`action.yml` at the repo root) that any workflow can pull in with a single `uses:` step, exposing the computed version as a `version` step output. Widen the script's Release Tag recognition to accept an optional leading `v` (while keeping the computed `.VERSION` output always bare), so this repo can tag its own releases using the same convention Action consumers reference, and dogfood its own script for its own versioning. Add a LICENSE file and CI (the existing bats suite running in GitHub Actions across bash 3.2 and bash 5, plus a new Actions-level integration workflow) so the Action is stable and consumable.

## User Stories

1. As a workflow author, I want to reference get-semver as a GitHub Action via `uses:`, so that I don't have to check out or invoke the script manually.
2. As a workflow author, I want the Action to expose the computed version as a step output, so that I can use it in subsequent steps without reading `.VERSION` off disk.
3. As a workflow author, I want the Action to require no inputs, so that adopting it is a one-line `uses:` step.
4. As a workflow author, I want the Action to run as a composite (bash) action calling the existing script, so that its behavior is identical to running the script directly and no container image needs building or pulling.
5. As a workflow author, I want the Action to make no network calls itself, so that its behavior stays predictable and consistent with the underlying script's existing "no network calls" design.
6. As a workflow author, I want the Action to fail clearly, not silently succeed with a wrong version, when my checkout is shallow, so that I find out immediately rather than shipping a bad version.
7. As a workflow author, I want the README/Action description to clearly document that `fetch-depth: 0` is required on `actions/checkout`, so that I configure my workflow correctly the first time.
8. As a maintainer, I want Release Tag recognition to also accept a leading `v` (e.g. `v1.2.0`), so that this repo — and any consumer — can use the conventional GitHub Actions tagging style for releases.
9. As a maintainer, I want the computed `.VERSION` output to always be bare (no `v` prefix), regardless of whether the matched tag was `v`-prefixed or not, so that downstream build tooling never has to strip a prefix and the output contract stays exactly as documented in ADR 0002.
10. As a maintainer, I want pre-release (`-rc.1`) and build-metadata (`+build.5`) tag suffixes to remain unrecognized, so that this change stays a small, contained widening rather than reopening the larger semver-precedence question.
11. As a maintainer, I want maintaining a floating major-version tag (e.g. `v1`) to stay an explicitly separate, manual/future concern, so that `get-semver.sh` itself stays scoped to computing a version, not managing tags.
12. As a maintainer, I want a LICENSE file matching `package.json`'s already-declared ISC license, so that the repo is legally usable, forkable, and consumable as an Action.
13. As a maintainer, I do not want a GitHub Marketplace listing yet, so that branding metadata (icon/color) and marketplace-specific polish aren't required for this pass.
14. As a maintainer, I want the existing bats suite to run in CI on every push/PR, so that regressions are caught automatically instead of relying on manual `npm test` runs.
15. As a maintainer, I want the bats suite to run on both `ubuntu-latest` and `macos-latest` in CI, so that the script's documented bash 3.2 compatibility (macOS's default `/bin/bash`) is actually verified, not just assumed.
16. As a maintainer, I want an integration test that invokes the composite Action itself (`uses: ./`) and asserts on its `version` output, so that `action.yml`'s wiring (inputs/outputs, `shell:`, `github.action_path` resolution) is verified — something the script-level bats suite cannot see.
17. As a maintainer, I want an integration test that deliberately performs a shallow checkout and asserts the Action fails, so that the documented shallow-clone failure contract is proven to hold through the real Action wrapper, not just through the bare script.
18. As a developer with no prior Release Tag, I want a repo with no tags at all to still start at `0.1.0`, unchanged from existing behavior.
19. As a developer, I want a repo with both a bare and a `v`-prefixed Release Tag on different commits to have the most-recent-by-history tag win regardless of prefix style, so that widened recognition never overrides existing recency-based tag selection.
20. As a developer, I want a tag like `v1.0.08` (leading zero after the `v`) to still be rejected as invalid, so that the existing strict `MAJOR.MINOR.PATCH` digit rules apply identically whether or not a `v` prefix is present.
21. As a developer, I want an uppercase or non-standard prefix (`V1.2.0`, `ver1.2.0`) to NOT be recognized as a Release Tag, so that recognition stays limited to exactly the documented lowercase `v` convention.
22. As a workflow author migrating from direct script invocation, I want the Action's behavior to be identical to running `./get-semver.sh` directly (the same `.VERSION` file is still written), so that existing consumers who read `.VERSION` off disk aren't broken by adopting the Action wrapper.

## Implementation Decisions

- **New file**: `action.yml` at the repo root. Composite action (`runs.using: composite`), zero inputs, one output: `version`. The single step invokes `${{ github.action_path }}/get-semver.sh` with `shell: bash`, then reads `.VERSION`'s contents to populate the `version` output.
- **`get-semver.sh` change**: widen `SEMVER_RE` to accept an optional leading lowercase `v` (`^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$`), and strip a matched `v` prefix before the version is passed into `bump_version`, so both the arithmetic and the final value written to `.VERSION` are always bare. No change to `bump_type_for_range`'s logic. `find_last_release_tag`'s traversal order is unchanged — nearest tag to HEAD still wins, regardless of prefix style.
- No inputs are added to the Action or the script — the zero-argument CLI is unchanged.
- No outputs beyond `version` are added (no `bump-type`, no `previous-version`).
- No auto-fetch/unshallow logic is added anywhere (neither the script nor `action.yml`) — shallow-clone detection and failure behavior in `get-semver.sh` is unchanged, and is exactly what the Action surfaces to consumers.
- No automation is added for creating or moving a floating major-version tag (e.g. `v1`) — left as a manual/future step.
- **New file**: `LICENSE` at the repo root, ISC license text, matching `package.json`'s existing `"license": "ISC"` declaration.
- **README updates**: remove the "`action.yml` wrapper is planned but not part of this first version" caveat; add a "Usage as a GitHub Action" section with an example `uses:` step (including the `fetch-depth: 0` requirement on the consumer's `actions/checkout` step) and the `version` output; update the Limitations section to remove the `v`-prefix bullet (now supported) while keeping the pre-release/build-metadata and fixed-bump-rules bullets.
- **Domain docs**: `CONTEXT.md`'s Release Tag and `.VERSION` file definitions already reflect optional `v`-prefix recognition and always-bare output. ADR 0001 is marked superseded by new ADR 0003, which records the `v`-prefix decision and its rationale — see both for the reasoning behind this change.

## Testing Decisions

- **What makes a good test here**: assert on observable outputs only — `.VERSION` contents / exit code / stderr for the script seam, step outputs / job success-or-failure for the Action seam — never on internal implementation (specific git plumbing commands, `action.yml`'s internal step structure).
- **Seam 1 (existing, reused)** — the black-box CLI seam already in `test/get-semver.bats`: invoke `get-semver.sh` as a subprocess against a fixture git repo (fresh temp dir per test, minimal commits/tags), assert on `.VERSION` contents/exit code/stderr. Add cases for: a `v`-prefixed tag recognized as a Release Tag (bump applies, output stays bare), a repo with both a bare and a `v`-prefixed tag on different commits (most-recent-by-history wins regardless of style), a `v`-prefixed tag with a leading-zero segment still rejected, and a non-standard prefix (e.g. `V1.0.0`) still not recognized. Prior art: the existing test file's fixture-per-test pattern.
- **Seam 2 (new)** — a GitHub Actions workflow under `.github/workflows/`, the only seam able to exercise `action.yml` itself since bats can't observe the Actions runtime. Jobs:
  - run the bats suite on `ubuntu-latest`
  - run the bats suite on `macos-latest` (verifies the existing bash-3.2-compatibility promise, unverified by any CI today)
  - invoke the composite action via `uses: ./` against a fixture-tagged checkout and assert the `version` step output matches the expected computed version
  - invoke the composite action against a deliberately shallow checkout (default `actions/checkout`, no `fetch-depth: 0`) and assert the step fails
  There is no existing Actions-workflow-based test in this repo, so these jobs establish that pattern fresh.

## Out of Scope

- GitHub Marketplace listing, and the branding metadata (`icon`/`color`) it requires.
- Pre-release (`-rc.1`) and build-metadata (`+build.5`) tag recognition — remains deferred, unchanged from ADR 0001's original reasoning.
- Automating creation or movement of a floating major-version tag (e.g. `v1`) — a release-process concern, not something `get-semver.sh` or `action.yml` does.
- Any CLI flags or Action inputs (`--help`, `--dry-run`, working-directory overrides, etc.).
- Additional Action outputs beyond `version` (e.g. `bump-type`, `previous-version`).
- Auto-fetching or otherwise deepening a shallow checkout, from either the script or the Action wrapper.
- Docker container or JavaScript Action implementations — composite only.

## Further Notes

This spec was produced from a `/grilling` design session. See `CONTEXT.md`'s updated Release Tag and `.VERSION` file entries, and `docs/adr/0003-release-tags-accept-optional-v-prefix.md` (which supersedes `docs/adr/0001-strict-semver-tags-no-v-prefix.md`) for the domain vocabulary and reasoning behind the `v`-prefix decision.

This builds directly on the original `get-semver.sh` spec (`.scratch/get-semver-script/spec.md`), whose "`action.yml` / GitHub Action wrapper" and "`v`-prefixed tag support" Out-of-Scope items are exactly what this spec brings into scope. Its other deferred items — pre-release/build-metadata tags, custom bump rules via a config file, CLI flags — remain deferred here too.
