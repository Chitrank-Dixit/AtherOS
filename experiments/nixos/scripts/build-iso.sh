#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/../../.." && pwd)
cd "$repo_root"

out_root=${AETHER_NIXOS_OUT:-"$repo_root/out/nixos"}
build_id="$(date -u +'%Y%m%dT%H%M%SZ')-$$"
out_dir="$out_root/$build_id"
result_link="/tmp/aether-nixos-result-$build_id"
result_link_identity=''
result_link_owned=false
build_invoked=false
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
printf -v stage '%s' 'prerequisite'
cleanup_result_link() {
  local cleanup_status=0
  if [[ $build_invoked == true && $result_link_owned == false && -L $result_link ]]; then
    if result_link_identity=$(python3 scripts/experiments/nixos_result_link.py identity "$result_link"); then
      result_link_owned=true
    else
      printf 'ERROR: could not identify invocation result link %s; leaving it untouched\n' \
        "$result_link" >&2
      printf 'result_link_cleanup=NOT TESTED (identity unavailable)\n' >> "$out_dir/metadata.log"
      return 1
    fi
  fi
  if [[ $result_link_owned == true && -n $result_link_identity ]]; then
    if ! python3 scripts/experiments/nixos_result_link.py cleanup "$result_link" "$result_link_identity"; then
      printf 'ERROR: could not safely clean up owned result link %s\n' "$result_link" >&2
      printf 'result_link_cleanup=FAILED\n' >> "$out_dir/metadata.log"
      cleanup_status=1
    else
      printf 'result_link_cleanup=PASSED\n' >> "$out_dir/metadata.log"
    fi
  fi
  return "$cleanup_status"
}
trap cleanup_result_link EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
write_record() {
  python3 scripts/experiments/nixos_record.py "$out_dir/experiment-record.json" \
    schemas/experiment-record.schema.json "NIXOS-BUILD-$build_id" "$1" "$2" "$3" "$4" \
    "$5" "$stage" "$nixpkgs_rev" "$6" "$7" "${relative_iso:-}" "${iso_sha256:-}"
}
fail_blocked() {
  local message="$1"
  printf 'BLOCKED at %s: %s\n' "$stage" "$message" | tee -a "$out_dir/metadata.log" >&2
  if ! write_record BLOCKED BLOCKED NOT\ TESTED NOT\ TESTED false "$message" "$message"; then
    printf 'stage=%s\nstatus=FAILED\nerror=validated record generation failed for BLOCKED outcome\n' \
      "$stage" > "$out_dir/metadata-generation-error.txt"
    echo "ERROR: could not generate validated experiment record; evidence retained at $out_dir" >&2
  fi
  exit 1
}
fail_failed() {
  local build="$1" artifact="$2" checksum="$3" complete="$4" message="$5"
  printf 'FAILED at %s: %s\n' "$stage" "$message" | tee -a "$out_dir/metadata.log" >&2
  if ! write_record FAILED "$build" "$artifact" "$checksum" "$complete" "$message" "$message"; then
    printf 'stage=%s\nstatus=FAILED\nerror=validated record generation failed for FAILED outcome\n' \
      "$stage" > "$out_dir/metadata-generation-error.txt"
    echo "ERROR: could not generate validated experiment record; evidence retained at $out_dir" >&2
  fi
  exit 1
}

if ! command -v nix >/dev/null 2>&1; then fail_blocked 'Nix is unavailable'; fi
if ! command -v python3 >/dev/null 2>&1 || ! python3 -c 'import jsonschema' >/dev/null 2>&1; then
  fail_blocked 'Python 3 and the pinned jsonschema development dependency are required for validated experiment records'
fi
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

printf -v stage '%s' 'metadata'
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

printf -v stage '%s' 'evaluation'
if ! nix --option sandbox true --option sandbox-fallback false --extra-experimental-features 'nix-command flakes' \
  eval --no-write-lock-file --raw ./experiments/nixos#nixosConfigurations.aether-iso.config.system.build.isoImage.drvPath \
  > "$out_dir/evaluation-result.txt" 2>> "$out_dir/metadata.log"; then
  fail_failed FAILED NOT\ TESTED NOT\ TESTED false 'Nix ISO configuration evaluation failed; see metadata.log'
fi

printf -v stage '%s' 'build'
if [[ -e $result_link || -L $result_link ]]; then
  fail_failed NOT\ TESTED FAILED NOT\ TESTED false 'refusing to overwrite an existing Nix result link'
fi
build_invoked=true
set +e
nix --option sandbox true --option sandbox-fallback false --extra-experimental-features 'nix-command flakes' \
  build --no-write-lock-file --print-build-logs --out-link "$result_link" ./experiments/nixos#nixos-iso \
  > "$out_dir/build.log" 2>&1
build_status=$?
set -e
cat "$out_dir/build.log"
printf 'exit_code=%s\n' "$build_status" > "$out_dir/build-result.txt"
if [[ -L $result_link ]]; then
  if result_link_identity=$(python3 scripts/experiments/nixos_result_link.py identity "$result_link"); then
    result_link_owned=true
  else
    fail_failed NOT\ TESTED NOT\ TESTED NOT\ TESTED false 'could not verify ownership of the Nix result link'
  fi
fi
if (( build_status != 0 )); then
  fail_failed FAILED NOT\ TESTED NOT\ TESTED false "Nix build exited $build_status; see build.log"
fi

printf -v stage '%s' 'artifact-discovery'
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
if ! cleanup_result_link; then
  fail_failed PASSED PASSED NOT\ TESTED false 'Nix result link cleanup failed; see metadata.log'
fi
result_link_owned=false
printf 'discovered_relative_path=%s\niso=%s\nbytes=%s\n' "$relative_iso" "$(basename "$artifact")" "$(stat -c '%s' "$artifact")" > "$out_dir/iso-metadata.txt"

printf -v stage '%s' 'checksum'
if ! sha256sum "$artifact" > "$out_dir/SHA256SUMS" 2> "$out_dir/checksum.log"; then
  fail_failed PASSED PASSED FAILED false 'SHA-256 generation failed'
fi
if ! sha512sum "$artifact" > "$out_dir/SHA512SUMS" 2>> "$out_dir/checksum.log"; then
  fail_failed PASSED PASSED FAILED false 'SHA-512 generation failed'
fi
printf 'sha256=%s\nsha512=%s\n' "$(cut -d ' ' -f 1 "$out_dir/SHA256SUMS")" \
  "$(cut -d ' ' -f 1 "$out_dir/SHA512SUMS")" >> "$out_dir/iso-metadata.txt"
iso_sha256=$(cut -d ' ' -f 1 "$out_dir/SHA256SUMS")

printf -v stage '%s' 'metadata-generation'
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
