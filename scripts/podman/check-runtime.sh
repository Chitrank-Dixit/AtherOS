#!/usr/bin/env bash
# Read-only Podman and host prerequisite diagnostics; never starts a machine.
set -uo pipefail

require_local_rootless=0
if [[ ${1:-} == --require-local-rootless ]]; then
  require_local_rootless=1
elif [[ $# -gt 0 ]]; then
  echo "Usage: $0 [--require-local-rootless]" >&2
  exit 2
fi
failed=0

if [[ -n ${CONTAINER_HOST:-} || -n ${CONTAINER_CONNECTION:-} ]]; then
  echo 'Podman target: remote override detected in CONTAINER_HOST or CONTAINER_CONNECTION.'
  echo 'BLOCKED: refusing diagnostics against an overridden Podman service.'
  exit "$require_local_rootless"
fi

if ! command -v podman >/dev/null 2>&1; then
  echo 'Podman CLI: unavailable'
  exit "$require_local_rootless"
fi
echo "Podman CLI: $(podman --version 2>&1 | head -n 1)"

podman_info_value() {
  local value
  if value=$(podman info --format "$1" 2>/dev/null); then
    if [[ -n $value && $value != '<no value>' ]]; then
      printf '%s' "$value"
    else
      printf 'unavailable'
    fi
  else
    printf 'unavailable'
  fi
}

rootless=$(podman_info_value '{{.Host.Security.Rootless}}')
remote=$(podman_info_value '{{.Host.ServiceIsRemote}}')
if [[ $rootless == unavailable || $remote == unavailable ]]; then
  echo 'Podman engine: unavailable or missing local/remote and rootless details' >&2
  exit "$require_local_rootless"
fi

if [[ $remote == true ]]; then
  printf 'Podman target: remote service (host=%s/%s)\n' \
    "$(podman_info_value '{{.Host.Os}}')" "$(podman_info_value '{{.Host.Arch}}')"
  echo 'BLOCKED: remote Podman is not accepted; no machine or connection will be modified.' >&2
  failed=1
elif [[ $remote == false ]]; then
  printf 'Podman target: local service (host=%s/%s)\n' \
    "$(podman_info_value '{{.Host.Os}}')" "$(podman_info_value '{{.Host.Arch}}')"
else
  printf 'Podman target: unknown (service_is_remote=%s)\n' "$remote"
  failed=1
fi

if [[ $rootless == true ]]; then
  echo 'Execution privilege: rootless'
elif [[ $rootless == false ]]; then
  echo 'Execution privilege: rootful'
  echo 'BLOCKED: rootful Podman is not accepted.' >&2
  failed=1
else
  printf 'Execution privilege: unknown (rootless=%s)\n' "$rootless"
  failed=1
fi

oci_runtime=$(podman_info_value '{{.Host.OCIRuntime.Name}}')
network_backend=$(podman_info_value '{{.Host.NetworkBackend}}')
storage_driver=$(podman_info_value '{{.Store.GraphDriverName}}')
graph_root=$(podman_info_value '{{.Store.GraphRoot}}')
printf 'OCI runtime: %s\nNetwork backend: %s\nStorage driver: %s\n' \
  "$oci_runtime" "$network_backend" "$storage_driver"
if [[ $remote == true ]]; then
  storage_fs='unavailable (remote graph root cannot be inspected locally)'
elif [[ $remote != false ]]; then
  storage_fs='unavailable (Podman target locality is unknown)'
elif [[ $graph_root != unavailable ]] && command -v stat >/dev/null 2>&1; then
  storage_fs=$(stat -f -c '%T' -- "$graph_root" 2>/dev/null || printf 'unavailable')
else
  storage_fs=unavailable
fi
printf 'Storage filesystem: %s\n' "$storage_fs"

if command -v findmnt >/dev/null 2>&1; then
  root_propagation=$(findmnt --noheadings --output PROPAGATION / 2>/dev/null | head -n 1)
else
  root_propagation=''
fi
printf 'Root mount propagation: %s\n' "${root_propagation:-unavailable}"

username=$(id -un 2>/dev/null || true)
uid=$(id -u 2>/dev/null || true)
for file in /etc/subuid /etc/subgid; do
  if [[ -r $file ]]; then
    range=$(awk -F: -v user="$username" -v uid="$uid" \
      '$1 == user || $1 == uid { print $2 ":" $3; found=1; exit } END { if (!found) exit 1 }' "$file" 2>/dev/null)
  else
    range=''
  fi
  if [[ -n $range ]]; then
    printf '%s: configured range %s\n' "$file" "$range"
  else
    printf '%s: MISSING or unreadable subordinate UID/GID range for current account\n' "$file"
    failed=1
  fi
done

if command -v unshare >/dev/null 2>&1 && unshare --user --map-root-user true >/dev/null 2>&1; then
  echo 'Prerequisite: host user namespace support passed (temporary namespace only).'
else
  echo 'Prerequisite: host user namespace support unavailable or blocked.' >&2
  failed=1
fi
if [[ $remote == false && $rootless == true ]]; then
  if podman unshare true >/dev/null 2>&1; then
    echo 'Prerequisite: Podman rootless user namespace passed.'
  else
    echo 'Prerequisite: Podman rootless user namespace unavailable or blocked.' >&2
    failed=1
  fi
else
  echo 'Prerequisite: Podman rootless user namespace NOT TESTED because the Podman target is not local and rootless.'
  failed=1
fi

echo 'Nested-container namespace operation: NOT TESTED by this diagnostic.'
echo 'The builder container probe is a separate runtime test and runs before each build.'
echo 'No containers, images, volumes, networks, machines, or connections were created or changed.'

if (( require_local_rootless )); then
  exit "$failed"
fi
exit 0
