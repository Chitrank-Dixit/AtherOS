#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/../../.." && pwd)
cd "$repo_root"

if ! command -v nix >/dev/null 2>&1; then
  echo 'BLOCKED: Nix is unavailable. Use a disposable Linux builder with Nix flakes enabled.' >&2
  exit 1
fi
if [[ ! -f experiments/nixos/flake.lock ]]; then
  echo 'BLOCKED: experiments/nixos/flake.lock is missing. Run nix flake lock in the disposable builder, review and commit the lock, then retry.' >&2
  exit 1
fi
exec nix --extra-experimental-features 'nix-command flakes' build ./experiments/nixos#nixos-iso
