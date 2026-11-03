#!/usr/bin/env bash
# Run one build in a rootless Podman container; source is RO and artifacts RW.
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/../.." && pwd)
kind=${1:-}
profile=${2:-minimal}
archive_date=${AETHER_ARCHISO_REPO_SNAPSHOT:-}
nix_image='ghcr.io/nixos/nix:2.35.4@sha256:05fe61395588e8a11452e9ba4602d4f0eb0ce5db8f7b9fa417c4ec07af79ca42'

if [[ $kind != arch && $kind != nixos ]]; then
  echo "Usage: AETHER_PODMAN_DISPOSABLE=1 $0 arch [minimal|desktop-gnome] | nixos" >&2
  exit 2
fi
if [[ ${AETHER_PODMAN_DISPOSABLE:-0} != 1 ]]; then
  echo 'BLOCKED: set AETHER_PODMAN_DISPOSABLE=1 only after designating the local rootless Podman builder disposable.' >&2
  exit 1
fi
bash "$repo_root/scripts/podman/check-runtime.sh" --require-local-rootless

if [[ $kind == arch ]]; then
  if [[ $profile != minimal && $profile != desktop-gnome ]]; then echo 'ERROR: unsupported Arch profile.' >&2; exit 2; fi
  if [[ ! $archive_date =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}$ ]]; then
    echo 'BLOCKED: set AETHER_ARCHISO_REPO_SNAPSHOT to YYYY/MM/DD.' >&2; exit 2
  fi
  image="localhost/aether-archiso-builder:${archive_date//\//-}"
  command=(bash /workspace/experiments/arch/scripts/build-iso.sh "$profile")
else
  if [[ ! -f $repo_root/experiments/nixos/flake.lock ]]; then
    echo 'BLOCKED: Nix flake.lock is missing; no container image will be run.' >&2; exit 1
  fi
  image=$nix_image
  command=(bash /workspace/experiments/nixos/scripts/build-iso.sh)
fi
if ! podman image exists "$image"; then
  echo "BLOCKED: required builder image is not prepared: $image" >&2
  echo "Run scripts/podman/prepare-builders.sh $kind first; this build command does not pull or build images." >&2
  exit 1
fi
if [[ $kind == arch ]]; then
  image_date=$(podman image inspect --format '{{ index .Labels "org.aether.archive-date" }}' "$image")
  image_base=$(podman image inspect --format '{{ index .Labels "org.aether.base-image" }}' "$image")
  if [[ $image_date != "$archive_date" ]]; then
    echo "BLOCKED: Arch builder image snapshot label mismatch ($image_date != $archive_date)." >&2; exit 1
  fi
  if ! python3 "$repo_root/scripts/experiments/arch_snapshot.py" "$archive_date" "$image_base" >/dev/null; then
    echo 'BLOCKED: Arch builder base image label is not a matching digest-pinned reference.' >&2; exit 1
  fi
fi
image_digest=$(podman image inspect --format '{{.Digest}}' "$image")
image_id=$(podman image inspect --format '{{.Id}}' "$image")
if [[ ! $image_digest =~ ^sha256:[0-9a-f]{64}$ ]]; then
  echo "BLOCKED: Podman did not report a valid OCI image digest for $image." >&2; exit 1
fi
podman_version=$(podman --version)
base_image_digest=not-applicable
if [[ ${image_base:-} =~ @sha256:([a-f0-9]{64})$ ]]; then
  base_image_digest="sha256:${BASH_REMATCH[1]}"
fi
remote=$(podman info --format '{{.Host.ServiceIsRemote}}')
rootless=$(podman info --format '{{.Host.Security.Rootless}}')
if [[ $remote != false || $rootless != true ]]; then
  echo "BLOCKED: expected local rootless Podman (remote=$remote rootless=$rootless)." >&2; exit 1
fi

build_id=$(date -u +'%Y%m%dT%H%M%SZ')
out_dir="$repo_root/out/podman/$kind/$build_id"
if [[ -e $out_dir ]]; then echo "ERROR: refusing to reuse output path $out_dir" >&2; exit 1; fi
mkdir -p "$out_dir"
cat > "$out_dir/podman-metadata.txt" <<EOF
builder=$kind
podman_version=$podman_version
podman_rootless=$rootless
podman_remote=$remote
container_image=$image
container_image_digest=$image_digest
container_image_id=$image_id
archive_snapshot=${archive_date:-not-applicable}
base_image_ref=${image_base:-not-applicable}
base_image_digest=$base_image_digest
source_mount=read-only
artifact_mount=read-write
container_privileged=false
extra_capabilities=none
host_podman_socket=not-mounted
EOF

run_args=(run --rm --pull=never --security-opt=no-new-privileges --cap-drop=ALL
  --volume "$repo_root:/workspace:ro" --volume "$out_dir:/out:rw"
  --workdir /workspace --entrypoint bash --env AETHER_PODMAN_BUILD=1
  --env AETHER_BUILDER_IMAGE_DIGEST="$image_digest" --env AETHER_PODMAN_VERSION="$podman_version"
  --env AETHER_ARCHISO_DISPOSABLE=1 --env AETHER_NIXOS_DISPOSABLE=1
  --env AETHER_ARCHISO_REPO_SNAPSHOT="$archive_date"
  --env AETHER_ARCH_BASE_IMAGE_REF="${image_base:-not-applicable}"
  --env AETHER_ARCHISO_OUT=/out --env AETHER_NIXOS_OUT=/out)
if [[ $kind == arch ]]; then
  # SC2016 is intentional: the child bash expands "$1" after Podman starts it.
  # shellcheck disable=SC2016
  command=(-c 'bash /workspace/scripts/podman/probe-builder-namespaces.sh && bash /workspace/experiments/arch/scripts/build-iso.sh "$1"' _ "$profile")
else
  # Evaluation is not a build. The existing build script runs only after this sandbox gate succeeds.
  # SC2016 is intentional: this whole string is the script for the container's bash process.
  # shellcheck disable=SC2016
  command=(-c 'nix --option sandbox true --option sandbox-fallback false --extra-experimental-features "nix-command flakes" eval --no-write-lock-file --raw ./experiments/nixos#nixosConfigurations.aether-iso.config.system.build.isoImage.drvPath && bash /workspace/scripts/podman/probe-builder-namespaces.sh && bash /workspace/experiments/nixos/scripts/build-iso.sh')
fi
set +e
podman "${run_args[@]}" "$image" "${command[@]}" 2>&1 | tee "$out_dir/podman-run.log"
status=${PIPESTATUS[0]}
set -e
printf 'container_exit_code=%s\n' "$status" > "$out_dir/container-result.txt"
printf 'Builder evidence: %s\n' "$out_dir"
exit "$status"
