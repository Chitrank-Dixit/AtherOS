# Build environment

## Recorded host evidence (2026-11-03 diagnostics)

Historical Windows diagnostics recorded different Podman CLI versions in separate sessions on 2026-11-03:

| Observation | CLI version | Context and result |
| --- | --- | --- |
| Sprint 0.1 build-environment assessment | 6.0.2 | `podman info` could not reach the WSL-backed engine because access to the machine identity was denied. |
| Later Sprint 0.1 implementation audit | 6.1.4 | The client displayed its version, then engine access failed on the same machine-identity permission error. The connection listing showed the root connection as default. |

These are separate session/environment observations; this report does not select one as the authoritative current version or infer that the engine works. A later `podman machine list` attempt failed because Podman could not create `C:\Users\Admin\.config` (a file already exists at that path). Rootless operation and container execution remain unverified. No machine, connection, or conflicting path was changed.

WSL enumeration still returns `E_ACCESSDENIED`. `qemu-system-x86_64` and `VBoxManage` were not found in PATH, and Hyper-V VM inventory returned access denied. Host CIM queries also returned access denied. DNS resolves the configured registries, but direct HTTPS port 443 checks failed. These checks establish that no usable builder or VM environment is demonstrated; they do not prove the host cannot support one. See the [current Sprint 0.1 audit](../research/sprint-0.1-implementation-audit.md).

Ubuntu on WSL can help with Linux shell tools and possibly image builds if it becomes accessible and has the required packages. WSL GUI support is not a full desktop validation environment. WSL nested VM configuration and usable hardware virtualization must be separately verified. This project will not modify Windows, WSL, virtualization features, Podman machines/connections, or host boot configuration.

## Native builders

- Arch ISO: build within a disposable Arch Linux builder with `archiso` and `mkarchiso`.
- NixOS ISO: build with Nix flakes using the native NixOS ISO image configuration in `experiments/nixos/flake.nix`.
- Podman: use the separate rootless local builder wrappers only after the read-only runtime checks pass; otherwise use a suitable disposable Linux VM. The existing Windows remote Podman connection is not accepted by these wrappers.
- VM matrix: use an approved hypervisor with disposable UEFI guests and network access.

Build outputs go under ignored `out/` or Nix `result` paths. ISO targets do not invoke privilege escalation automatically.
