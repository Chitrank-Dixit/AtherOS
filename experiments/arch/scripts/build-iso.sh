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
base_image=${AETHER_ARCH_BASE_IMAGE_REF:-not-applicable}

if [[ $(uname -s) != Linux ]]; then
  echo 'BLOCKED: mkarchiso requires a Linux build environment; no changes were made.' >&2
  exit 1
fi
if [[ ! -f /etc/arch-release ]]; then
  echo 'BLOCKED: this profile is intended to be built inside an Arch Linux builder.' >&2
  exit 1
fi
for tool in mkarchiso pacman python3 sha256sum sha512sum; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "BLOCKED: required command $tool is missing." >&2
    exit 1
  fi
done
if [[ ${AETHER_ARCHISO_DISPOSABLE:-0} != 1 ]]; then
  echo 'BLOCKED: set AETHER_ARCHISO_DISPOSABLE=1 only inside a disposable Arch VM before building.' >&2
  exit 1
fi
if ! python3 "$repo_root/scripts/experiments/arch_snapshot.py" --validate-date "$snapshot" >/dev/null 2>&1; then
  echo 'BLOCKED: set AETHER_ARCHISO_REPO_SNAPSHOT to a valid Arch Linux Archive date (YYYY/MM/DD).' >&2
  exit 1
fi
if [[ ${AETHER_PODMAN_BUILD:-0} == 1 && -f /.containerenv ]]; then
  if ! python3 "$repo_root/scripts/experiments/arch_snapshot.py" "$snapshot" "$base_image" >/dev/null; then
    echo 'BLOCKED: container builds require an explicit snapshot and matching digest-pinned Arch base reference.' >&2
    exit 1
  fi
fi
if [[ ${AETHER_PODMAN_BUILD:-0} == 1 && -f /.containerenv ]]; then
  echo 'Build environment: rootless Podman container; namespace preflight is required by wrapper.'
elif ! command -v systemd-detect-virt >/dev/null 2>&1 || ! systemd-detect-virt --vm >/dev/null 2>&1; then
  echo 'BLOCKED: no VM was detected. ISO builds are restricted to a disposable VM.' >&2
  exit 1
fi

build_id="$(date -u +'%Y%m%dT%H%M%SZ')-$$"
out_dir="$out_root/$build_id"
if [[ -e $out_dir || -L $out_dir ]]; then
  echo "ERROR: refusing to reuse existing output path: $out_dir" >&2
  exit 1
fi
if ! mkdir -p "$out_dir/work" "$out_dir/repo-config" "$out_dir/cache"; then
  echo "ERROR: cannot create build output at $out_dir" >&2
  exit 1
fi
: > "$out_dir/manifest.log"
: > "$out_dir/provenance.log"
printf 'Package manifest has not yet been collected.\n' > "$out_dir/package-manifest.txt"
date -u +'%Y-%m-%dT%H:%M:%SZ' > "$out_dir/build-started-utc.txt"
git -C "$repo_root" rev-parse HEAD > "$out_dir/git-commit.txt" 2>/dev/null || echo UNKNOWN > "$out_dir/git-commit.txt"
archiso_version_status=PASSED
if ! pacman -Q archiso > "$out_dir/archiso-version.txt" 2>&1; then
  archiso_version_status=FAILED
  echo 'BLOCKED: archiso package version could not be queried.' > "$out_dir/archiso-version.txt"
fi

base_digest=not-applicable
if [[ $base_image =~ @sha256:([a-f0-9]{64})$ ]]; then base_digest="sha256:${BASH_REMATCH[1]}"; fi
if [[ ${AETHER_PODMAN_BUILD:-0} == 1 && -f /.containerenv ]]; then
  if ! python3 "$repo_root/scripts/experiments/arch_snapshot.py" "$snapshot" "$base_image" > "$out_dir/base-image-input.txt"; then
    echo 'BLOCKED: base image reference and archive date did not validate.' >&2
    exit 1
  fi
  base_digest=$(sed -n 's/^digest=//p' "$out_dir/base-image-input.txt")
fi

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
printf 'profile=%s\nsnapshot=%s\nbuilder=%s\nbase_image_ref=%s\nbase_image_digest=%s\n' \
  "$profile_name" "$snapshot" "$(uname -srmo)" "$base_image" "$base_digest" > "$out_dir/build-inputs.txt"
