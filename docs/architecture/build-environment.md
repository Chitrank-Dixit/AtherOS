# Build Environment Architecture

Sprint 0.1 keeps source configuration, ISO construction, and UEFI boot testing in separate stages. A successful build is not boot evidence, and virtual graphics do not establish physical NVIDIA compatibility.

```text
Repository revision
       |
       +--> isolated Linux builder --> Arch ISO + log + metadata + checksums
       |                         `--> NixOS ISO + log + metadata + checksums
       |
       `--> checks and experiment records

ISO + checksum --> disposable UEFI VM --> boot evidence + experiment record
```

## Isolation boundaries

- Diagnostics are read-only and do not start builders or install tools.
- Build scripts require an explicit disposable-environment acknowledgement. The acknowledgement is not proof of disposability; VM detection is only an additional signal.
- Builders write to unique output directories and do not access physical disks.
- Local container builders use rootless Podman, OCI Containerfiles, a read-only repository bind mount, and a separate writable artifact directory. No Docker dependency or host Podman socket is used. Container setup and ISO building are separate commands.
- Boot testing uses QEMU with UEFI firmware when available. Live ISO checks do not need a virtual disk. Installer tests that require a virtual disk must create a new, explicitly named disk in a disposable VM; never attach a physical disk or host EFI partition.
- Windows host, WSL configuration, boot settings, and installed operating systems are outside the build workflow.

## Backend comparison

| Backend | Build suitability | UEFI boot-test suitability | Constraints |
| --- | --- | --- | --- |
| Dedicated Linux VM | Good when disposable and isolated | Good with QEMU/OVMF or hypervisor UEFI | Must be explicitly designated disposable; avoid host disk passthrough |
| Disposable cloud Linux VM | Good for remote build | Conditional on nested virtualization and console access | Provider-specific and may incur cost; no physical GPU evidence |
| CI Linux runner | Suitable for controlled builds | Not assumed | A build artifact from CI does not prove it boots |
| WSL2 | Linux tools may work; not automatically disposable | Not an assumed UEFI test backend | WSL GUI integration is not a full desktop or UEFI VM; nested virtualization is configuration-dependent |
| Podman or Docker | Potentially useful for isolated build tools | Not a UEFI VM | Windows implementations use a Linux machine/backend; container isolation is not VM boot validation |
| QEMU + OVMF | Linux ISO boot validation | Preferred candidate | Availability and nested virtualization must be checked; not installed automatically |
| Hyper-V, VMware, VirtualBox | Potential VM backend | Potential UEFI testing | Availability and safe disposable VM creation must be confirmed individually |

No backend is selected as the universal project standard. The current environment must be diagnosed before a build or boot attempt. See the host and Linux builder diagnostic scripts.

## Build flow

1. Run read-only diagnostics and select an explicitly disposable Linux builder.
2. Record repository commit, builder OS/kernel/architecture, tool versions, and repository inputs.
3. Run one distribution build script in that environment. Each build gets a distinct output directory, complete log, metadata manifest, and SHA-256/SHA-512 checksums.
4. Review the build output and record its actual result. Pinning inputs improves repeatability but does not establish bit-for-bit reproducibility.
5. Boot the ISO separately in a disposable UEFI VM. Record firmware, VM resources, ISO checksum, logs, and observed behavior.
6. Validate the experiment record against the schema. Missing evidence stays NOT TESTED or BLOCKED.

## Evidence categories

Documentation research, builder observations, UEFI VM observations, and physical hardware testing are separate evidence classes. Physical NVIDIA compatibility is not tested by this sprint's VM workflow.

## CI boundaries

Existing pull request workflows run independent lint jobs and lightweight repository validation. Experiment fixtures are added to the JSON Schema job. Expensive ISO construction and UEFI boots are not triggered on every pull request. A dedicated manual build workflow remains pending a tested, pinned builder image and review of its isolation behavior; CI build success alone will never be reported as UEFI boot success.

## Podman backend

Podman is the accepted primary local container runtime ([ADR-007](../adr/ADR-007-container-runtime.md)). Arch and Nix each have independent OCI builder definitions. Both are invoked only after a read-only local/rootless runtime check and an explicit disposable-build acknowledgement. The runtime must report local service mode and rootless operation; an existing remote connection or Podman machine is never selected implicitly for a build.

The Arch builder tests nested user and mount namespaces before calling Archiso. Its official base image must be supplied as a dated tag pinned by digest, and the tag date must match the explicit Archive date. The base image remains an independent bootstrap input; installed base packages may differ from the Archive snapshot, so the workflow is experimental and does not claim coherent binary reproducibility. It never uses `pacman -Syyu` as a downgrade mechanism. Archiso's regular-user path itself depends on `unshare` and kernel user namespaces. Nix runs with `sandbox = true` and `sandbox-fallback = false`; its default Linux sandbox uses private PID, mount, network, IPC, and UTS namespaces. If either probe or actual operation fails, retain the logs and use a disposable Linux VM. Do not add capabilities, disable seccomp/SELinux, set host networking, or pass a host Podman socket to make a build proceed.

The builders use ADR-007's `nested-namespace` security profile: Podman's rootless runtime defaults are retained without added capabilities, while `no-new-privileges`, the default seccomp/LSM policy, and an explicit bridge network remain in effect. The in-container probe blocks if `CAP_SYS_ADMIN` appears in any capability set. The separate `standard` profile drops all capabilities and disables networking for ordinary containers. The reason for the builder exception and its operator-reported WSL2 evidence are documented in the [Sprint 0.3 report](../development/sprint-0.3-podman-security.md).

Source is mounted read-only and build artifacts are mounted at a separate output path. SELinux relabeling is not requested; if policy denies a mount, stop and use an approved VM. Container filesystems are disposable per run; downloaded images remain in the user's Podman store until the user chooses to remove them manually.
