#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/../../.." && pwd)
profile_name=${1:-${AETHER_ARCHISO_PROFILE:-minimal}}
case "$profile_name" in
  minimal) profile="$repo_root/experiments/arch/iso/profile" ;;
  desktop-gnome) profile="$repo_root/experiments/arch/iso/desktop-gnome" ;;
  *) echo 'ERROR: AETHER_ARCHISO_PROFILE must be minimal or desktop-gnome.' >&2; exit 2 ;;
esac
out_root=${AETHER_ARCHISO_OUT:-"$repo_root/out/arch/$profile_name"}
snapshot=${AETHER_ARCHISO_REPO_SNAPSHOT:-}

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
if [[ ! $snapshot =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}$ ]]; then
  echo 'BLOCKED: set AETHER_ARCHISO_REPO_SNAPSHOT to a reviewed Arch Linux Archive date (YYYY/MM/DD).' >&2
  exit 1
fi
if [[ ${AETHER_PODMAN_BUILD:-0} == 1 && -f /.containerenv ]]; then
  echo 'Build environment: rootless Podman container; namespace preflight is required by wrapper.'
elif ! command -v systemd-detect-virt >/dev/null 2>&1 || ! systemd-detect-virt --vm >/dev/null 2>&1; then
  echo 'BLOCKED: no VM was detected. ISO builds are restricted to a disposable VM.' >&2
  exit 1
fi
build_id=$(date -u +'%Y%m%dT%H%M%SZ')
out_dir="$out_root/$build_id"
if [[ -e $out_dir ]]; then
  echo "ERROR: refusing to reuse existing output directory: $out_dir" >&2
  exit 1
fi
mkdir -p "$out_dir/work" "$out_dir/repo-config" "$out_dir/cache"
cat > "$out_dir/repo-config/pacman.conf" <<EOF
[options]
Architecture = auto
SigLevel = Required DatabaseOptional
CacheDir = $out_dir/cache
GPGDir = /etc/pacman.d/gnupg
HookDir = /etc/pacman.d/hooks

[core]
Server = https://archive.archlinux.org/repos/$snapshot/\$repo/os/\$arch

[extra]
Server = https://archive.archlinux.org/repos/$snapshot/\$repo/os/\$arch
EOF
date -u +'%Y-%m-%dT%H:%M:%SZ' > "$out_dir/build-started-utc.txt"
git -C "$repo_root" rev-parse HEAD > "$out_dir/git-commit.txt" 2>/dev/null || echo UNKNOWN > "$out_dir/git-commit.txt"
pacman -Q archiso > "$out_dir/archiso-version.txt" 2>&1 || echo UNKNOWN > "$out_dir/archiso-version.txt"
printf 'profile=%s\nsnapshot=%s\nbuilder=%s\n' "$profile_name" "${snapshot}" "$(uname -srmo)" > "$out_dir/build-inputs.txt"
set +e
mkarchiso -v -C "$out_dir/repo-config/pacman.conf" -w "$out_dir/work" -o "$out_dir" "$profile" > "$out_dir/build.log" 2>&1
build_status=$?
set -e
cat "$out_dir/build.log"
printf 'exit_code=%s\n' "$build_status" > "$out_dir/build-result.txt"
if (( build_status != 0 )); then
  {
    printf 'profile=%s\nrepository_snapshot=%s\nbuild_timestamp_utc=%s\n' "$profile_name" "$snapshot" "$(cat "$out_dir/build-started-utc.txt")"
    printf 'git_commit=%s\n' "$(cat "$out_dir/git-commit.txt")"
    printf 'podman_version=%s\npodman_image_digest=%s\n' "${AETHER_PODMAN_VERSION:-not-applicable}" "${AETHER_BUILDER_IMAGE_DIGEST:-not-applicable}"
    printf 'build_result=FAILED\nexit_code=%s\nlog=%s/build.log\n' "$build_status" "$out_dir"
  } > "$out_dir/metadata.txt"
  echo "FAILED: mkarchiso exited with $build_status; see $out_dir/build.log" >&2
  exit "$build_status"
fi
manifest_db="$out_dir/work/x86_64/airootfs/var/lib/pacman/local"
if [[ -d $manifest_db ]]; then
  find "$manifest_db" -type f -name desc -print0 | sort -z | xargs -0 -r awk '/^%NAME%$/ { getline; name=$0 } /^%VERSION%$/ { getline; print name " " $0 }' > "$out_dir/package-manifest.txt"
else
  printf 'UNAVAILABLE: archiso package database was not found at %s\n' "$manifest_db" > "$out_dir/package-manifest.txt"
fi
mapfile -t images < <(find "$out_dir" -maxdepth 1 -type f -name '*.iso' -print | sort)
if (( ${#images[@]} == 0 )); then
  echo "ERROR: mkarchiso completed without producing an ISO under $out_dir." >&2
  exit 1
fi
sha256sum "${images[@]}" | tee "$out_dir/SHA256SUMS"
sha512sum "${images[@]}" | tee "$out_dir/SHA512SUMS"
{
  printf 'profile=%s\nrepository_snapshot=%s\ngit_commit=%s\narchiso=' "$profile_name" "$snapshot" "$(cat "$out_dir/git-commit.txt")"
  printf 'build_timestamp_utc=%s\n' "$(cat "$out_dir/build-started-utc.txt")"
  cat "$out_dir/archiso-version.txt"
  printf 'builder=%s\n' "$(uname -srmo)"
  for image in "${images[@]}"; do
    printf 'iso=%s\nbytes=%s\n' "$(basename "$image")" "$(stat -c '%s' "$image")"
    printf 'sha256=%s\n' "$(sha256sum "$image" | cut -d ' ' -f 1)"
    printf 'sha512=%s\n' "$(sha512sum "$image" | cut -d ' ' -f 1)"
  done
  printf 'build_result=PASSED\n'
  printf 'podman_version=%s\npodman_image_digest=%s\n' "${AETHER_PODMAN_VERSION:-not-applicable}" "${AETHER_BUILDER_IMAGE_DIGEST:-not-applicable}"
  printf 'package_manifest=%s\n' "$out_dir/package-manifest.txt"
  cat "$out_dir/package-manifest.txt"
} > "$out_dir/metadata.txt"
printf 'Build evidence: %s\n' "$out_dir"