printf 'reproducibility=EXPERIMENTAL: bootstrap image or disposable VM packages may not originate from the selected archive snapshot; pacman does not downgrade them\n' \
  >> "$out_dir/build-inputs.txt"

stage=build
set +e
mkarchiso -v -C "$out_dir/repo-config/pacman.conf" -w "$out_dir/work" -o "$out_dir" "$profile" > "$out_dir/build.log" 2>&1
build_status=$?
set -e
cat "$out_dir/build.log"
printf 'exit_code=%s\n' "$build_status" > "$out_dir/build-result.txt"

record() {
  local overall="$1" artifact_status="$2" checksum_status="$3" manifest_status="$4" complete="$5" stage_name="$6" actual="$7" error="$8"
  local blockers=''
  local base_image_json=''
  local builder_digest_json=''
  local iso_checksum_json=''
  local checksum_logs=''
  if [[ $overall == BLOCKED ]]; then blockers=', "blockers": ["'"$error"'"]'; fi
  if [[ $base_digest != not-applicable ]]; then
    base_image_json=', "arch_base_image": "'"$base_image"'", "arch_base_image_digest": "'"$base_digest"'"'
  fi
  if [[ ${AETHER_BUILDER_IMAGE_DIGEST:-} =~ ^sha256:[a-f0-9]{64}$ ]]; then
    builder_digest_json=', "builder_image_digest": "'"$AETHER_BUILDER_IMAGE_DIGEST"'"'
  fi
  if [[ -n ${iso_sha256:-} ]]; then
    iso_checksum_json=', "iso_sha256": "'"$iso_sha256"'"'
  fi
  if [[ $checksum_status == PASSED ]]; then
    checksum_logs=', "SHA256SUMS", "SHA512SUMS"'
  fi
  cat > "$out_dir/experiment-record.json" <<EOF
{
  "id": "ARCH-BUILD-$build_id",
  "status": "$overall",
  "distribution": "Arch Linux",
  "distribution_revision": "$snapshot",
  "builder_environment": "$(uname -srmo)",
  "environment": "Disposable Linux builder; see build-inputs.txt",
  "os_revision": "Arch Linux Archive $snapshot",
  "package_revisions": [],
  "commands": ["mkarchiso -v -C repo-config/pacman.conf -w work -o output profile"],
  "expected": "Build the selected Archiso profile and collect its package manifest and checksums",
  "actual": "$actual",
  "evidence": ["build.log", "build-result.txt", "build-inputs.txt"],
  "limitations": ["Archive packages and builder bootstrap state are separate provenance inputs; binary reproducibility is not claimed"],
  "logs": ["build.log", "metadata.txt", "manifest.log", "provenance.log", "package-manifest.txt"$checksum_logs],
  "build_status": "$([[ $build_status == 0 ]] && echo PASSED || echo FAILED)",
  "artifact_status": "$artifact_status",
  "checksum_status": "$checksum_status",
  "package_manifest_status": "$manifest_status",
  "archiso_version_status": "$archiso_version_status",
  "evidence_complete": $complete,
  "build_stage": "$stage_name",
  "error": "$error",
  "arch_archive_snapshot": "$snapshot",
  "package_manifest": "package-manifest.txt"$base_image_json$builder_digest_json$iso_checksum_json$blockers
}
EOF
}

if (( build_status != 0 )); then
  printf 'build_result=FAILED\nartifact_status=NOT TESTED\nchecksum_status=NOT TESTED\npackage_manifest_status=NOT TESTED\nevidence_complete=false\n' > "$out_dir/metadata.txt"
  record FAILED NOT\ TESTED NOT\ TESTED NOT\ TESTED false build "mkarchiso exited with status $build_status" 'mkarchiso build failed; see build.log'
  echo "FAILED: mkarchiso exited with $build_status; evidence retained at $out_dir" >&2
  exit "$build_status"
fi

manifest_db="$out_dir/work/x86_64/airootfs/var/lib/pacman/local"
manifest_status=PASSED
if ! python3 "$repo_root/scripts/experiments/arch_evidence.py" "$manifest_db" "$out_dir/package-manifest.txt" > "$out_dir/manifest.log" 2>&1; then
  manifest_status=FAILED
  cat "$out_dir/manifest.log" >&2
  printf 'UNAVAILABLE: package database or complete package descriptions were not available.\n' > "$out_dir/package-manifest.txt"
