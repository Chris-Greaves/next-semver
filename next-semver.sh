#!/usr/bin/env bash
set -eu

SEMVER_RE='^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'

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

bump_type_for_range() {
  local range="$1" bump="" subject message
  while IFS= read -r commit; do
    [ -z "$commit" ] && continue
    message=$(git log -1 --format='%B' "$commit")
    subject=$(printf '%s\n' "$message" | head -1)

    if printf '%s\n' "$message" | grep -Eq '^BREAKING CHANGE:' \
      || printf '%s\n' "$subject" | grep -Eq '^[a-zA-Z]+(\([^)]*\))?!:'; then
      bump="major"
      break
    elif printf '%s\n' "$subject" | grep -Eq '^feat(\([^)]*\))?:'; then
      bump="minor"
    elif printf '%s\n' "$subject" | grep -Eq '^fix(\([^)]*\))?:'; then
      [ -z "$bump" ] && bump="patch"
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

  last_tag=$(find_last_release_tag)

  if [ -z "$last_tag" ]; then
    next_version="0.1.0"
  else
    last_version="${last_tag#v}"
    bump=$(bump_type_for_range "$last_tag..HEAD")
    next_version=$(bump_version "$last_version" "$bump")
  fi

  echo "$next_version" > .VERSION
}

main "$@"
