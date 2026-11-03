# Arch experiment

Status: **BLOCKED**; no Arch VM, ISO, or desktop session was available in the current environment. No experiment result is claimed.

## Intended environment

Disposable x86_64 UEFI Arch VM, systemd, network, and functional package manager. Build the ISO inside this disposable Arch Linux builder with `archiso`. The script requires `AETHER_ARCHISO_DISPOSABLE=1` and detects that it is running in a VM. Do not use the Windows host or a persistent host installation as the builder.

## Reproduction sequence

1. In an approved disposable Arch VM/builder, install the `archiso` package using the VM's package manager. Archiso can run as a regular user; package cache use may fall back to `/tmp`.
2. From a Linux checkout, run `make validate-arch`.
3. In the disposable VM, set `AETHER_ARCHISO_DISPOSABLE=1` and choose an explicit Arch Linux Archive snapshot with `AETHER_ARCHISO_REPO_SNAPSHOT=YYYY/MM/DD`. Run `experiments/arch/scripts/build-iso.sh minimal` or `experiments/arch/scripts/build-iso.sh desktop-gnome`. Outputs are kept under profile-specific, timestamped directories within `out/arch/`. The wrapper requires Linux, `/etc/arch-release`, a detected VM, and `mkarchiso`; it does not elevate privileges.
4. Boot the generated image in a disposable UEFI VM and record the firmware, image checksum, boot, networking, and install outcome.
5. Test GNOME, KDE Plasma, and Hyprland independently, including GDM/SDDM, desktop switching, and reboot.

This is a minimal bootable Archiso scaffold, not an installer or Aether desktop image. Package and service behavior remains unverified. Never mix a partial Arch upgrade into a valid test state; record the full update operation and package snapshot. See the [Archiso guide](https://wiki.archlinux.org/title/Archiso) for build behavior and options.

## Minimal and desktop profiles

`experiments/arch/iso/profile/` remains the minimal profile: `base`, `linux`, `linux-firmware`, and `networkmanager`. The separate `experiments/arch/iso/desktop-gnome/` profile adds the `gnome` package group, GDM, NetworkManager, PipeWire components, and GNOME portal integration. It is a package composition experiment only; installing these packages does not demonstrate successful login or session behavior.

To build the separate profile inside the disposable VM, use `experiments/arch/scripts/build-iso.sh desktop-gnome` after setting both required environment variables. Each profile writes its ISO, complete build log, tool/build inputs, and `SHA256SUMS`/`SHA512SUMS` files to its own ignored output tree. Record package versions and boot evidence in the experiment results. Snapshot pinning is an input record, not a claim of bit-for-bit reproducibility.
