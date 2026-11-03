#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/../../.." && pwd)
cd "$repo_root"

out_root=${AETHER_NIXOS_OUT:-"$repo_root/out/nixos"}
build_id="$(date -u +'%Y%m%dT%H%M%SZ')-$$"
out_dir="$out_root/$build_id"
result_link="/tmp/aether-nixos-result-$build_id"
if [[ -e $out_dir || -L $out_dir ]]; then
  echo "ERROR: refusing to reuse existing output directory: $out_dir" >&2
  exit 1
fi
if ! mkdir -p "$out_root" || ! mkdir "$out_dir"; then
  echo "ERROR: could not create a fresh Nix build output directory: $out_dir" >&2
  exit 1
fi
: > "$out_dir/metadata.log"
: > "$out_dir/build.log"
: > "$out_dir/artifact-discovery.log"
: > "$out_dir/checksum.log"
: > "$out_dir/lock-revision.log"
uname -srmo > "$out_dir/environment.txt" 2>&1 || echo unavailable > "$out_dir/environment.txt"
printf 'architecture=%s\n' "$(uname -m 2>/dev/null || echo unavailable)" >> "$out_dir/environment.txt"
printf 'nix-version=unavailable\n' > "$out_dir/nix-version.txt"
git rev-parse HEAD > "$out_dir/git-commit.txt" 2>/dev/null || echo UNKNOWN > "$out_dir/git-commit.txt"

nixpkgs_rev=unavailable
stage=prerequisite
write_record() {
  local overall="$1" build="$2" artifact="$3" checksum="$4" complete="$5" actual="$6" error="$7"
  local blocker_json=''
  local relative_json=''
  local checksum_json=''
  local checksum_logs=''
  if [[ $overall == BLOCKED ]]; then blocker_json=', "blockers": ["'"$error"'"]'; fi
  if [[ -n ${relative_iso:-} ]]; then relative_json=', "artifact_relative_path": "'"$relative_iso"'"'; fi
  if [[ -n ${iso_sha256:-} ]]; then checksum_json=', "iso_sha256": "'"$iso_sha256"'"'; fi
  if [[ $checksum == PASSED ]]; then checksum_logs=', "SHA256SUMS", "SHA512SUMS"'; fi
  cat > "$out_dir/experiment-record.json" <<EOF
{
  "id": "NIXOS-BUILD-$build_id",
  "status": "$overall",
  "distribution": "NixOS",
  "distribution_revision": "$nixpkgs_rev",
  "builder_environment": "see environment.txt",
  "environment": "Disposable Linux builder; see environment.txt",
  "os_revision": "nixpkgs $nixpkgs_rev",
  "package_revisions": [],
  "commands": ["nix flake metadata", "nix eval", "nix build"],
  "expected": "Evaluate and build one NixOS ISO from the committed flake lock",
  "actual": "$actual",
  "evidence": ["metadata.log", "build.log"],
  "limitations": ["Builder details and complete logs are stored alongside this record"],
  "logs": ["metadata.log", "build.log", "artifact-discovery.log", "checksum.log", "lock-revision.log", "environment.txt", "nix-version.txt", "git-commit.txt"$checksum_logs],
  "build_status": "$build",
  "artifact_status": "$artifact",
  "checksum_status": "$checksum",
  "evidence_complete": $complete,
  "build_stage": "$stage",
  "error": "$error"$relative_json$checksum_json$blocker_json
}
EOF
}
fail_blocked() {
  local message="$1"
  printf 'BLOCKED at %s: %s\n' "$stage" "$message" | tee -a "$out_dir/metadata.log" >&2
  write_record BLOCKED BLOCKED NOT\ TESTED NOT\ TESTED false "$message" "$message"
  exit 1
}
fail_failed() {
  local build="$1" artifact="$2" checksum="$3" complete="$4" message="$5"
  printf 'FAILED at %s: %s\n' "$stage" "$message" | tee -a "$out_dir/metadata.log" >&2
  write_record FAILED "$build" "$artifact" "$checksum" "$complete" "$message" "$message"
  exit 1
}

if ! command -v nix >/dev/null 2>&1; then fail_blocked 'Nix is unavailable'; fi
if ! command -v sha256sum >/dev/null 2>&1 || ! command -v sha512sum >/dev/null 2>&1; then
  fail_blocked 'SHA-256 and SHA-512 checksum tools are required'
fi
if [[ ${AETHER_NIXOS_DISPOSABLE:-0} != 1 ]]; then
  fail_blocked 'AETHER_NIXOS_DISPOSABLE=1 acknowledgement is required'
fi
if [[ $(uname -s) != Linux ]]; then fail_blocked 'NixOS ISO builds require Linux'; fi
if [[ ! -f experiments/nixos/flake.lock ]]; then fail_blocked 'experiments/nixos/flake.lock is missing'; fi
if [[ ${AETHER_PODMAN_BUILD:-0} == 1 && -f /.containerenv ]]; then
  printf 'Build environment: rootless Podman container; sandbox fallback disabled.\n' | tee -a "$out_dir/metadata.log"
elif ! command -v systemd-detect-virt >/dev/null 2>&1 || ! systemd-detect-virt --vm >/dev/null 2>&1; then
  fail_blocked 'no VM was detected; detection is only an additional safety check'
fi
printf 'nix_version=' > "$out_dir/nix-version.txt"
nix --version >> "$out_dir/nix-version.txt" 2>&1 || fail_blocked 'could not query Nix version'

