#!/usr/bin/env bash
set -euo pipefail

# The flake supplies a locked runtime for manual runs and the Renovate runner.
exec nix run --no-write-lock-file .#update-orbit -- "$@"
