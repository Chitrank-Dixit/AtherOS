# Building the NixOS experiment ISO

## Current lock status

This repository's Nix experiment requires a reviewed `flake.lock`. Do not fabricate one or run an unreviewed `nix flake update`. If no committed lock exists, the ISO build is blocked until Nix is available in a suitable disposable Linux builder and the lock is generated and reviewed there.

## Prerequisites and safety

Use a disposable Linux VM designated for builds, with Nix supporting flakes, Git, GNU `find`, `realpath`, `sha256sum`, `sha512sum`, and enough free storage. Do not use a persistent WSL distribution as a disposable builder. `AETHER_NIXOS_DISPOSABLE=1` is an acknowledgement, not proof of isolation. The build does not attach disks or configure the host.

## Commands

From repository root after the lock has been reviewed and committed:

```bash
scripts/environment/inspect-linux-builder.sh
export AETHER_NIXOS_DISPOSABLE=1
experiments/nixos/scripts/build-iso.sh
```

Record `nix --version`, `nix flake metadata --json`, the locked `nixpkgs` revision, system architecture, Git commit, complete build log, ISO filename, size, and SHA-256/SHA-512 digests. Evaluation and ISO generation are separate outcomes: successful evaluation does not imply that an ISO was built.

Evaluation and build commands pass `--no-write-lock-file`; they use the reviewed lock and will not update it. The build searches recursively for regular `.iso` files under the resolved Nix result symlink, rejects targets outside `/nix/store`, does not follow nested symlinks, and requires exactly one ISO. The experiment record includes the artifact path relative to the result directory. No ISO, multiple ISOs, checksum errors, or metadata errors are recorded as failures with their logs; a successful Nix build does not imply that extraction or evidence generation passed.

## Troubleshooting and cleanup

If Nix or `flake.lock` is absent, report BLOCKED and do not substitute a guessed revision. Build output is retained in a unique directory for review. Remove it only after verifying the precise path and only within the disposable builder. Use the separate UEFI guide for boot validation.
