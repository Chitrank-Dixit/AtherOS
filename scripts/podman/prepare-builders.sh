#!/usr/bin/env bash
# Separate image setup step: only pulls/builds images and never runs ISO builds.
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/../.." && pwd)
kind=${1:-}
archive_date=${2:-${AETHER_ARCHISO_REPO_SNAPSHOT:-}}
nix_image='ghcr.io/nixos/nix:2.35.4@sha256:05fe61395588e8a11452e9ba4602d4f0eb0ce5db8f7b9fa417c4ec07af79ca42'

if [[ $kind != arch && $kind != nixos ]]; then
  echo "Usage: $0 arch [YYYY/MM/DD] | nixos" >&2
  exit 2
fi
bash "$repo_root/scripts/podman/check-runtime.sh" --require-local-rootless

if [[ $kind == arch ]]; then
  if [[ ! $archive_date =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}$ ]]; then
    echo 'BLOCKED: pass a reviewed Arch Archive date as YYYY/MM/DD.' >&2; exit 2
  fi
  date_tag=${archive_date//\//-}
  image="localhost/aether-archiso-builder:$date_tag"
  if podman image exists "$image"; then
    existing_date=$(podman image inspect --format '{{ index .Labels "org.aether.archive-date" }}' "$image")
    if [[ $existing_date != "$archive_date" ]]; then
      echo "BLOCKED: existing image tag has unexpected snapshot label '$existing_date'; preserving it." >&2
      exit 1
    fi
    echo "Image already exists; preserving it without modification: $image"
    podman image inspect --format 'Image digest: {{.Digest}} | image ID: {{.Id}}' "$image"
    exit 0
  fi
  podman build --tag "$image" \
    --label org.aether.archive-date="$archive_date" \
    --build-arg "ARCHIVE_DATE=$archive_date" \
    --file "$repo_root/experiments/containers/archiso/Containerfile" \
    "$repo_root/experiments/containers/archiso"
  built_date=$(podman image inspect --format '{{ index .Labels "org.aether.archive-date" }}' "$image")
  if [[ $built_date != "$archive_date" ]]; then
    echo "ERROR: built image label '$built_date' did not match requested snapshot '$archive_date'." >&2
    exit 1
  fi
  podman image inspect --format 'Image digest: {{.Digest}} | image ID: {{.Id}}' "$image"
else
  if podman image exists "$nix_image"; then
    echo "Pinned Nix image already present: $nix_image"
  else
    podman pull "$nix_image"
  fi
  digest=$(podman image inspect --format '{{.Digest}}' "$nix_image")
  if [[ $digest != sha256:05fe61395588e8a11452e9ba4602d4f0eb0ce5db8f7b9fa417c4ec07af79ca42 ]]; then
    echo "BLOCKED: pulled image digest did not match the pinned reference ($digest)." >&2
    exit 1
  fi
  podman image inspect --format 'Image digest: {{.Digest}} | image ID: {{.Id}}' "$nix_image"
fi
