# Podman build feasibility assessment

**Research date:** 2026-11-03  
**Evidence class:** upstream documentation review and read-only Windows Podman diagnostics; no container build executed.

## Archiso

The Archiso project documents regular non-root operation using `unshare` and kernel user namespace support. The image generator also creates filesystem trees, chroots, and ISO/EFI artifacts. Therefore a rootless Podman build depends on nested user/mount namespace support and writable artifact storage. Podman does not receive added capabilities in the proposed run command. A small nested namespace/tmpfs probe runs before Archiso; that probe is necessary but does not prove all later archiso operations will succeed. Build failures are retained and lead to the disposable Linux VM fallback.

The Arch builder requires an official dated Arch `base-devel` image reference pinned by digest; its tag date must match the explicit Arch Linux Archive date. The Archive provides package repositories for `archiso` installation and the ISO package set, but does not retroactively define every package in the bootstrap image. The build uses `pacman -Sy --needed`, not `pacman -Syyu` as a downgrade mechanism. This mixed input remains experimental. The built builder image digest, base reference/digest, Archiso version, and actual package manifest are recorded.

## Nix

Nix 2.35 documentation says Linux sandboxed builds use private PID, mount, network, IPC, and UTS namespaces; sandboxing requires Nix to perform setup as root. The builder uses the official NixOS Nix 2.35.4 linux/amd64 image pinned by manifest digest. Root inside the rootless Podman container is confined to Podman's user namespace and is not host root. Nix is invoked with sandboxing enabled and `sandbox-fallback = false`. If Nix cannot create its sandbox inside the outer rootless container, the operation must fail. No `sandbox = false`, `--privileged`, added host capability, daemon socket, or host namespace is permitted.

The namespace probe cannot prove Nix's full sandbox will work. Only an actual evaluation/build attempt on a disposable Linux builder can determine that. If sandbox setup fails, use the direct disposable Linux VM workflow.

## Podman host constraints

Rootless Podman uses user namespaces and normally requires subordinate UID/GID ranges. Rootless networking, OCI runtime, and backing filesystem support also vary by host. Windows Podman communicates with its Linux Podman machine through a remote service. Because Aether must not alter existing machines/connections, build wrappers reject remote Podman services and require local rootless service mode inside an explicitly designated Linux builder.

SELinux labeling and the host filesystem can prevent the source/artifact bind mounts from working. The wrapper does not relabel workspaces or disable SELinux. Such a failure is a blocker, not a reason to weaken isolation.

## Execution status

The Windows Podman 6.1.4 CLI is present, but the engine is unreachable because the existing machine identity cannot be read. The default connection points to its root service. Direct TCP/443 checks to the required registries failed after DNS resolution. No existing Podman machine or connection was changed; no image pull or smoke test was attempted. Rootless operation is therefore unverified. The Containerfiles and wrappers are implementation artifacts, not verified build capabilities. Archiso container build, Nix container sandbox build, ISO generation, UEFI boot, and CI Podman support remain **NOT TESTED**.

## Sprint 0.3 operator-reported WSL2 experiment

The operator supplied a separate runtime experiment from local rootless Podman 5.7.0 on Ubuntu 26.04 WSL2 with kernel 6.18.33.2. Its date and raw command transcripts were not included, so this is recorded as supplied evidence rather than an independently reproduced test. The detailed record is [PODMAN-WSL2-NAMESPACE-SECURITY-01](../../experiments/containers/results/sprint-0.3-wsl2-namespace-security.json).

| Test | Reported result |
| --- | --- |
| Local rootless Podman; host user namespaces; rootless container execution | PASSED |
| Read-only source bind and writable output bind mounts | PASSED |
| Nested user namespace with Podman's default capabilities and `no-new-privileges` | PASSED |
| Nested mount namespace and private tmpfs | PASSED |
| Nested user namespace with `--cap-drop=ALL` | FAILED |
| Nested user namespace with SETUID+SETGID | FAILED |
| Nested user namespace with SETUID+SETGID+SETPCAP | FAILED |

The observed incompatible setting is `--cap-drop=ALL`. The evidence does not isolate which individual default capability is necessary, and the tested capability additions did not restore nested namespace creation. It therefore does not support replacing the runtime default set with a hand-picked set. Aether keeps two profiles: strict `standard` isolation drops all capabilities and disables networking, while the builders that require nested namespaces use `nested-namespace`, which retains Podman's version-specific rootless defaults without adding capabilities. Both retain `no-new-privileges`; the namespace-dependent profile also leaves default seccomp and host LSM enforcement intact and uses an explicit bridge network, not host networking. Its in-container probe blocks if `CAP_SYS_ADMIN` appears in any capability set. This modifies only the builder container process policy; it does not change host configuration. The in-container probe remains required before either builder script can run.

This experiment did not build Archiso or NixOS, evaluate the Nix sandbox, generate an ISO, or boot a VM. Those outcomes remain **NOT TESTED**. Preserving Podman's runtime-default capabilities increases the builder's container-level permissions compared with the standard profile, and those defaults vary by Podman version; the exact version is recorded in builder metadata for review.

The earlier Windows CLI observation above is a separate historical host session. It is not contradicted by the supplied Ubuntu WSL2 result, which reports a working local rootless runtime in that Linux environment. The current PowerShell host's Podman, WSL access, and nested namespace behavior have not been tested as part of Sprint 0.3.

## Primary sources

- [Archiso project requirements and image workflow](https://github.com/archlinux/archiso)
- [`mkarchiso` manual](https://man.archlinux.org/man/mkarchiso.1.en)
- [Podman rootless mode](https://docs.podman.io/en/latest/markdown/podman.1.html#rootless-mode)
- [Podman build isolation and mount options](https://docs.podman.io/en/stable/markdown/podman-build.1.html)
- [Nix sandbox configuration](https://nix.dev/manual/nix/2.35/command-ref/conf-file.html#conf-sandbox)
- [Official Nix image version and architecture digests](https://github.com/NixOS/nix/pkgs/container/nix)
- [Podman Windows and Linux installation model](https://podman.io/docs/installation)
