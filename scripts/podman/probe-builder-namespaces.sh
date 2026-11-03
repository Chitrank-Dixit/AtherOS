#!/usr/bin/env bash
# Run inside a rootless container to check nested user and mount namespace support.
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/../.." && pwd)
# shellcheck source=scripts/podman/security-profile.sh
source "$repo_root/scripts/podman/security-profile.sh"
aether_probe_nested_namespaces /.containerenv
