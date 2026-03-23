#! /usr/bin/env nix-shell
#! nix-shell -i bash -p nix-update curl jq gnused

set -euo pipefail

API_URL="https://api.github.com/repos/fleetdm/fleet"

VERSION_OVERRIDE=""
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: update.sh [--version X.Y.Z] [--dry-run]

Options:
  --version X.Y.Z  Force a specific orbit version (without v prefix)
  --dry-run        Print resolved metadata without modifying files
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --version)
      VERSION_OVERRIDE="${2:-}"
      if [ -z "$VERSION_OVERRIDE" ]; then
        usage
        exit 1
      fi
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
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

DATA=$(curl -s "$API_URL/git/refs/tags" | jq -r --arg ver "$VERSION_OVERRIDE" '
  [ .[]
    | select(.ref | test("^refs/tags/orbit-v[0-9]+[.][0-9]+[.][0-9]+$"))
    | {
        tag: (.ref | sub("^refs/tags/"; "")),
        sha: .object.sha,
        type: .object.type,
        ver: (.ref | capture("v(?<ver>.*)$").ver)
      }
  ]
  | if $ver != "" then map(select(.ver == $ver)) else . end
  | sort_by(.ver | split(".") | map(tonumber))
  | last
')

VERSION=$(jq -r '.ver' <<< "$DATA")
REF_SHA=$(jq -r '.sha' <<< "$DATA")
REF_TYPE=$(jq -r '.type' <<< "$DATA")
if [ -z "$VERSION" ] || [ "$VERSION" = "null" ]; then
  printf 'No matching orbit tag found for version: %s\n' "${VERSION_OVERRIDE:-latest}" >&2
  exit 1
fi
if [ "$REF_TYPE" = "tag" ]; then
  SHA=$(curl -s "$API_URL/git/tags/$REF_SHA" | jq -r '.object.sha')
else
  SHA="$REF_SHA"
fi
DATE=$(curl -s "$API_URL/commits/$SHA" | jq -r '.commit.committer.date')

printf 'Found the following version:\n\n'
printf 'version=%s\n' "$VERSION"
printf 'commit=%s\n' "$SHA"
printf 'date=%s\n' "$DATE"

if [ "$DRY_RUN" -eq 1 ]; then
  exit 0
fi

sed -i "s|commit = \"[^\"]*\";|commit = \"${SHA}\";|" pkgs/default.nix
sed -i "s|date = \"[^\"]*\";|date = \"${DATE}\";|" pkgs/default.nix

nix-update orbit --version-regex 'orbit-v(.*)' --flake --version "$VERSION"
