#!/usr/bin/env bash
# Find exactly one regular ISO below the Nix result directory without following inner symlinks.
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 RESULT_SYMLINK [ALLOWED_STORE_ROOT]" >&2
  exit 2
fi
result_link=$1
store_root=${2:-/nix/store}
if [[ ! -L $result_link ]]; then
  echo "ERROR: Nix result path is not a symlink: $result_link" >&2
  exit 1
fi
if ! result_root=$(realpath -e -- "$result_link"); then
  echo "ERROR: cannot resolve Nix result symlink: $result_link" >&2
  exit 1
fi
if ! allowed_root=$(realpath -e -- "$store_root"); then
  echo "ERROR: allowed Nix store root is unavailable: $store_root" >&2
  exit 1
fi
case "$result_root/" in
  "$allowed_root"/*) ;;
  *) echo "ERROR: Nix result target is outside the allowed store root: $result_root" >&2; exit 1 ;;
esac
if [[ ! -d $result_root ]]; then
  echo "ERROR: Nix result target is not a directory: $result_root" >&2
  exit 1
fi
mapfile -d '' artifacts < <(find -P "$result_root" -type f -name '*.iso' -print0)
if (( ${#artifacts[@]} == 0 )); then
  echo "ERROR: no regular ISO artifact found below $result_root" >&2
  exit 1
fi
if (( ${#artifacts[@]} != 1 )); then
  printf 'ERROR: expected exactly one ISO under %s; found %s:\n' "$result_root" "${#artifacts[@]}" >&2
  printf '  %s\n' "${artifacts[@]}" >&2
  exit 1
fi
relative=${artifacts[0]#"$result_root"/}
if [[ $relative == *$'\n'* || $relative == *$'\t'* ]]; then
  echo 'ERROR: ISO artifact path contains unsupported control characters' >&2
  exit 1
fi
if [[ ! $relative =~ ^[A-Za-z0-9._/-]+$ ]]; then
  echo 'ERROR: ISO artifact path contains unsupported characters for the metadata record' >&2
  exit 1
fi
printf '%s\t%s\n' "${artifacts[0]}" "$relative"
