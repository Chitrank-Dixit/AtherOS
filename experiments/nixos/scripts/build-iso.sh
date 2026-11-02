#!/usr/bin/env bash
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/../../.." && pwd)
cd "$repo_root"

if ! command -v nix >/dev/null 2>&1; then
  echo 'BLOCKED: Nix is unavailable. Use a disposable Linux builder with Nix flakes enabled.' >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo 'BLOCKED: Python 3 is required to record locked flake metadata.' >&2
  exit 1
fi
if [[ ${AETHER_NIXOS_DISPOSABLE:-0} != 1 ]]; then
  echo 'BLOCKED: set AETHER_NIXOS_DISPOSABLE=1 only inside an explicitly disposable Linux builder.' >&2
  exit 1
fi
if [[ $(uname -s) != Linux ]]; then
  echo 'BLOCKED: NixOS ISO builds require a Linux builder.' >&2
  exit 1
fi
if [[ ! -f experiments/nixos/flake.lock ]]; then
  echo 'BLOCKED: experiments/nixos/flake.lock is missing. Run nix flake lock in the disposable builder, review and commit the lock, then retry.' >&2
  exit 1
fi
if [[ ${AETHER_PODMAN_BUILD:-0} == 1 && -f /.containerenv ]]; then
  echo 'Build environment: rootless Podman container; Nix sandbox fallback is disabled.'
elif ! command -v systemd-detect-virt >/dev/null 2>&1 || ! systemd-detect-virt --vm >/dev/null 2>&1; then
  echo 'BLOCKED: no VM was detected. A VM is an additional safety check, not proof of disposability.' >&2
  exit 1
fi
out_root=${AETHER_NIXOS_OUT:-"$repo_root/out/nixos"}
build_id=$(date -u +'%Y%m%dT%H%M%SZ')
out_dir="$out_root/$build_id"
result_link="/tmp/aether-nixos-result-$build_id"
if [[ -e $out_dir ]]; then
  echo "ERROR: refusing to reuse existing output directory: $out_dir" >&2
  exit 1
fi
if [[ -e $result_link || -L $result_link ]]; then
  echo "ERROR: refusing to overwrite existing Nix result link: $result_link" >&2
  exit 1
fi
mkdir -p "$out_dir"
git rev-parse HEAD > "$out_dir/git-commit.txt" 2>/dev/null || echo UNKNOWN > "$out_dir/git-commit.txt"
nix --version > "$out_dir/nix-version.txt" 2>&1
if ! nix --option sandbox true --option sandbox-fallback false --extra-experimental-features 'nix-command flakes' flake metadata --json ./experiments/nixos > "$out_dir/flake-metadata.json" 2> "$out_dir/metadata.log"; then
  printf 'flake_metadata=FAILED\nevaluation=NOT TESTED\nbuild=NOT TESTED\n' > "$out_dir/metadata.txt"
  cat "$out_dir/metadata.log" >&2
  exit 1
fi
if ! python3 - "$out_dir/flake-metadata.json" > "$out_dir/locked-revisions.txt" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as stream:
    metadata = json.load(stream)
locked = metadata["locks"]["nodes"]["nixpkgs"]["locked"]
print(f"nixpkgs_rev={locked.get('rev', 'UNKNOWN')}")
print(f"nixpkgs_last_modified={locked.get('lastModified', 'UNKNOWN')}")
PY
then
  printf 'flake_metadata=PASSED\nrevision_extraction=FAILED\nevaluation=NOT TESTED\nbuild=NOT TESTED\n' > "$out_dir/metadata.txt"
  exit 1
fi
if ! nix --option sandbox true --option sandbox-fallback false --extra-experimental-features 'nix-command flakes' eval --raw ./experiments/nixos#nixosConfigurations.aether-iso.config.system.build.isoImage.drvPath > "$out_dir/evaluation-result.txt" 2>> "$out_dir/metadata.log"; then
  {
    printf 'git_commit=%s\nbuilder=%s\narchitecture=%s\n' "$(cat "$out_dir/git-commit.txt")" "$(uname -srmo)" "$(uname -m)"
    cat "$out_dir/nix-version.txt" "$out_dir/locked-revisions.txt"
    printf 'podman_version=%s\npodman_image_digest=%s\nevaluation=FAILED\nbuild=NOT TESTED\n' "${AETHER_PODMAN_VERSION:-not-applicable}" "${AETHER_BUILDER_IMAGE_DIGEST:-not-applicable}"
    printf 'log=%s/metadata.log\n' "$out_dir"
  } > "$out_dir/metadata.txt"
  cat "$out_dir/metadata.log" >&2
  exit 1
fi
set +e
nix --option sandbox true --option sandbox-fallback false --extra-experimental-features 'nix-command flakes' build --print-build-logs --out-link "$result_link" ./experiments/nixos#nixos-iso > "$out_dir/build.log" 2>&1
build_status=$?
set -e
cat "$out_dir/build.log"
printf 'exit_code=%s\n' "$build_status" > "$out_dir/build-result.txt"
if (( build_status != 0 )); then
  {
    printf 'git_commit=%s\nbuilder=%s\narchitecture=%s\n' "$(cat "$out_dir/git-commit.txt")" "$(uname -srmo)" "$(uname -m)"
    cat "$out_dir/nix-version.txt" "$out_dir/locked-revisions.txt"
    printf 'podman_version=%s\npodman_image_digest=%s\nevaluation=PASSED\nbuild=FAILED\nexit_code=%s\nlog=%s/build.log\n' \
      "${AETHER_PODMAN_VERSION:-not-applicable}" "${AETHER_BUILDER_IMAGE_DIGEST:-not-applicable}" "$build_status" "$out_dir"
  } > "$out_dir/metadata.txt"
  echo "FAILED: Nix build exited with $build_status; see $out_dir/build.log" >&2
  exit "$build_status"
fi
iso=$(find -L "$result_link" -maxdepth 1 -type f -name '*.iso' -print -quit)
if [[ -z $iso ]]; then
  echo "ERROR: Nix output did not contain an ISO; inspect $result_link and build log." >&2
  exit 1
fi
artifact="$out_dir/$(basename "$iso")"
cp -- "$iso" "$artifact"
sha256sum "$artifact" > "$out_dir/SHA256SUMS"
sha512sum "$artifact" > "$out_dir/SHA512SUMS"
printf 'iso=%s\nbytes=%s\nsha256=%s\nsha512=%s\n' \
  "$(basename "$artifact")" "$(stat -c '%s' "$artifact")" \
  "$(cut -d ' ' -f 1 "$out_dir/SHA256SUMS")" "$(cut -d ' ' -f 1 "$out_dir/SHA512SUMS")" > "$out_dir/iso-metadata.txt"
{
  printf 'git_commit=%s\nbuilder=%s\narchitecture=%s\n' "$(cat "$out_dir/git-commit.txt")" "$(uname -srmo)" "$(uname -m)"
  cat "$out_dir/nix-version.txt" "$out_dir/locked-revisions.txt"
  printf 'podman_version=%s\npodman_image_digest=%s\n' "${AETHER_PODMAN_VERSION:-not-applicable}" "${AETHER_BUILDER_IMAGE_DIGEST:-not-applicable}"
  printf 'evaluation=PASSED\nbuild=PASSED\n'
} > "$out_dir/metadata.txt"
printf 'Build evidence: %s\n' "$out_dir"
