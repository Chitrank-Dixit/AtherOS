# Build environment

## Current host evidence

The workspace is on Windows. The Podman 6.0.2 CLI is installed, but `podman info` cannot reach its WSL-backed engine because access to the machine identity is denied. `podman machine list` fails because Podman cannot create `C:\Users\Admin\.config` (a file already exists at that path). The configured default connection is the root connection. The non-root connection is not selected. Rootless operation and container execution are therefore unverified. The audit makes no changes to the machine, connection, or the conflicting path.

WSL enumeration still returns `E_ACCESSDENIED`. `qemu-system-x86_64` and `VBoxManage` were not found in PATH, and Hyper-V VM inventory returned access denied. Host CIM queries also returned access denied. DNS resolves the configured registries, but direct HTTPS port 443 checks failed. These checks establish that no usable builder or VM environment is demonstrated; they do not prove the host cannot support one. See the [current Sprint 0.1 audit](../research/sprint-0.1-implementation-audit.md).

Ubuntu on WSL can help with Linux shell tools and possibly image builds if it becomes accessible and has the required packages. WSL GUI support is not a full desktop validation environment. WSL nested VM configuration and usable hardware virtualization must be separately verified. This project will not modify Windows, WSL, virtualization features, Podman machines/connections, or host boot configuration.

## Native builders

- Arch ISO: build within a disposable Arch Linux builder with `archiso` and `mkarchiso`.
- NixOS ISO: build with Nix flakes using the native NixOS ISO image configuration in `experiments/nixos/flake.nix`.
- Podman: use the separate rootless local builder wrappers only after the read-only runtime checks pass; otherwise use a suitable disposable Linux VM. The existing Windows remote Podman connection is not accepted by these wrappers.
- VM matrix: use an approved hypervisor with disposable UEFI guests and network access.

Build outputs go under ignored `out/` or Nix `result` paths. ISO targets do not invoke privilege escalation automatically.
