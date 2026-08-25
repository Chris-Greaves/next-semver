# 03 — Package get-semver as a composite GitHub Action

**What to build:** A workflow author can pull `get-semver` into their workflow with a single `uses:` step instead of checking out and invoking the script manually, and read the computed version as a step output instead of opening `.VERSION` off disk. The Action takes no inputs, runs as a composite (bash) action calling the existing script unchanged — same behavior, `.VERSION` is still written to disk exactly as before, no container image to build or pull, no network calls. A shallow checkout still fails clearly (the script's existing shallow-clone check surfaces through the Action wrapper unchanged). The README documents the `uses:` step, the `version` output, and the `fetch-depth: 0` requirement on the consumer's `actions/checkout` step.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] New `action.yml` at the repo root: `runs.using: composite`, zero inputs, one output (`version`)
- [ ] The single step invokes `${{ github.action_path }}/get-semver.sh` with `shell: bash`, then reads `.VERSION`'s contents to populate the `version` output
- [ ] No auto-fetch/unshallow logic is added — shallow-clone detection and failure stays exactly what `get-semver.sh` already does, surfaced as-is through the Action
- [ ] No inputs added, no outputs beyond `version` (no `bump-type`, no `previous-version`)
- [ ] README: remove the "`action.yml` wrapper is planned but not part of this first version" caveat
- [ ] README: add a "Usage as a GitHub Action" section with an example `uses:` step, including the `fetch-depth: 0` requirement on `actions/checkout`, and the `version` output
