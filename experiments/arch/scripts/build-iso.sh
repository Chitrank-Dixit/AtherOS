#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/../../.." && pwd)
profile_name=${AETHER_ARCHISO_PROFILE:-minimal}
case "$profile_name" in
  minimal) profile="$repo_root/experiments/arch/iso/profile" ;;
  desktop-gnome) profile="$repo_root/experiments/arch/iso/desktop-gnome" ;;
  *) echo 'ERROR: AETHER_ARCHISO_PROFILE must be minimal or desktop-gnome.' >&2; exit 2 ;;
esac
out_dir=${AETHER_ARCHISO_OUT:-"$repo_root/out/arch/$profile_name"}

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
if [[ ${AETHER_ARCHISO_DISPOSABLE:-0} != 1 ]]; then
  echo 'BLOCKED: set AETHER_ARCHISO_DISPOSABLE=1 only inside a disposable Arch VM before building.' >&2
  exit 1
fi
if ! command -v systemd-detect-virt >/dev/null 2>&1 || ! systemd-detect-virt --vm >/dev/null 2>&1; then
  echo 'BLOCKED: no VM was detected. ISO builds are restricted to a disposable VM.' >&2
  exit 1
fi
mkdir -p "$out_dir"
mkarchiso -v -w "$out_dir/work" -o "$out_dir" "$profile"
mapfile -t images < <(find "$out_dir" -maxdepth 1 -type f -name '*.iso' -print | sort)
if (( ${#images[@]} == 0 )); then
  echo "ERROR: mkarchiso completed without producing an ISO under $out_dir." >&2
  exit 1
fi
sha256sum "${images[@]}" | tee "$out_dir/SHA256SUMS"
sha512sum "${images[@]}" | tee "$out_dir/SHA512SUMS"
