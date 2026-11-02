#!/usr/bin/env bash
set -euo pipefail
usage() { echo "Usage: $0 arch|nixos" >&2; exit 2; }
[[ $# -eq 1 ]] || usage
target=$1
case "$target" in arch|nixos) ;; *) usage ;; esac
failures=0
require() {
  if command -v "$1" >/dev/null 2>&1; then
    printf 'FOUND: %s (%s)\n' "$1" "$(command -v "$1")"
  else
    printf 'MISSING: %s\n' "$1" >&2
    failures=$((failures + 1))
  fi
}
printf 'Environment check for %s (read-only; no packages or host settings will be changed)\n' "$target"
case "$target" in
  arch)
    require bash
    require mkarchiso
    if [[ $(uname -s) != Linux ]]; then
      echo 'BLOCKED: Arch ISO building requires a Linux build environment.' >&2
      failures=$((failures + 1))
    elif [[ ! -f /etc/arch-release ]]; then
      echo 'BLOCKED: use an Arch Linux builder for this experiment.' >&2
      failures=$((failures + 1))
    fi
    ;;
  nixos)
    require nix
    if ! nix --version >/dev/null 2>&1; then
      echo 'BLOCKED: Nix is not runnable in this environment.' >&2
      failures=$((failures + 1))
    else
      nix --version
    fi
    ;;
esac
if (( failures > 0 )); then
  printf 'Prerequisites unavailable: %d check(s) failed. No changes were made.\n' "$failures" >&2
  exit 1
fi
echo 'Prerequisite checks passed. This does not validate an ISO or VM boot.'
