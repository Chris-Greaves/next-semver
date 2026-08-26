# next-semver

A standalone bash script that inspects a git repository's commit history and tags to determine the next Semantic Version, writing the result to a `.VERSION` file.

## What Does This Script Do?

- Gets the hash of the last semver tag used
- Gets all the commits after that last version
- If there is no prior semver tag, then start the versioning at 0.1.0
- Using commit message conventions like [conventional commits](https://www.conventionalcommits.org/en/v1.0.0/) and [Angular Commit Message Format](https://github.com/angular/angular/blob/22b96b9/CONTRIBUTING.md#-commit-message-guidelines) to work out what the next version should be.
- Create a file called `.VERSION` containing the computed version string, useful when baking the version into the build.

## How to Use It

Run the script from the root of your git repository:

```sh
./next-semver.sh
cat .VERSION
```

It works identically whether run locally or from any CI system — it makes no network calls and requires no configuration.

## Usage as a GitHub Action

```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0 # required: next-semver needs full history, not a shallow clone

- uses: <owner>/next-semver@v1
  id: next-semver

- run: echo "Next version is ${{ steps.next-semver.outputs.version }}"
```

The Action takes no inputs, calls `next-semver.sh` unchanged (so `.VERSION` is still written to disk exactly as when run directly), and exposes the computed version as the `version` step output. Because it makes no network calls itself and does no auto-fetching, a shallow checkout fails the step clearly — always set `fetch-depth: 0` on `actions/checkout`.

## Custom Bump Type Rules

By default, `fix:` → patch, `feat:` → minor, and a `BREAKING CHANGE:` footer or `!` after the type/scope → major. You can customize the `type:` → Bump Type mapping with an optional `.semver.json` file at the repo root:

```json
{
  "$schema": "https://raw.githubusercontent.com/<owner>/next-semver/main/semver.schema.json",
  "rules": {
    "feat": "minor",
    "fix": "patch",
    "perf": "patch",
    "docs": "none"
  }
}
```

- The file is optional — if it's absent, behavior is identical to the built-in rules above.
- `rules` maps a commit-type keyword to a Bump Type: `"major"`, `"minor"`, `"patch"`, or `"none"`. A key matching a built-in (`feat`, `fix`) overrides its default; any other key adds a new rule. `"none"` means that commit type contributes no bump, same as an unrecognized type.
- Matching is case-sensitive, lowercase-only keys (`^[a-z]+$`), same as the built-in `feat:`/`fix:` checks. `breaking` is a reserved key and is rejected.
- The optional `"$schema"` key (shown above) is never inspected by the script — it's purely for editor autocomplete/validation. Point it at a raw URL (as above) since [`semver.schema.json`](./semver.schema.json) lives in this repo, not in a consumer repo that only uses the Action — a relative path only resolves if you're running `next-semver.sh` from within a checkout of this repo itself.
- `BREAKING CHANGE:` footer / `!` suffix detection always yields `major` and can't be reconfigured.
- `jq` is now a required dependency for this feature (preinstalled on `ubuntu-latest` and `macos-latest` GitHub-hosted runners).
- Malformed config (invalid JSON, an invalid `rules` key, or an invalid `rules` value) fails the script loudly, with no `.VERSION` written.

Rules scoped to a type-and-scope combination (e.g. a rule specific to `feat(api):`) are a possible future extension, not currently supported.

## Limitations

This first version of `next-semver.sh` intentionally keeps its scope narrow. This is a deferred follow-up, not a permanent constraint:

- Only strict `MAJOR.MINOR.PATCH` Release Tags are recognized, with an optional leading lowercase `v` — pre-release (`-rc.1`) and build-metadata (`+build.5`) suffixes aren't yet.
