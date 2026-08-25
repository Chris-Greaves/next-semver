---
status: accepted, supersedes ADR-0001
---

# Release Tags accept an optional `v` prefix; computed output stays bare

ADR 0001 restricted Release Tags to bare `MAJOR.MINOR.PATCH`, explicitly rejecting the `v`-prefixed GitHub convention (`v1.2.0`) to keep tag-matching minimal. Wrapping this script as a GitHub Action changes the calculus: consumers reference an Action via a tagged ref (conventionally `v1.2.0`, plus a floating `v1`), and this repo wants to dogfood `next-semver.sh` on itself using that same tag rather than maintaining two parallel tag schemes. We decided Release Tag recognition now accepts an optional leading `v` (`1.2.0` and `v1.2.0` are equally valid), while the version written to `.VERSION` is always bare regardless of which form matched. This was chosen over preserving the matched tag's prefix in the output, because `.VERSION`'s existing contract (ADR 0002) is "just the version string" for direct consumption by build tooling (npm, Docker tags, etc.) that expects bare semver — normalizing the output means the `v` prefix is purely an input-recognition concern and `.VERSION` never changes shape based on which tagging style a repo happens to use. Pre-release (`-rc.1`) and build-metadata (`+build.5`) suffixes remain unrecognized, unchanged from ADR 0001 — only the `v` prefix is being pulled back into scope.
