#!/usr/bin/env bash
# Read-only inventory of a Linux build host. This script never builds or installs.
set -uo pipefail

section() { printf '\n== %s ==\n' "$1"; }
check() {
  local name="$1"; shift
  if ! command -v "$name" >/dev/null 2>&1; then
    printf '%-20s unavailable\n' "$name"; return
  fi
  local line
  line=$("$@" 2>&1 | head -n 1) || line="available (version query failed)"
  printf '%-20s %s\n' "$name" "$line"
}

section 'Operating system'
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  printf 'Distribution: %s\nVersion: %s\n' "${PRETTY_NAME:-unknown}" "${VERSION_ID:-unknown}"
else
  printf 'Distribution metadata unavailable\n'
fi
printf 'Kernel: %s\nArchitecture: %s\n' "$(uname -sr 2>/dev/null || echo unavailable)" "$(uname -m 2>/dev/null || echo unavailable)"

section 'Resources'
if command -v free >/dev/null 2>&1; then free -h 2>&1 | head -n 2; else echo 'RAM: free command unavailable'; fi
df -h . 2>&1 | head -n 2

section 'Build tools (presence/version only)'
check pacman pacman --version
check mkarchiso mkarchiso -V
check nix nix --version
check git git --version
check python3 python3 --version
check shellcheck shellcheck --version
check qemu-system-x86_64 qemu-system-x86_64 --version

section 'Container runtimes (no daemon start)'
check podman podman --version
check docker docker --version
if command -v podman >/dev/null 2>&1; then podman info --format '{{.Host.Arch}}' 2>&1 | head -n 1 || true; fi
if command -v docker >/dev/null 2>&1; then docker info --format '{{.OSType}}/{{.Architecture}}' 2>&1 | head -n 1 || true; fi

section 'Virtualization and UEFI tooling'
if [[ -r /dev/kvm && -r /dev/vhost-net ]]; then echo 'KVM device: visible (not a safety or functionality proof)'
elif [[ -e /dev/kvm ]]; then echo 'KVM device: present but access not verified'
else echo 'KVM device: unavailable'; fi
if command -v systemd-detect-virt >/dev/null 2>&1; then systemd-detect-virt --vm 2>&1 || true; else echo 'VM detector: unavailable'; fi
for firmware in /usr/share/OVMF/OVMF_CODE.fd /usr/share/edk2-ovmf/x64/OVMF_CODE.fd /usr/share/qemu/OVMF.fd; do
  if [[ -r "$firmware" ]]; then printf 'UEFI firmware candidate: %s\n' "$firmware"; fi
done
echo 'This diagnostic does not establish that QEMU, KVM, or UEFI boot works.'
