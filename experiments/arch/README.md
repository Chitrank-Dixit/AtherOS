# Arch experiment

Status: **BLOCKED**; no Arch VM, ISO, or desktop session was available in the current environment. No experiment result is claimed.

## Intended environment
Disposable x86_64 UEFI VM, systemd, network, and functional package manager. Build the ISO inside a disposable Arch Linux builder with `archiso`. Do not use the Windows host as the builder and do not build as root through this script.

## Reproduction sequence
1. In an approved disposable Arch VM/builder, install the `archiso` package using the VM's package manager. Archiso can run as a regular user; package cache use may fall back to `/tmp`.
2. From a Linux checkout, run `make validate-arch`.
3. Run `make build-arch-iso`; output is written under `out/arch` by default. To override, set `AETHER_ARCHISO_OUT` to a path in the disposable builder. The wrapper requires Linux, `/etc/arch-release`, and `mkarchiso`; it does not elevate privileges.
4. Boot the generated image in a disposable UEFI VM and record the firmware, image checksum, boot, networking, and install outcome.
5. Test GNOME, KDE Plasma, and Hyprland independently, including GDM/SDDM, desktop switching, and reboot.

This is a minimal bootable Archiso scaffold, not an installer or Aether desktop image. Package and service behavior remains unverified. Never mix a partial Arch upgrade into a valid test state; record the full update operation and package snapshot. See the [Archiso guide](https://wiki.archlinux.org/title/Archiso) for build behavior and options.
