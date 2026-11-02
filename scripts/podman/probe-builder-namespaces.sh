#!/usr/bin/env bash
# Run inside a rootless container to check nested user and mount namespace support.
set -euo pipefail

if [[ ! -f /.containerenv ]]; then
  echo 'BLOCKED: expected to run inside a Podman container.' >&2
  exit 1
fi
tmpdir=$(mktemp -d /tmp/aether-ns-probe.XXXXXX)
trap 'rmdir "$tmpdir" 2>/dev/null || true' EXIT
unshare --user --map-root-user --mount sh -eu -c '
  mount -t tmpfs -o nosuid,nodev,noexec tmpfs "$1"
  touch "$1/probe"
  umount "$1"
' sh "$tmpdir"
echo 'Nested user namespace and private tmpfs mount probe passed.'
