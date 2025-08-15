#! /usr/bin/env nix-shell
#! nix-shell -i bash -p nix-update curl jq gnused gh

set -euo pipefail

API_URL="https://api.github.com/repos/fleetdm/fleet"

DATA=$(curl -s "$API_URL/git/refs/tags" | jq -r '
  [ .[]
    | select(.ref | test("^refs/tags/orbit-v[0-9]+[.][0-9]+[.][0-9]+$"))
    | {
        tag: (.ref | sub("^refs/tags/"; "")),
        sha: .object.sha,
        ver: (.ref | capture("^refs/tags/orbit-v(?<ver>.*)$").ver)
      }
  ]
  | sort_by(.ver | split(".") | map(tonumber))
  | last
')

VERSION=$(jq -r '.ver' <<< "$DATA")
SHA=$(jq -r '.sha' <<< "$DATA")
DATE=$(curl -s "$API_URL/commits/$SHA" | jq -r '.commit.committer.date')

sed -i "s|commit = \"[^\"]*\";|commit = \"${SHA}\";|" pkgs/default.nix
sed -i "s|date = \"[^\"]*\";|date = \"${DATE}\";|" pkgs/default.nix

nix-update orbit --version-regex 'orbit-v(.*)' --flake --version "$VERSION"
