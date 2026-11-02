# NixOS experiment

Status: **BLOCKED**; Nix was not available in the current environment and no NixOS VM/ISO was built or booted.

## Reproduction sequence

1. Use a disposable Linux builder with Nix and flakes enabled; do not modify host WSL or Windows configuration to obtain it.
2. From the repository root, run `make validate-nixos`.
3. Run `nix flake lock ./experiments/nixos` to resolve the input, then review and commit `experiments/nixos/flake.lock`; record the resulting nixpkgs revision.
4. In the explicitly disposable VM, set `AETHER_NIXOS_DISPOSABLE=1` and run `make build-nixos-iso`. The target requires a detected VM and the reviewed lock, records flake metadata and Nix version, separates evaluation from build, retains logs, and writes checksums.
5. Record artifact checksum, UEFI boot, clean VM boot, network access, configuration changes, generation activation, and rollback evidence.

The flake exposes minimal, GNOME, Plasma, Hyprland, and developer-tool NixOS configurations plus the ISO output. These are configuration scaffolds only; they have not been evaluated or booted. The flake names the `nixos-unstable` input but has no lock file because Nix could not be run here. It is therefore not yet pinned or reproducible. Do not claim the desired revision lock until a generated lock file is reviewed and committed. Desktop option names follow the current [NixOS manual](https://nixos.org/manual/nixos/stable/) and must be rechecked against the locked revision.
