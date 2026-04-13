#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT=$(git rev-parse --show-toplevel)
FLEET_DIR=${FLEET_DIR:-"${REPO_ROOT}/../fleet"}
BASE_REF=${BASE_REF:-""}
HEAD_REF=${HEAD_REF:-"HEAD"}
OUTPUT_DIR=${OUTPUT_DIR:-"${REPO_ROOT}/patches"}

usage() {
  cat <<'EOF'
Export a commit range from ../fleet into patch files.

Usage:
  ./export-patches.sh --base <ref> [--head <ref>] [--fleet-dir <path>] [--output-dir <path>]

Behavior:
  - Exports one patch per commit in base..head (oldest to newest)
  - Filename format: NNNN-<first-line-of-commit-message>.patch
  - The first line of each commit message becomes the patch name (sanitized)

Examples:
  ./export-patches.sh --base 6f9e4ce --head orbit-nixos-patches
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --base)
      BASE_REF="${2:-}"
      shift 2
      ;;
    --head)
      HEAD_REF="${2:-}"
      shift 2
      ;;
    --fleet-dir)
      FLEET_DIR="${2:-}"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="${2:-}"
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

if [ -z "$BASE_REF" ]; then
  printf 'error: --base is required\n' >&2
  usage
  exit 1
fi

if ! git -C "$FLEET_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'error: not a git repo: %s\n' "$FLEET_DIR" >&2
  exit 1
fi

if ! git -C "$FLEET_DIR" rev-parse --verify "$BASE_REF^{commit}" >/dev/null 2>&1; then
  printf 'error: base ref not found: %s\n' "$BASE_REF" >&2
  exit 1
fi

if ! git -C "$FLEET_DIR" rev-parse --verify "$HEAD_REF^{commit}" >/dev/null 2>&1; then
  printf 'error: head ref not found: %s\n' "$HEAD_REF" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIR"
rm -f "${OUTPUT_DIR}"/[0-9][0-9][0-9][0-9]-*.patch

mapfile -t commits < <(git -C "$FLEET_DIR" rev-list --reverse "${BASE_REF}..${HEAD_REF}")

if [ "${#commits[@]}" -eq 0 ]; then
  printf 'No commits found in range %s..%s\n' "$BASE_REF" "$HEAD_REF"
  exit 0
fi

idx=1
for commit in "${commits[@]}"; do
  subject=$(git -C "$FLEET_DIR" show -s --format=%s "$commit")
  slug=$(printf '%s' "$subject" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//; s/-+/-/g')
  if [ -z "$slug" ]; then
    slug="patch"
  fi

  out_file=$(printf '%s/%04d-%s.patch' "$OUTPUT_DIR" "$idx" "$slug")
  printf 'Writing %s\n' "$out_file"
  git -C "$FLEET_DIR" show --no-color --pretty=format: "$commit" > "$out_file"

  idx=$((idx + 1))
done

printf 'Exported %d patches from %s..%s\n' "${#commits[@]}" "$BASE_REF" "$HEAD_REF"
