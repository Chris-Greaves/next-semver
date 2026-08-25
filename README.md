# get-semver

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
./get-semver.sh
cat .VERSION
```

It works identically whether run locally or from any CI system — it makes no network calls and requires no configuration.

## Usage as a GitHub Action

```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0 # required: get-semver needs full history, not a shallow clone

- uses: <owner>/get-semver@v1
  id: get-semver

- run: echo "Next version is ${{ steps.get-semver.outputs.version }}"
```

The Action takes no inputs, calls `get-semver.sh` unchanged (so `.VERSION` is still written to disk exactly as when run directly), and exposes the computed version as the `version` step output. Because it makes no network calls itself and does no auto-fetching, a shallow checkout fails the step clearly — always set `fetch-depth: 0` on `actions/checkout`.

## Limitations

This first version of `get-semver.sh` intentionally keeps its scope narrow. These are deferred follow-ups, not permanent constraints:

- Only strict `MAJOR.MINOR.PATCH` Release Tags are recognized, with an optional leading lowercase `v` — pre-release (`-rc.1`) and build-metadata (`+build.5`) suffixes aren't yet.
- Bump Type rules are fixed (`fix:` → patch, `feat:` → minor, `BREAKING CHANGE:`/`!` → major) — no custom rules via a config file yet.
