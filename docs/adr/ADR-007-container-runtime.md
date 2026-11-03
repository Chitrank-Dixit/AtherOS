# ADR-007: Podman-first container infrastructure

- **Status:** Accepted
- **Date:** 2026-11-03
- **Decision owners:** Project owner

## Context

Aether needs isolated local build environments for distribution experiments. The requirements favor rootless operation, OCI-compatible definitions, and no mandatory Docker installation. Container builds must not bypass operating system security boundaries when nested namespaces or filesystem mounts are unavailable.

## Decision

Use Podman as Aether's primary local container runtime. Use portable OCI `Containerfile` definitions and prefer rootless Podman. Do not require Docker or Docker-specific build dependencies. Use Podman Compose only when multiple cooperating services justify it; the current build environments are independent single-container tasks.

Archiso and Nix builders are independent. Containers run without `--privileged`, additional capabilities, host networking, host Podman sockets, host root mounts, or writable source mounts. They must fail when their nested namespace or sandbox requirements are unavailable. Nix builds keep sandboxing enabled and disable sandbox fallback. The approved fallback is an explicitly disposable Linux VM, not weakened container security.

## Consequences

- Users must install and configure Podman themselves; Aether never installs Podman or changes Podman machines/connections automatically.
- Builders require a working local rootless Podman service and user namespaces. Archiso itself requires `unshare` and kernel user namespace support for regular-user operation.
- Nix's Linux sandbox requires namespace and mount isolation. Rootless-container support for those nested operations must be verified on each host; an unsupported environment uses a disposable Linux VM.
- Builder image versions/digests, Podman version, package revisions, build logs, and artifact checksums are recorded.
- The selected container runtime does not select Arch or NixOS as Aether's base distribution. ADR-001 remains proposed.

## Implementation status

The OCI definitions and wrappers are present but not runtime-validated. The current host's Podman machine cannot be reached, and the default connection targets its root service. No machine or connection has been changed.

## Alternatives considered

- Docker: rejected as a required local dependency because the project requirement explicitly standardizes on Podman.
- Privileged Podman containers or host Podman socket: rejected because they expand container authority and are not needed to define a safe fallback.
- Linux VM for every local task: retained as the mandatory fallback where nested rootless container requirements cannot be met safely.

## Review conditions

Revisit after rootless build probes and actual ISO build attempts on supported Linux builders. Do not infer desktop, UEFI boot, or physical NVIDIA behavior from a container build.
