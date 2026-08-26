#!/usr/bin/env bats

SCRIPT="$BATS_TEST_DIRNAME/../next-semver.sh"

setup() {
  TEST_DIR="$(mktemp -d)"
  cd "$TEST_DIR" || return 1
  git init -q
  git config user.email "test@example.com"
  git config user.name "Test"
  git config commit.gpgsign false
}

teardown() {
  cd "$BATS_TEST_DIRNAME" || true
  rm -rf "$TEST_DIR"
}

@test "no prior Release Tag yields 0.1.0" {
  git commit --allow-empty -q -m "chore: init"

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(cat .VERSION)" = "0.1.0" ]
}

@test "fix: commit since last Release Tag yields a patch bump" {
  git commit --allow-empty -q -m "chore: init"
  git tag 1.0.0
  git commit --allow-empty -q -m "fix: correct off-by-one"

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(cat .VERSION)" = "1.0.1" ]
}

@test "feat: commit since last Release Tag yields a minor bump" {
  git commit --allow-empty -q -m "chore: init"
  git tag 1.0.0
  git commit --allow-empty -q -m "feat: add search endpoint"

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(cat .VERSION)" = "1.1.0" ]
}

@test "BREAKING CHANGE footer yields a major bump" {
  git commit --allow-empty -q -m "chore: init"
  git tag 1.0.0
  git commit --allow-empty -q -m "fix: rework storage layer

BREAKING CHANGE: storage format is no longer backwards compatible"

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(cat .VERSION)" = "2.0.0" ]
}

@test "! after type/scope yields a major bump" {
  git commit --allow-empty -q -m "chore: init"
  git tag 1.0.0
  git commit --allow-empty -q -m "feat!: drop support for legacy config"

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(cat .VERSION)" = "2.0.0" ]
}

@test "mixed range: highest-precedence bump wins" {
  git commit --allow-empty -q -m "chore: init"
  git tag 1.0.0
  git commit --allow-empty -q -m "fix: correct off-by-one"
  git commit --allow-empty -q -m "feat: add search endpoint"
  git commit --allow-empty -q -m "fix: another bugfix"

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(cat .VERSION)" = "1.1.0" ]
}

@test "only non-conforming commits yields no bump, unchanged version" {
  git commit --allow-empty -q -m "chore: init"
  git tag 1.0.0
  git commit --allow-empty -q -m "tidy up whitespace"
  git commit --allow-empty -q -m "update dependencies"

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(cat .VERSION)" = "1.0.0" ]
}

@test "empty range since last Release Tag writes .VERSION with unchanged version" {
  git commit --allow-empty -q -m "chore: init"
  git tag 1.0.0

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(cat .VERSION)" = "1.0.0" ]
}

@test "merge commit in range is excluded from bump determination" {
  git commit --allow-empty -q -m "chore: init"
  git tag 1.0.0

  git checkout -qb feature-branch
  git commit --allow-empty -q -m "feat: this should count"
  git checkout -q master
  git merge --no-ff -q -m "merge: feat!: this merge subject should not count" feature-branch

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(cat .VERSION)" = "1.1.0" ]
}

@test "shallow clone fails with a clear error and no .VERSION mutation" {
  git commit --allow-empty -q -m "chore: init"
  git commit --allow-empty -q -m "feat: add search endpoint"

  SHALLOW_DIR="$(mktemp -d)"
  git clone -q --depth 1 "file://$TEST_DIR" "$SHALLOW_DIR"
  cd "$SHALLOW_DIR"

  run "$SCRIPT"

  [ "$status" -ne 0 ]
  [ -n "$output" ]
  [ ! -e .VERSION ]

  rm -rf "$SHALLOW_DIR"
}

@test "v-prefixed tag is recognized as a Release Tag, bump applies, output stays bare" {
  git commit --allow-empty -q -m "chore: init"
  git tag v1.0.0
  git commit --allow-empty -q -m "fix: correct off-by-one"

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(cat .VERSION)" = "1.0.1" ]
}

