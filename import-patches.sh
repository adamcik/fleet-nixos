#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
FLEET_DIR=${FLEET_DIR:-"${REPO_ROOT}/../fleet"}
PATCH_DIR=${PATCH_DIR:-"${REPO_ROOT}/patches"}
BASE_TAG=${BASE_TAG:-"orbit-v1.54.0"}
BRANCH=${BRANCH:-"orbit-nixos-patches"}

usage() {
  cat <<'EOF'
Create/refresh a Fleet patch branch from local patch files.

Usage:
  ./import-patches.sh [options]

Options:
  --fleet-dir PATH   Fleet checkout path (default: ../fleet)
  --patch-dir PATH   Patch directory (default: ./patches)
  --base-tag TAG     Base tag/commit for branch (default: orbit-v1.54.0)
  --branch NAME      Branch to (re)create (default: orbit-nixos-patches)

Environment alternatives:
  FLEET_DIR, PATCH_DIR, BASE_TAG, BRANCH

Behavior:
  - Fetches tags in Fleet checkout
  - Resets branch to BASE_TAG (`git checkout -B`)
  - Applies patches in lexical order from PATCH_DIR/NNNN-*.patch
  - Creates one commit per patch

Commit message:
  - Derived from patch filename without .patch
  - Leading numeric prefix like 0001- is stripped
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --fleet-dir)
      FLEET_DIR="${2:-}"
      shift 2
      ;;
    --patch-dir)
      PATCH_DIR="${2:-}"
      shift 2
      ;;
    --base-tag)
      BASE_TAG="${2:-}"
      shift 2
      ;;
    --branch)
      BRANCH="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

if ! git -C "$FLEET_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'error: not a git repository: %s\n' "$FLEET_DIR" >&2
  exit 1
fi

if [ ! -d "$PATCH_DIR" ]; then
  printf 'error: patch directory not found: %s\n' "$PATCH_DIR" >&2
  exit 1
fi

shopt -s nullglob
patches=("${PATCH_DIR}"/[0-9][0-9][0-9][0-9]-*.patch)
shopt -u nullglob

if [ "${#patches[@]}" -eq 0 ]; then
  printf 'error: no patch files found in %s\n' "$PATCH_DIR" >&2
  exit 1
fi

IFS=$'\n' patches=($(printf '%s\n' "${patches[@]}" | sort))
unset IFS

git -C "$FLEET_DIR" fetch --tags origin
git -C "$FLEET_DIR" checkout -B "$BRANCH" "$BASE_TAG"

for patch in "${patches[@]}"; do
  file=$(basename "$patch")
  msg=${file%.patch}
  msg=$(printf '%s' "$msg" | sed -E 's/^[0-9]+-//')
  if [ -z "$msg" ]; then
    msg="patch"
  fi

  printf 'Applying %s\n' "$file"
  if grep -q '^diff --git ' "$patch"; then
    git -C "$FLEET_DIR" apply "$patch"
  else
    patch --no-backup-if-mismatch -d "$FLEET_DIR" -p1 < "$patch"
  fi
  git -C "$FLEET_DIR" add -A

  if git -C "$FLEET_DIR" diff --cached --quiet; then
    printf 'warning: %s produced no staged changes, skipping commit\n' "$file"
    continue
  fi

  git -C "$FLEET_DIR" commit -m "$msg"
done

printf '\nDone. Branch %s now contains patch commits on top of %s\n' "$BRANCH" "$BASE_TAG"
git -C "$FLEET_DIR" --no-pager log --oneline "${BASE_TAG}..${BRANCH}"
