# Building the Arch Linux experiment ISO

## Scope and safety

This builds the Archiso experiment profile in an explicitly disposable Linux builder. The `AETHER_ARCHISO_DISPOSABLE=1` setting is an acknowledgement, not a proof of disposability. `systemd-detect-virt` is an additional environment check only. Do not run this on a persistent workstation, WSL distribution, or host whose data matters. The script does not install packages or alter host disks; Archiso may require privileges inside the disposable builder.

## Prerequisites

- A disposable Arch Linux x86_64 Linux VM with `archiso`, `pacman`, `git`, `sha256sum`, `sha512sum`, and Python 3.
- A pinned Arch Linux Archive snapshot date in `YYYY/MM/DD` format.
- For the Podman builder, an official dated `archlinux/archlinux` base image reference pinned by a reviewed SHA-256 OCI digest. The base tag date must equal the Archive date.
- Sufficient free storage for packages, work tree, ISO, logs, and metadata.

## Commands

From the repository root in the disposable builder:

```bash
scripts/environment/inspect-linux-builder.sh
export AETHER_ARCHISO_DISPOSABLE=1
export AETHER_ARCHISO_REPO_SNAPSHOT=2026/01/15
experiments/arch/scripts/build-iso.sh minimal
experiments/arch/scripts/build-iso.sh desktop-gnome
```

Replace the example snapshot with a deliberately chosen Archive date. The script should fail before building if acknowledgement, environment, profile, or required tools are missing. Outputs are profile-specific and timestamped. Review the build log, manifest, package list, and both checksum files before recording any result.

The container builder uses `pacman -Sy --needed`, never `pacman -Syyu` as a downgrade mechanism. Its official bootstrap image is a separate input from the Archive repositories. Matching the date in the tag and repository does not prove every base package originated in that Archive, so the build remains experimental and does not claim binary reproducibility. Metadata records both references, Archiso version, image digest, package manifest, and evidence status. Build execution can pass while evidence validation fails if the package database is absent or malformed.

The minimal profile is a diagnostic live system. The desktop profile is a package composition experiment; included desktop packages do not prove that a graphical session works. Session switching and recovery require separate VM tests.

## Reproducibility and cleanup

Repository snapshot and tool versions make inputs reviewable, but timestamps, package signing metadata, and other build inputs can prevent byte-identical ISO output. Keep the build output until evidence has been reviewed. Cleanup is a separate manual operation inside the disposable VM; verify the exact output path before removing it. Never point cleanup at host or physical disks.

## Troubleshooting

- Missing acknowledgement: set it only after confirming the builder is disposable.
- Missing Archiso or privileges: stop and provision an approved disposable builder separately; the script does not install tools.
- Snapshot unavailable: choose a valid Archive snapshot and rerun in a fresh output directory.
- A successful build is not a boot test; use the UEFI guide.