fi
mapfile -t images < <(find "$out_dir" -maxdepth 1 -type f -name '*.iso' -print | sort)
if (( ${#images[@]} == 0 )); then
  printf 'build_result=PASSED\nartifact_status=FAILED\nchecksum_status=NOT TESTED\npackage_manifest_status=%s\nevidence_complete=false\n' "$manifest_status" > "$out_dir/metadata.txt"
  record FAILED FAILED NOT\ TESTED "$manifest_status" false artifact-discovery 'mkarchiso exited successfully but produced no ISO' 'no ISO artifact was found'
  echo "ERROR: no ISO artifact was found; evidence retained at $out_dir" >&2
  exit 1
fi

checksum_status=PASSED
if ! sha256sum "${images[@]}" > "$out_dir/SHA256SUMS"; then checksum_status=FAILED; fi
if ! sha512sum "${images[@]}" > "$out_dir/SHA512SUMS"; then checksum_status=FAILED; fi
if [[ $checksum_status == FAILED ]]; then
  printf 'build_result=PASSED\nartifact_status=PASSED\nchecksum_status=FAILED\npackage_manifest_status=%s\nevidence_complete=false\n' "$manifest_status" > "$out_dir/metadata.txt"
  record FAILED PASSED FAILED "$manifest_status" false checksum 'ISO was generated but checksum collection failed' 'checksum generation failed'
  echo "ERROR: checksum collection failed; evidence retained at $out_dir" >&2
  exit 1
fi
if (( ${#images[@]} == 1 )); then iso_sha256=$(sha256sum "${images[0]}" | cut -d ' ' -f 1); fi

stage_name=metadata-generation
if ! python3 "$repo_root/scripts/experiments/arch_snapshot.py" --write-metadata \
  "$out_dir/arch-provenance.json" "$snapshot" "$base_image" "$base_digest" \
  "${AETHER_BUILDER_IMAGE_DIGEST:-}" "$(cat "$out_dir/archiso-version.txt")" > "$out_dir/provenance.log" 2>&1; then
  manifest_log=$(cat "$out_dir/provenance.log")
  printf 'build_status=PASSED\nartifact_status=PASSED\nchecksum_status=PASSED\npackage_manifest_status=%s\nevidence_complete=false\n' "$manifest_status" > "$out_dir/metadata.txt"
  record FAILED PASSED PASSED "$manifest_status" false metadata-generation 'build succeeded but provenance metadata generation failed' 'see provenance.log'
  echo "$manifest_log" >&2
  exit 1
fi

evidence_complete=true
overall=PASSED
stage_name=complete
actual='build, artifact, checksums, and package manifest were recorded'
error=none
if [[ $manifest_status != PASSED || $archiso_version_status != PASSED ]]; then
  evidence_complete=false
  overall=FAILED
  if [[ $manifest_status != PASSED ]]; then
    stage_name=package-manifest
    actual='ISO build and checksums passed but package-manifest evidence is incomplete'
    error='package-manifest validation failed; see manifest.log'
  else
    stage_name=archiso-version
    actual='ISO build and checksums passed but Archiso version evidence is incomplete'
    error='Archiso package version query failed'
  fi
fi
{
  cat "$out_dir/build-inputs.txt"
  printf 'build_status=PASSED\nartifact_status=PASSED\nchecksum_status=%s\npackage_manifest_status=%s\narchiso_version_status=%s\nevidence_complete=%s\n' \
    "$checksum_status" "$manifest_status" "$archiso_version_status" "$evidence_complete"
  cat "$out_dir/archiso-version.txt"
  for image in "${images[@]}"; do
    printf 'iso=%s\nbytes=%s\n' "$(basename "$image")" "$(stat -c '%s' "$image")"
    printf 'sha256=%s\n' "$(sha256sum "$image" | cut -d ' ' -f 1)"
    printf 'sha512=%s\n' "$(sha512sum "$image" | cut -d ' ' -f 1)"
  done
  printf 'package_manifest=package-manifest.txt\n'
  cat "$out_dir/package-manifest.txt"
  printf 'arch_provenance=arch-provenance.json\n'
} > "$out_dir/metadata.txt"
record "$overall" PASSED "$checksum_status" "$manifest_status" "$evidence_complete" "$stage_name" "$actual" "$error"
printf 'Build evidence: %s\n' "$out_dir"
if [[ $overall != PASSED ]]; then exit 1; fi
