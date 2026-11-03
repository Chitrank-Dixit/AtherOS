# Rootless Podman build environments

Podman is Aether's accepted primary local container runtime ([ADR-007](../adr/ADR-007-container-runtime.md)). Each builder is one container; Podman Compose is not used because there are no cooperating services. The definitions use OCI-compatible `Containerfile` instructions. Docker is not required or used.

## Security and technical requirements

- Podman and Python 3 must already be installed and configured by the user or administrator. Follow the [official installation instructions](https://podman.io/docs/installation) for the selected Linux distribution. Aether scripts do not install packages, initialize Podman machines, switch connections, or alter subordinate ID files.
- Run local Linux Podman as a non-root user. Rootless Podman normally requires subordinate UID/GID ranges in `/etc/subuid` and `/etc/subgid`; the local diagnostic checks without editing them. Consult the [Podman rootless documentation](https://docs.podman.io/en/latest/markdown/podman.1.html#rootless-mode) and have an administrator resolve missing ranges.
- The Linux host needs user namespaces, a supported OCI runtime (`crun` or `runc`), a rootless networking backend for package downloads, and a storage filesystem supported by rootless Podman. `fuse-overlayfs` may be required for some kernels/filesystems. The diagnostic does not install or configure these components.
- The build scripts reject a remote Podman service. This avoids unintentionally changing an existing Podman machine or remote builder. Windows Podman commonly uses a Linux VM backend; select a dedicated disposable Linux VM explicitly, then run the workflow in that guest. The scripts do not initialize or alter that VM.
- Archiso's regular-user mode needs `unshare` and kernel user namespace support. Its container gets a nested user+mount namespace probe before the build. A failure blocks the build.
- Nix Linux sandboxing creates private mount, PID, network, IPC, and UTS namespaces and requires privileged sandbox setup from Nix's perspective. The Nix image keeps sandboxing enabled and sets `sandbox-fallback = false`. If sandboxing cannot run with rootless Podman, the build fails and must be run in an explicitly disposable Linux VM. Do not add capabilities, disable seccomp/SELinux, use `--privileged`, or pass a host Nix/Podman socket.
- Source is a read-only bind mount. A separate output directory is writable. SELinux relabeling is not requested. A denied mount is a blocker; do not turn off host enforcement.

Primary technical references: [mkarchiso manual](https://man.archlinux.org/man/mkarchiso.1.en), [Archiso project requirements](https://github.com/archlinux/archiso), [Podman rootless mode](https://docs.podman.io/en/latest/markdown/podman.1.html#rootless-mode), [Podman build mount and isolation options](https://docs.podman.io/en/stable/markdown/podman-build.1.html), and [Nix sandbox configuration](https://nix.dev/manual/nix/2.35/command-ref/conf-file.html#conf-sandbox).

## Read-only runtime check

```bash
make podman-env-check
```

It reports the Podman version, rootless/local service status, subordinate IDs, and basic user namespace functionality. It does not create containers, images, volumes, networks, machines, or connections. A pass is not proof that nested Archiso or Nix sandboxing will work; those are checked inside their builder containers.

## Prepare the images (separate from builds)

Choose an Arch Archive date and an official dated base image reference pinned by an OCI digest. The date encoded in the base image tag must match the selected Archive date. Obtain and review a real digest from the registry; the repository does not supply or invent one. The base image is an independent bootstrap input. The selected Archive provides package repositories for archiso installation and the ISO package set, but package state already present in the bootstrap image may not originate from that Archive. The builder uses `pacman -Sy --needed` and never relies on `pacman -Syyu` to downgrade packages. This remains an experimental mixed-input build, and binary reproducibility is not claimed. The Nix builder starts from the NixOS project's Nix 2.35.4 `linux/amd64` image pinned to `sha256:05fe61395588e8a11452e9ba4602d4f0eb0ce5db8f7b9fa417c4ec07af79ca42`.

```bash
make podman-prepare-arch ARCHIVE_DATE=YYYY/MM/DD ARCH_BASE_IMAGE='archlinux/archlinux:<matching-dated-tag>@sha256:<reviewed-digest>'
make podman-prepare-nixos
```

Image preparation pulls/builds local images only. Existing same-name images are preserved. Preparation does not run an ISO build. It requires a local rootless Podman runtime and network access to the image/package sources.

## Build Arch

Run only after designating the local Linux builder disposable. Acknowledgements do not prove it contains no important data.

```bash
export AETHER_PODMAN_DISPOSABLE=1
export AETHER_ARCHISO_DISPOSABLE=1
export AETHER_ARCHISO_REPO_SNAPSHOT=2026/11/02
make podman-build-arch-iso PROFILE=minimal
make podman-build-arch-iso PROFILE=desktop-gnome
```

The profile is mounted read-only. Build output is in a unique ignored `out/podman/arch/` directory; logs, checksums, build metadata, Podman version, builder image digest, base image tag/digest, archive date, and package manifest are retained there. The experiment record separates build, artifact, checksum, and manifest statuses. Missing or incomplete package databases make evidence validation fail even when mkarchiso itself succeeded. A desktop package profile is not desktop-session evidence.

## Build NixOS

The Nix flake must already have a reviewed `flake.lock`. The wrapper does not create or update it.

```bash
export AETHER_PODMAN_DISPOSABLE=1
export AETHER_NIXOS_DISPOSABLE=1
make podman-build-nixos-iso
```

Nix evaluation and ISO building are separate recorded actions. The output directory includes the pinned nixpkgs revision, Nix version, Podman version, builder image digest, logs, ISO, and checksums. Nix sandbox fallback is disabled.

## Troubleshooting

- **Podman missing or service unreachable:** stop. Install/configure Podman through the host's supported process; this repository will not alter it.
- **Rootless/subordinate ID check fails:** have the Linux administrator configure valid ranges. Do not run the builder with `sudo` as a workaround.
- **Remote service detected:** the scripts refuse it. Do not switch or edit the default connection; use the local engine in an explicitly disposable Linux guest.
- **Nested namespace probe fails:** retain the output and run the experiment in a disposable Linux VM. Do not add `CAP_SYS_ADMIN`, use `--privileged`, or weaken seccomp.
- **Nix sandbox setup fails:** keep `sandbox = true` and `sandbox-fallback = false`; use the disposable VM builder.
- **SELinux or filesystem denies a bind mount:** stop and use a supported Linux filesystem/VM. Do not apply `:z`, `:Z`, or disable labels to the repository.
- **No flake lock:** BLOCKED. Generate it in a suitable disposable Nix VM, review it, and commit it before retrying.

## Artifacts and cleanup

Each run uses `--rm` only for the specific new container it starts; it does not remove existing containers. Builder images are retained in the user's Podman store. No cleanup/prune command is provided. To reclaim space, inspect exact image IDs and output paths first and manually remove only Aether images/artifacts you created and no longer need. Never run `podman system prune`, `podman image prune`, or broad container/volume removal for this workflow.

## CI

Current pull-request CI uses independent validation jobs. The GitHub-hosted runner's rootless nested namespace behavior has not been verified for Archiso or Nix sandbox builds, so ISO container builds are not enabled there. CI build success is never boot evidence. A runner-specific Podman workflow can be added after its isolation probes pass; otherwise use the documented disposable Linux VM backend.
