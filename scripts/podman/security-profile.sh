#!/usr/bin/env bash
# Shared Podman security profiles and nested namespace probe helpers.

aether_podman_security_args() {
  local profile=$1
  local destination_name=$2
  local -n destination=$destination_name

  case "$profile" in
    standard)
      destination+=(--security-opt=no-new-privileges --cap-drop=ALL --network=none)
      ;;
    nested-namespace)
      # Keep Podman's default capability set. Do not add capabilities or disable
      # seccomp: supplied WSL2 experiments failed with --cap-drop=ALL and with
      # the tested SETUID/SETGID/SETPCAP additions.
      destination+=(--security-opt=no-new-privileges --network=bridge)
      ;;
    *)
      printf 'ERROR: unknown Podman security profile: %s\n' "$profile" >&2
      return 2
      ;;
  esac
}

aether_check_nested_namespace_prerequisites() {
  local container_marker=${1:-/.containerenv}
  if [[ ! -f $container_marker ]]; then
    echo 'BLOCKED: namespace-dependent profile must run inside a Podman container.' >&2
    return 1
  fi
  local tool
  for tool in unshare mount umount touch sh mktemp rmdir; do
    if ! command -v "$tool" >/dev/null 2>&1; then
      printf 'BLOCKED: namespace probe prerequisite is unavailable: %s\n' "$tool" >&2
      return 1
    fi
  done
  return 0
}

aether_require_no_sys_admin() {
  local status_file=${1:-/proc/self/status}
  local key value field_bit
  local seen_fields=0
  if [[ ! -r $status_file ]]; then
    printf 'BLOCKED: cannot inspect effective capabilities in %s.\n' "$status_file" >&2
    return 1
  fi
  while IFS=$' \t' read -r key value; do
    case "$key" in
      CapEff:) field_bit=1 ;;
      CapPrm:) field_bit=2 ;;
      CapInh:) field_bit=4 ;;
      CapBnd:) field_bit=8 ;;
      CapAmb:) field_bit=16 ;;
      *) continue ;;
    esac
    if [[ ! $value =~ ^[[:xdigit:]]+$ ]]; then
      printf 'BLOCKED: capability mask %s is missing or malformed.\n' "$key" >&2
      return 1
    fi
    seen_fields=$((seen_fields | field_bit))
    if (( (16#$value & 0x200000) != 0 )); then
      printf 'BLOCKED: CAP_SYS_ADMIN is present in %s inside the builder container.\n' "$key" >&2
      return 1
    fi
  done < "$status_file"
  if (( seen_fields != 31 )); then
    echo 'BLOCKED: capability status fields are incomplete; refusing the namespace-dependent profile.' >&2
    return 1
  fi
  return 0
}

aether_probe_nested_namespaces() {
  local container_marker=${1:-/.containerenv}
  aether_check_nested_namespace_prerequisites "$container_marker" || return
  aether_require_no_sys_admin || return

  local tmpdir
  tmpdir=$(mktemp -d /tmp/aether-ns-probe.XXXXXX) || {
    echo 'BLOCKED: could not create a temporary namespace probe directory.' >&2
    return 1
  }

  # SC2016: the quoted body is interpreted by the child shell inside unshare.
  # shellcheck disable=SC2016
  if ! unshare --user --map-root-user --mount sh -eu -c '
    mount -t tmpfs -o nosuid,nodev,noexec tmpfs "$1"
    touch "$1/probe"
    umount "$1"
  ' sh "$tmpdir"; then
    rmdir "$tmpdir" 2>/dev/null || true
    echo 'BLOCKED: nested user/mount namespace or private tmpfs probe failed.' >&2
    return 1
  fi

  rmdir "$tmpdir"
  echo 'Nested user namespace and private tmpfs mount probe passed.'
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
  if [[ $# -ne 1 ]]; then
    echo "Usage: $0 standard|nested-namespace" >&2
    exit 2
  fi
  profile_args=()
  aether_podman_security_args "$1" profile_args || exit $?
  printf '%s\n' "${profile_args[@]}"
fi