stage=metadata
if ! nix --option sandbox true --option sandbox-fallback false --extra-experimental-features 'nix-command flakes' \
  flake metadata --no-write-lock-file --json ./experiments/nixos > "$out_dir/flake-metadata.json" 2> "$out_dir/metadata.log"; then
  fail_failed NOT\ TESTED NOT\ TESTED NOT\ TESTED false 'Nix flake metadata failed; see metadata.log'
fi
nixpkgs_rev=$(nix --option sandbox true --option sandbox-fallback false \
  --extra-experimental-features 'nix-command flakes' eval --raw --expr \
  '(builtins.fromJSON (builtins.readFile ./experiments/nixos/flake.lock)).nodes.nixpkgs.locked.rev' \
  2> "$out_dir/lock-revision.log") || {
  fail_failed NOT\ TESTED NOT\ TESTED NOT\ TESTED false 'could not extract the locked nixpkgs revision'
}
printf 'nixpkgs_rev=%s\n' "$nixpkgs_rev" > "$out_dir/locked-revisions.txt"

stage=evaluation
if ! nix --option sandbox true --option sandbox-fallback false --extra-experimental-features 'nix-command flakes' \
  eval --no-write-lock-file --raw ./experiments/nixos#nixosConfigurations.aether-iso.config.system.build.isoImage.drvPath \
  > "$out_dir/evaluation-result.txt" 2>> "$out_dir/metadata.log"; then
  fail_failed FAILED NOT\ TESTED NOT\ TESTED false 'Nix ISO configuration evaluation failed; see metadata.log'
fi

stage=build
if [[ -e $result_link || -L $result_link ]]; then
  fail_failed NOT\ TESTED FAILED NOT\ TESTED false 'refusing to overwrite an existing Nix result link'
fi
set +e
nix --option sandbox true --option sandbox-fallback false --extra-experimental-features 'nix-command flakes' \
  build --no-write-lock-file --print-build-logs --out-link "$result_link" ./experiments/nixos#nixos-iso \
  > "$out_dir/build.log" 2>&1
build_status=$?
set -e
cat "$out_dir/build.log"
printf 'exit_code=%s\n' "$build_status" > "$out_dir/build-result.txt"
if (( build_status != 0 )); then
  fail_failed FAILED NOT\ TESTED NOT\ TESTED false "Nix build exited $build_status; see build.log"
fi

stage=artifact-discovery
if ! artifact_info=$(bash scripts/experiments/find-nixos-iso.sh "$result_link" /nix/store 2> "$out_dir/artifact-discovery.log"); then
  cat "$out_dir/artifact-discovery.log" >&2
  fail_failed PASSED FAILED NOT\ TESTED false 'ISO artifact discovery failed; see artifact-discovery.log'
fi
iso=${artifact_info%%$'\t'*}
relative_iso=${artifact_info#*$'\t'}
artifact="$out_dir/$(basename "$iso")"
if ! cp -- "$iso" "$artifact"; then
  fail_failed PASSED FAILED NOT\ TESTED false 'copying the discovered ISO artifact failed'
fi
printf 'discovered_relative_path=%s\niso=%s\nbytes=%s\n' "$relative_iso" "$(basename "$artifact")" "$(stat -c '%s' "$artifact")" > "$out_dir/iso-metadata.txt"

stage=checksum
if ! sha256sum "$artifact" > "$out_dir/SHA256SUMS" 2> "$out_dir/checksum.log"; then
  fail_failed PASSED PASSED FAILED false 'SHA-256 generation failed'
fi
if ! sha512sum "$artifact" > "$out_dir/SHA512SUMS" 2>> "$out_dir/checksum.log"; then
  fail_failed PASSED PASSED FAILED false 'SHA-512 generation failed'
fi
printf 'sha256=%s\nsha512=%s\n' "$(cut -d ' ' -f 1 "$out_dir/SHA256SUMS")" \
  "$(cut -d ' ' -f 1 "$out_dir/SHA512SUMS")" >> "$out_dir/iso-metadata.txt"
iso_sha256=$(cut -d ' ' -f 1 "$out_dir/SHA256SUMS")

stage=metadata-generation
if ! cat > "$out_dir/metadata.txt" <<EOF
experiment_id=NIXOS-BUILD-$build_id
git_commit=$(cat "$out_dir/git-commit.txt")
builder=$(cat "$out_dir/environment.txt")
$(cat "$out_dir/nix-version.txt")
$(cat "$out_dir/locked-revisions.txt")
podman_version=${AETHER_PODMAN_VERSION:-not-applicable}
podman_image_digest=${AETHER_BUILDER_IMAGE_DIGEST:-not-applicable}
discovered_relative_iso=$relative_iso
evaluation=PASSED
build=PASSED
artifact=PASSED
checksums=PASSED
EOF
then
  fail_failed PASSED PASSED PASSED false 'metadata.txt generation failed'
fi
if ! write_record PASSED PASSED PASSED PASSED true 'Nix evaluation, build, artifact discovery, and checksums passed' 'none'; then
  printf 'FAILED: could not write experiment-record.json\n' > "$out_dir/metadata-generation-error.txt"
  echo "ERROR: metadata generation failed; evidence is retained in $out_dir" >&2
  exit 1
fi
printf 'Build evidence: %s\n' "$out_dir"
