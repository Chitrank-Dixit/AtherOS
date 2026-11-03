#!/usr/bin/env bash
# Separate image setup step: only pulls/builds images and never runs ISO builds.
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/../.." && pwd)
kind=${1:-}
archive_date=${2:-${AETHER_ARCHISO_REPO_SNAPSHOT:-}}
arch_base_image=${3:-${AETHER_ARCH_BASE_IMAGE_REF:-}}
nix_base_image='ghcr.io/nixos/nix:2.35.4@sha256:05fe61395588e8a11452e9ba4602d4f0eb0ce5db8f7b9fa417c4ec07af79ca42'
nix_builder_image='localhost/aether-nixos-builder:2.35.4'

if [[ $kind != arch && $kind != nixos ]]; then
  echo "Usage: $0 arch YYYY/MM/DD archlinux/archlinux:<dated-tag>@sha256:<digest> | nixos" >&2
  exit 2
fi
bash "$repo_root/scripts/podman/check-runtime.sh" --require-local-rootless

if [[ $kind == arch ]]; then
  if [[ ! $archive_date =~ ^[0-9]{4}/[0-9]{2}/[0-9]{2}$ ]]; then
    echo 'BLOCKED: pass a reviewed Arch Archive date as YYYY/MM/DD.' >&2; exit 2
  fi
  if ! python3 "$repo_root/scripts/experiments/arch_snapshot.py" "$archive_date" "$arch_base_image"; then
    echo 'BLOCKED: Arch builder requires a valid snapshot and matching official digest-pinned base image.' >&2
    exit 2
  fi
  date_tag=${archive_date//\//-}
  image="localhost/aether-archiso-builder:$date_tag"
  if podman image exists "$image"; then
    existing_date=$(podman image inspect --format '{{ index .Labels "org.aether.archive-date" }}' "$image")
    existing_base=$(podman image inspect --format '{{ index .Labels "org.aether.base-image" }}' "$image")
    if [[ $existing_date != "$archive_date" || $existing_base != "$arch_base_image" ]]; then
      echo "BLOCKED: existing image has unexpected snapshot/base labels; preserving it." >&2
      exit 1
    fi
    echo "Image already exists; preserving it without modification: $image"
    podman image inspect --format 'Image digest: {{.Digest}} | image ID: {{.Id}}' "$image"
    exit 0
  fi
  podman build --tag "$image" \
    --label org.aether.archive-date="$archive_date" \
    --label org.aether.base-image="$arch_base_image" \
    --build-arg "ARCH_BASE_IMAGE=$arch_base_image" \
    --build-arg "ARCHIVE_DATE=$archive_date" \
    --file "$repo_root/experiments/containers/archiso/Containerfile" \
    "$repo_root/experiments/containers/archiso"
  built_date=$(podman image inspect --format '{{ index .Labels "org.aether.archive-date" }}' "$image")
  built_base=$(podman image inspect --format '{{ index .Labels "org.aether.base-image" }}' "$image")
  if [[ $built_date != "$archive_date" || $built_base != "$arch_base_image" ]]; then
    echo 'ERROR: built image snapshot/base labels do not match the requested immutable inputs.' >&2
    exit 1
  fi
  podman image inspect --format 'Image digest: {{.Digest}} | image ID: {{.Id}}' "$image"
else
  if podman image exists "$nix_base_image"; then
    echo "Pinned Nix base image already present: $nix_base_image"
  else
    podman pull "$nix_base_image"
  fi
  digest=$(podman image inspect --format '{{.Digest}}' "$nix_base_image")
  if [[ $digest != sha256:05fe61395588e8a11452e9ba4602d4f0eb0ce5db8f7b9fa417c4ec07af79ca42 ]]; then
    echo "BLOCKED: pulled image digest did not match the pinned reference ($digest)." >&2
    exit 1
  fi
  if podman image exists "$nix_builder_image"; then
    existing_base=$(podman image inspect --format '{{ index .Labels "org.aether.base-image" }}' "$nix_builder_image")
    existing_schema=$(podman image inspect --format '{{ index .Labels "org.aether.jsonschema-version" }}' "$nix_builder_image")
    if [[ $existing_base != "$nix_base_image" || $existing_schema != '4.26.0' ]]; then
      echo "BLOCKED: existing Nix builder has unexpected provenance labels; preserving it: $nix_builder_image" >&2
      exit 1
    fi
    echo "Nix builder already exists; preserving it without modification: $nix_builder_image"
  else
    podman build --pull=never --tag "$nix_builder_image" \
      --build-arg "NIX_BASE_IMAGE=$nix_base_image" \
      --file "$repo_root/experiments/containers/nixos/Containerfile" \
      "$repo_root/experiments/containers/nixos"
  fi
  built_base=$(podman image inspect --format '{{ index .Labels "org.aether.base-image" }}' "$nix_builder_image")
  built_schema=$(podman image inspect --format '{{ index .Labels "org.aether.jsonschema-version" }}' "$nix_builder_image")
  if [[ $built_base != "$nix_base_image" || $built_schema != '4.26.0' ]]; then
    echo 'BLOCKED: prepared Nix builder provenance or JSON Schema dependency is incorrect.' >&2
    exit 1
  fi
  podman image inspect --format 'Image digest: {{.Digest}} | image ID: {{.Id}}' "$nix_builder_image"
fi
