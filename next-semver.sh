#!/usr/bin/env bash
set -eu

SEMVER_RE='^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
COMMIT_TYPE_RE='^[a-zA-Z]+(\([^)]*\))?'

BUILTIN_RULES_TABLE='feat minor
fix patch'

find_last_release_tag() {
  local commit tag_list t
  for commit in $(git rev-list HEAD 2>/dev/null); do
    tag_list=$(git tag --points-at "$commit" 2>/dev/null || true)
    for t in $tag_list; do
      if echo "$t" | grep -Eq "$SEMVER_RE"; then
        echo "$t"
        return 0
      fi
    done
  done
  return 0
}

# Populates the global RULES_TABLE with the built-in rules, merged with any
# `.semver.json` rules (which override a built-in of the same key, or add a
# new one). Exits the script on malformed config, before anything else runs.
build_rules_table() {
  local config=".semver.json" key value

  RULES_TABLE="$BUILTIN_RULES_TABLE"

  [ -f "$config" ] || return 0

  if ! command -v jq >/dev/null 2>&1; then
    echo "next-semver.sh: jq is required to read $config (see README)" >&2
    exit 1
  fi

  if ! jq empty "$config" >/dev/null 2>&1; then
    echo "next-semver.sh: $config is not valid JSON" >&2
    exit 1
  fi

  if [ "$(jq -r 'if has("rules") then (.rules | type) else "object" end' "$config")" != "object" ]; then
    echo "next-semver.sh: $config 'rules' must be an object" >&2
    exit 1
  fi

  while IFS=$'\t' read -r key value; do
    key="${key%$'\r'}"
    value="${value%$'\r'}"
    [ -z "$key" ] && continue

    if ! printf '%s' "$key" | grep -Eq '^[a-z]+$' || [ "$key" = "breaking" ]; then
      echo "next-semver.sh: $config rules key '$key' is invalid; keys must match ^[a-z]+\$ and must not be 'breaking'" >&2
      exit 1
    fi

    case "$value" in
      major | minor | patch | none) ;;
      *)
        echo "next-semver.sh: $config rules value '$value' for key '$key' is invalid; must be one of major, minor, patch, none" >&2
        exit 1
        ;;
    esac

    RULES_TABLE="$RULES_TABLE
$key $value"
  done < <(jq -r 'if has("rules") then .rules else {} end | to_entries[] | [.key, (.value | tostring)] | @tsv' "$config")
}

# Extracts the commit-type keyword (e.g. "feat") from a conventional-commit
# subject line, or prints nothing if the subject doesn't have that shape.
type_of_commit_subject() {
  local subject="$1"
  if printf '%s\n' "$subject" | grep -Eq "${COMMIT_TYPE_RE}:"; then
    printf '%s\n' "$subject" | grep -Eo '^[a-zA-Z]+'
  fi
}

# Looks up "type" in "table" (lines of "type level"), case-sensitive.
# Prints the level, or nothing if there's no matching row.
level_for_type() {
  local type="$1" table="$2" line line_type line_level level=""
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    line_type="${line%% *}"
    line_level="${line#* }"
    if [ "$line_type" = "$type" ]; then
      level="$line_level"
    fi
  done <<EOF
$table
EOF
  printf '%s' "$level"
}

# Precedence order for Bump Types: major > minor > patch > none/unmatched.
rank_for_level() {
  case "$1" in
    major) echo 3 ;;
    minor) echo 2 ;;
    patch) echo 1 ;;
    *) echo 0 ;;
  esac
}

bump_type_for_range() {
  local range="$1" table="$2"
  local bump="" bump_rank=0 subject message type level rank
  while IFS= read -r commit; do
    [ -z "$commit" ] && continue
    message=$(git log -1 --format='%B' "$commit")
    subject=$(printf '%s\n' "$message" | head -1)

    if printf '%s\n' "$message" | grep -Eq '^BREAKING CHANGE:' \
      || printf '%s\n' "$subject" | grep -Eq "${COMMIT_TYPE_RE}!:"; then
      bump="major"
      break
    fi

    type=$(type_of_commit_subject "$subject")
    [ -z "$type" ] && continue

    level=$(level_for_type "$type" "$table")
    [ -z "$level" ] && continue

    rank=$(rank_for_level "$level")
    if [ "$rank" -gt "$bump_rank" ]; then
      bump="$level"
      bump_rank="$rank"
    fi
  done <<EOF
$(git log --no-merges --format='%H' "$range")
EOF
  echo "$bump"
}

bump_version() {
  local version="$1" bump="$2" major minor patch
  major=$(echo "$version" | cut -d. -f1)
  minor=$(echo "$version" | cut -d. -f2)
  patch=$(echo "$version" | cut -d. -f3)

  case "$bump" in
    major) echo "$((major + 1)).0.0" ;;
    minor) echo "$major.$((minor + 1)).0" ;;
    patch) echo "$major.$minor.$((patch + 1))" ;;
    *) echo "$version" ;;
  esac
}

main() {
  local last_tag last_version next_version bump

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "next-semver.sh: not a git repository" >&2
    exit 1
  fi

  if [ "$(git rev-parse --is-shallow-repository)" = "true" ]; then
    echo "next-semver.sh: this is a shallow git clone; run with full history (git fetch --unshallow) and try again" >&2
    exit 1
  fi

  build_rules_table

  last_tag=$(find_last_release_tag)

  if [ -z "$last_tag" ]; then
    next_version="0.1.0"
  else
    last_version="${last_tag#v}"
    bump=$(bump_type_for_range "$last_tag..HEAD" "$RULES_TABLE")
    next_version=$(bump_version "$last_version" "$bump")
  fi

  echo "$next_version" > .VERSION
}

main "$@"
