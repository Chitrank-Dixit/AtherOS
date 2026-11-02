#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/../../.." && pwd)
profile="$repo_root/experiments/arch/iso/profile"
out_dir=${AETHER_ARCHISO_OUT:-"$repo_root/out/arch"}

if [[ $(uname -s) != Linux ]]; then
  echo 'BLOCKED: mkarchiso requires a Linux build environment; no changes were made.' >&2
  exit 1
fi
if [[ ! -f /etc/arch-release ]]; then
  echo 'BLOCKED: this profile is intended to be built inside an Arch Linux builder.' >&2
  exit 1
fi
if ! command -v mkarchiso >/dev/null 2>&1; then
  echo 'BLOCKED: mkarchiso is missing. Use a disposable Arch builder with archiso installed.' >&2
  exit 1
fi
mkdir -p "$out_dir"
exec mkarchiso -v -w "$out_dir/work" -o "$out_dir" "$profile"
