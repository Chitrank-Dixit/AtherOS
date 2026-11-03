# Disposable UEFI boot testing

## Prerequisites

Use a disposable Linux VM with QEMU x86_64 and OVMF/UEFI firmware already available, and enough RAM and CPU for the ISO. Do not install or enable virtualization software as part of a test run. Confirm that the ISO and its checksum match the build manifest.

## Safety

Booting a live ISO needs no writable virtual disk. Never attach physical disks, host EFI partitions, or persistent VM disks. Installer testing that needs a disk is separate and requires explicit confirmation for creation of a new disposable virtual disk. VM detection is not proof that a machine is disposable. The harness must require the `AETHER_QEMU_DISPOSABLE=1` acknowledgement and refuse existing disk paths.

## Boot evidence

The repository harness performs a live ISO boot with no writable disk. Run it only from an explicitly disposable Linux VM, using an existing OVMF code image and a new evidence directory:

```bash
export AETHER_QEMU_DISPOSABLE=1
scripts/experiments/boot-iso-uefi.sh /path/to/image.iso /path/to/OVMF_CODE.fd /path/to/new-evidence-dir 4096 2
```

The harness uses QEMU TCG, records its version, firmware and ISO SHA-256 digests, VM resources, serial output, and QEMU log. QEMU's process exit status only describes QEMU itself and never sets boot status. After QEMU exits, the harness writes an experiment record with all guest milestones set to `NOT TESTED`; operators must update them from direct observations. GTK display support is required to view the graphical bootloader. QEMU's user-mode network is attached for basic guest network checks.

For each distribution, record the QEMU version and command, firmware file/version or checksum, VM CPU and memory allocation, ISO SHA-256, UTC timestamp, serial/boot log, and observations for:

1. UEFI firmware initialized.
2. Bootloader displayed.
3. Kernel booted.
4. Live environment reached.
5. Shell or login access available.
6. Networking available where expected.

Use `PASSED`, `FAILED`, `BLOCKED`, or `NOT TESTED` for each key in `boot_milestones`. The accepted keys are `uefi_firmware_initialized`, `bootloader_displayed`, `kernel_booted`, `live_environment_reached`, `shell_available`, and `network_available`. A boot status of `PASSED` requires direct evidence for the milestones required by that experiment; the harness does not set it automatically.

A live shell result is not desktop-session evidence. Virtual graphics are not physical NVIDIA compatibility evidence. Record each unchecked item as NOT TESTED and a missing required capability as BLOCKED.

## Cleanup and troubleshooting

The initial live boot uses no disk. Retain logs and screenshots with the experiment record. If a disposable disk was separately authorized, power off the VM and verify its exact path before manual cleanup. Missing QEMU, firmware, or safe VM capability is a blocker; do not change host settings to work around it.