@test "most-recent-by-history Release Tag wins regardless of v-prefix style" {
  git commit --allow-empty -q -m "chore: init"
  git tag v1.0.0
  git commit --allow-empty -q -m "fix: correct off-by-one"
  git tag 1.0.1
  git commit --allow-empty -q -m "feat: add search endpoint"

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(cat .VERSION)" = "1.1.0" ]
}

@test "a v-prefixed tag segment with a leading zero is not recognized as a Release Tag" {
  git commit --allow-empty -q -m "chore: init"
  git tag v1.0.08
  git commit --allow-empty -q -m "fix: correct off-by-one"

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(cat .VERSION)" = "0.1.0" ]
}

@test "a non-standard tag prefix is not recognized as a Release Tag" {
  git commit --allow-empty -q -m "chore: init"
  git tag V1.0.0
  git commit --allow-empty -q -m "fix: correct off-by-one"

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(cat .VERSION)" = "0.1.0" ]
}

@test "pre-release tag is not recognized, falls through to prior bare Release Tag" {
  git commit --allow-empty -q -m "chore: init"
  git tag 1.0.0
  git commit --allow-empty -q -m "feat: work in progress"
  git tag 1.1.0-rc.1
  git commit --allow-empty -q -m "fix: another fix"

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(cat .VERSION)" = "1.1.0" ]
}

@test "a tag segment with a leading zero is not recognized as a Release Tag" {
  git commit --allow-empty -q -m "chore: init"
  git tag 1.0.08
  git commit --allow-empty -q -m "fix: correct off-by-one"

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(cat .VERSION)" = "0.1.0" ]
}

@test "running outside a git repository fails with a clear error and no .VERSION mutation" {
  cd "$TEST_DIR"
  rm -rf .git

  run "$SCRIPT"

  [ "$status" -ne 0 ]
  [ -n "$output" ]
  [ ! -e .VERSION ]
}

@test "an empty repository (no commits yet) yields 0.1.0 without leaking git errors" {
  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(cat .VERSION)" = "0.1.0" ]
  [[ "$output" != *fatal* ]]
}

@test "no .semver.json present: behavior is unchanged" {
  git commit --allow-empty -q -m "chore: init"
  git tag 1.0.0
  git commit --allow-empty -q -m "feat: add search endpoint"

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(cat .VERSION)" = "1.1.0" ]
}

@test ".semver.json can add a new custom commit-type rule" {
  cat > .semver.json <<'JSON'
{"rules": {"perf": "patch"}}
JSON
  git commit --allow-empty -q -m "chore: init"
  git tag 1.0.0
  git commit --allow-empty -q -m "perf: speed up query"

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(cat .VERSION)" = "1.0.1" ]
}

@test ".semver.json can override a built-in commit-type rule" {
  cat > .semver.json <<'JSON'
{"rules": {"feat": "major"}}
JSON
  git commit --allow-empty -q -m "chore: init"
  git tag 1.0.0
  git commit --allow-empty -q -m "feat: add search endpoint"

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(cat .VERSION)" = "2.0.0" ]
}

@test ".semver.json rules value 'none' contributes no bump" {
  cat > .semver.json <<'JSON'
{"rules": {"docs": "none"}}
JSON
  git commit --allow-empty -q -m "chore: init"
  git tag 1.0.0
  git commit --allow-empty -q -m "docs: update readme"

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(cat .VERSION)" = "1.0.0" ]
}

@test ".semver.json mixed-precedence: custom and built-in rules combine, highest wins" {
  cat > .semver.json <<'JSON'
{"rules": {"perf": "patch", "docs": "none"}}
JSON
  git commit --allow-empty -q -m "chore: init"
  git tag 1.0.0
  git commit --allow-empty -q -m "docs: update readme"
  git commit --allow-empty -q -m "perf: speed up query"
  git commit --allow-empty -q -m "feat: add search endpoint"

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(cat .VERSION)" = "1.1.0" ]
}

