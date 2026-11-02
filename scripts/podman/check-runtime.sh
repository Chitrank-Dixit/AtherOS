#!/usr/bin/env bash
# Read-only diagnostics. Does not start a Podman machine or create resources.
set -uo pipefail

require_local_rootless=0
[[ ${1:-} == --require-local-rootless ]] && require_local_rootless=1
failed=0

if ! command -v podman >/dev/null 2>&1; then
  echo 'Podman: unavailable'
  exit "$((require_local_rootless))"
fi
echo "Podman: $(podman --version 2>&1 | head -n 1)"

info=$(podman info --format '{{.Host.Security.Rootless}}|{{.Host.ServiceIsRemote}}|{{.Host.Os}}|{{.Host.Arch}}' 2>&1)
info_status=$?
if (( info_status != 0 )); then
  printf 'Podman engine: unavailable (%s)\n' "$info"
  exit "$((require_local_rootless))"
fi
IFS='|' read -r rootless remote host_os host_arch <<< "$info"
printf 'Rootless: %s\nRemote service: %s\nRuntime host: %s/%s\n' "$rootless" "$remote" "$host_os" "$host_arch"

if [[ $rootless != true ]]; then echo 'BLOCKED: Podman is not rootless.' >&2; failed=1; fi
if [[ $remote != false ]]; then echo 'BLOCKED: Podman targets a remote service; no remote machine/connection will be modified.' >&2; failed=1; fi
if [[ -n ${CONTAINER_HOST:-} || -n ${CONTAINER_CONNECTION:-} ]]; then
  echo 'BLOCKED: a Podman remote override is set in the environment.' >&2; failed=1
fi

username=$(id -un 2>/dev/null || true)
uid=$(id -u 2>/dev/null || true)
for file in /etc/subuid /etc/subgid; do
  if [[ -r $file ]] && awk -F: -v user="$username" -v uid="$uid" '$1 == user || $1 == uid { found=1 } END { exit !found }' "$file"; then
    printf '%s: subordinate ID range found for current account\n' "$file"
  else
    printf '%s: subordinate ID range unavailable or unreadable\n' "$file"
    failed=1
  fi
done

if command -v unshare >/dev/null 2>&1 && unshare --user --map-root-user true >/dev/null 2>&1; then
  echo 'Kernel user namespace probe: passed (disposable namespace only)'
else
  echo 'Kernel user namespace probe: unavailable or blocked'
  failed=1
fi
if command -v podman >/dev/null 2>&1 && podman unshare true >/dev/null 2>&1; then
  echo 'Podman rootless user namespace probe: passed'
else
  echo 'Podman rootless user namespace probe: unavailable or blocked'
  failed=1
fi
echo 'This check does not create containers, images, volumes, networks, machines, or connections.'
echo 'Build scripts also probe nested namespaces from inside each builder container.'
if (( require_local_rootless )); then exit "$failed"; fi
exit 0
