# Arch experiment

Status: **BLOCKED**; no Arch VM, ISO, or desktop session was available in the current environment. No experiment result is claimed.

## Intended environment

Disposable x86_64 UEFI Arch VM, systemd, network, and functional package manager. Build the ISO inside this disposable Arch Linux builder with `archiso`. The script requires `AETHER_ARCHISO_DISPOSABLE=1` and detects that it is running in a VM. Do not use the Windows host or a persistent host installation as the builder.

## Reproduction sequence

1. In an approved disposable Arch VM/builder, install the `archiso` package using the VM's package manager. Archiso can run as a regular user; package cache use may fall back to `/tmp`.
2. From a Linux checkout, run `make validate-arch`.
3. Run `AETHER_ARCHISO_DISPOSABLE=1 make build-arch-iso`; output is written under `out/arch/minimal` by default. To override, set `AETHER_ARCHISO_OUT` to a path in the disposable builder. The wrapper requires Linux, `/etc/arch-release`, a detected VM, and `mkarchiso`; it does not elevate privileges.
4. Boot the generated image in a disposable UEFI VM and record the firmware, image checksum, boot, networking, and install outcome.
5. Test GNOME, KDE Plasma, and Hyprland independently, including GDM/SDDM, desktop switching, and reboot.

This is a minimal bootable Archiso scaffold, not an installer or Aether desktop image. Package and service behavior remains unverified. Never mix a partial Arch upgrade into a valid test state; record the full update operation and package snapshot. See the [Archiso guide](https://wiki.archlinux.org/title/Archiso) for build behavior and options.

## Minimal and desktop profiles

`experiments/arch/iso/profile/` remains the minimal profile: `base`, `linux`, `linux-firmware`, and `networkmanager`. The separate `experiments/arch/iso/desktop-gnome/` profile adds the `gnome` package group, GDM, NetworkManager, PipeWire components, and GNOME portal integration. It is a package composition experiment only; installing these packages does not demonstrate successful login or session behavior.

To build the separate profile inside the disposable VM, run `AETHER_ARCHISO_DISPOSABLE=1 AETHER_ARCHISO_PROFILE=desktop-gnome make build-arch-iso`. Each profile writes its ISO and `SHA256SUMS`/`SHA512SUMS` files to its own ignored output directory. Record image path, checksum, package snapshot, and boot evidence in the experiment results.
