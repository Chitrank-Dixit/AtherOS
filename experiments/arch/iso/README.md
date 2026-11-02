# Arch ISO profiles

The minimal profile at `profile/` and GNOME package experiment at `desktop-gnome/` are separate Archiso configurations. The default build always selects `minimal`; select the second explicitly with `AETHER_ARCHISO_PROFILE=desktop-gnome`.

| Profile | Packages | Purpose |
|---|---|---|
| `profile/` | `base`, `linux`, `linux-firmware`, `networkmanager` | Minimal boot and package-manager baseline |
| `desktop-gnome/` | Minimal baseline plus `gnome`, `gdm`, NetworkManager, PipeWire, and GNOME portal packages | GNOME package/session experiment; not evidence that login or desktop behavior works |

Build output is separated by profile under `out/arch/`. The build script records SHA-256 and SHA-512 checksums. Only run builds in disposable Arch VMs; do not build on the host.
