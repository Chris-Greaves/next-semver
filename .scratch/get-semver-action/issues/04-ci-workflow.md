# 04 — CI: verify the script and the Action in GitHub Actions

**What to build:** Regressions in `get-semver.sh` or `action.yml` are caught automatically on every push/PR instead of relying on manual `npm test` runs. This is the only seam that can exercise `action.yml` itself (bats can't observe the Actions runtime), so it also proves the Action's wiring — inputs/outputs, `shell:`, `github.action_path` resolution — and proves the documented shallow-clone failure contract holds through the real Action wrapper, not just the bare script.

**Blocked by:** 01 (Widen Release Tag recognition to accept optional `v` prefix), 03 (Package get-semver as a composite GitHub Action)

**Status:** ready-for-agent

- [ ] New GitHub Actions workflow under `.github/workflows/`
- [ ] Job: run the bats suite on `ubuntu-latest`
- [ ] Job: run the bats suite on `macos-latest` (verifies the documented bash 3.2 compatibility, unverified by any CI today)
- [ ] Job: invoke the composite action via `uses: ./` against a fixture-tagged checkout and assert the `version` step output matches the expected computed version
- [ ] Job: invoke the composite action against a deliberately shallow checkout (default `actions/checkout`, no `fetch-depth: 0`) and assert the step fails
- [ ] All jobs pass on the current `main` branch state once 01 and 03 are merged