@test "invalid JSON in .semver.json fails with a clear error and no .VERSION mutation" {
  printf '{invalid' > .semver.json
  git commit --allow-empty -q -m "chore: init"
  git tag 1.0.0
  git commit --allow-empty -q -m "feat: add search endpoint"

  run "$SCRIPT"

  [ "$status" -ne 0 ]
  [ -n "$output" ]
  [ ! -e .VERSION ]
}

@test "invalid .semver.json rules value fails with a clear error and no .VERSION mutation" {
  cat > .semver.json <<'JSON'
{"rules": {"perf": "huge"}}
JSON
  git commit --allow-empty -q -m "chore: init"
  git tag 1.0.0
  git commit --allow-empty -q -m "feat: add search endpoint"

  run "$SCRIPT"

  [ "$status" -ne 0 ]
  [ -n "$output" ]
  [ ! -e .VERSION ]
}

@test "invalid .semver.json rules key fails with a clear error and no .VERSION mutation" {
  cat > .semver.json <<'JSON'
{"rules": {"Feat": "minor"}}
JSON
  git commit --allow-empty -q -m "chore: init"
  git tag 1.0.0
  git commit --allow-empty -q -m "feat: add search endpoint"

  run "$SCRIPT"

  [ "$status" -ne 0 ]
  [ -n "$output" ]
  [ ! -e .VERSION ]
}

@test "'breaking' is a reserved .semver.json rules key and is rejected" {
  cat > .semver.json <<'JSON'
{"rules": {"breaking": "major"}}
JSON
  git commit --allow-empty -q -m "chore: init"
  git tag 1.0.0
  git commit --allow-empty -q -m "feat: add search endpoint"

  run "$SCRIPT"

  [ "$status" -ne 0 ]
  [ -n "$output" ]
  [ ! -e .VERSION ]
}

@test "BREAKING CHANGE detection stays independent of .semver.json" {
  cat > .semver.json <<'JSON'
{"rules": {"feat": "none", "fix": "none"}}
JSON
  git commit --allow-empty -q -m "chore: init"
  git tag 1.0.0
  git commit --allow-empty -q -m "feat!: drop support for legacy config"

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(cat .VERSION)" = "2.0.0" ]
}

@test "missing jq with .semver.json present fails with a clear jq-related error, not a JSON error" {
  cat > .semver.json <<'JSON'
{"rules": {"perf": "patch"}}
JSON
  git commit --allow-empty -q -m "chore: init"
  git tag 1.0.0
  git commit --allow-empty -q -m "feat: add search endpoint"

  jq_dir=$(dirname "$(command -v jq)")
  stripped_path=$(printf '%s' "$PATH" | tr ':' '\n' | grep -Fxv "$jq_dir" | tr '\n' ':')

  old_path="$PATH"
  PATH="$stripped_path"
  run "$SCRIPT"
  PATH="$old_path"

  [ "$status" -ne 0 ]
  [[ "$output" == *jq* ]]
  [ ! -e .VERSION ]
}

@test "a non-object .semver.json 'rules' value fails with a clear error and no .VERSION mutation" {
  cat > .semver.json <<'JSON'
{"rules": false}
JSON
  git commit --allow-empty -q -m "chore: init"
  git tag 1.0.0
  git commit --allow-empty -q -m "feat: add search endpoint"

  run "$SCRIPT"

  [ "$status" -ne 0 ]
  [ -n "$output" ]
  [ ! -e .VERSION ]
}

@test "a valid .semver.json with an unrelated \$schema key has no effect on behavior" {
  cat > .semver.json <<'JSON'
{"$schema": "./semver.schema.json", "rules": {"feat": "minor", "fix": "patch"}}
JSON
  git commit --allow-empty -q -m "chore: init"
  git tag 1.0.0
  git commit --allow-empty -q -m "fix: correct off-by-one"

  run "$SCRIPT"

  [ "$status" -eq 0 ]
  [ "$(cat .VERSION)" = "1.0.1" ]
}
