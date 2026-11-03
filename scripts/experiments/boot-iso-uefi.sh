#!/usr/bin/env bash
# Boot a live ISO in QEMU/OVMF without attaching any virtual or physical disk.
set -euo pipefail

usage() {
  echo "Usage: AETHER_QEMU_DISPOSABLE=1 $0 ISO_PATH OVMF_CODE.fd OUTPUT_ROOT [MEMORY_MIB] [CPU_COUNT]" >&2
}
if [[ $# -lt 3 || $# -gt 5 ]]; then usage; exit 2; fi
for tool in realpath sha256sum; do
  if ! command -v "$tool" >/dev/null 2>&1; then echo "BLOCKED: required command $tool is unavailable." >&2; exit 1; fi
done
if [[ ! -f $1 || ! -f $2 ]]; then echo 'ERROR: ISO and OVMF firmware files must both exist.' >&2; exit 2; fi
iso=$(realpath "$1")
firmware=$(realpath "$2")
out_root=$(realpath -m "$3")
memory=${4:-4096}
cpus=${5:-2}

if [[ ${AETHER_QEMU_DISPOSABLE:-0} != 1 ]]; then
  echo 'BLOCKED: set AETHER_QEMU_DISPOSABLE=1 only in an explicitly disposable Linux VM.' >&2; exit 1
fi
if [[ $(uname -s) != Linux ]]; then echo 'BLOCKED: QEMU boot harness requires Linux.' >&2; exit 1; fi
if ! command -v systemd-detect-virt >/dev/null 2>&1 || ! systemd-detect-virt --vm >/dev/null 2>&1; then
  echo 'BLOCKED: no VM detected; detection is an additional check, not proof of disposability.' >&2; exit 1
fi
if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then echo 'BLOCKED: qemu-system-x86_64 is unavailable.' >&2; exit 1; fi
if [[ ! -f $iso || ! -r $iso || ! -f $firmware || ! -r $firmware ]]; then
  echo 'ERROR: ISO and readable OVMF firmware files are required.' >&2; exit 2
fi
if [[ ! $memory =~ ^[0-9]+$ || $memory -lt 1024 || ! $cpus =~ ^[0-9]+$ || $cpus -lt 1 ]]; then
  echo 'ERROR: memory must be >=1024 MiB and CPU count must be a positive integer.' >&2; exit 2
fi
if [[ -e $out_root ]]; then echo "ERROR: output root already exists; choose a new path: $out_root" >&2; exit 1; fi
mkdir -p "$out_root"
started=$(date -u +'%Y-%m-%dT%H:%M:%SZ')
iso_sha256=$(sha256sum "$iso" | cut -d ' ' -f 1)
firmware_sha256=$(sha256sum "$firmware" | cut -d ' ' -f 1)
qemu_version=$(qemu-system-x86_64 --version | head -n 1)
printf 'timestamp_utc=%s\niso=%s\niso_sha256=%s\nfirmware=%s\nfirmware_sha256=%s\nqemu=%s\nmemory_mib=%s\ncpu_count=%s\n' \
  "$started" "$iso" "$iso_sha256" "$firmware" "$firmware_sha256" "$qemu_version" "$memory" "$cpus" > "$out_root/metadata.txt"
printf 'command=qemu-system-x86_64 -machine q35,accel=tcg -cpu max -smp %s -m %s -drive pflash:readonly -cdrom %s -boot order=d -nic user -serial file:serial.log\n' \
  "$cpus" "$memory" "$iso" >> "$out_root/metadata.txt"
: > "$out_root/serial.log"

echo 'Starting a live ISO with no writable virtual disk attached. Close the VM window to finish.'
set +e
qemu-system-x86_64 \
  -machine q35,accel=tcg -cpu max -smp "$cpus" -m "$memory" \
  -drive "if=pflash,format=raw,readonly=on,file=$firmware" \
  -cdrom "$iso" -boot order=d,menu=on -nic user,model=virtio-net-pci \
  -serial "file:$out_root/serial.log" -monitor none \
  -display gtk > "$out_root/qemu.log" 2>&1
result=$?
set -e
printf 'qemu_exit_code=%s\n' "$result" >> "$out_root/metadata.txt"
cat "$out_root/qemu.log"
cat > "$out_root/experiment-record.json" <<EOF
{
  "id": "UEFI-$started",
  "status": "NOT TESTED",
  "environment": "Disposable Linux VM; see metadata.txt",
  "distribution": "unknown; identify from ISO before recording final outcome",
  "os_revision": "ISO SHA-256 $iso_sha256",
  "package_revisions": [],
  "commands": ["scripts/experiments/boot-iso-uefi.sh ISO_PATH OVMF_CODE.fd OUTPUT_ROOT MEMORY_MIB CPU_COUNT"],
  "expected": "Boot ISO in UEFI and observe live environment milestones",
  "actual": "QEMU exited with status $result; guest boot milestones require human verification",
  "evidence": ["metadata.txt", "qemu.log", "serial.log"],
  "limitations": ["QEMU process exit is not guest boot evidence; operator must record each milestone"],
  "logs": ["metadata.txt", "qemu.log", "serial.log"],
  "iso_sha256": "$iso_sha256",
  "boot_status": "NOT TESTED",
  "vm_configuration": {
    "hypervisor": "QEMU TCG",
    "architecture": "x86_64",
    "cpu_count": $cpus,
    "memory_mib": $memory,
    "firmware": "$firmware_sha256"
  },
  "boot_milestones": {
    "uefi_firmware_initialized": "NOT TESTED",
    "bootloader_displayed": "NOT TESTED",
    "kernel_booted": "NOT TESTED",
    "live_environment_reached": "NOT TESTED",
    "shell_available": "NOT TESTED",
    "network_available": "NOT TESTED"
  }
}
EOF
printf 'Evidence directory: %s\n' "$out_root"
exit "$result"
