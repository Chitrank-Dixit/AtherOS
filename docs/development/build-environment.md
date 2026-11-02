# Build environment

## Current host evidence

The workspace is on Windows. `wsl.exe` and `docker.exe` are discoverable, but WSL returned `E_ACCESSDENIED` when queried and Docker could not connect to an engine. `qemu-system-x86_64` and `VBoxManage` were not found in PATH. Hyper-V cmdlets are discoverable, but no VM availability or configuration was verified. These checks establish that no usable VM environment is currently demonstrated; they do not prove the host cannot support one.

Ubuntu on WSL can help with Linux shell tools and possibly image builds if it is accessible and has the required packages. WSL GUI support is not a full desktop validation environment. WSL nested VM configuration and usable hardware virtualization must be separately verified. This project will not modify Windows, WSL, virtualization features, or host boot configuration.

## Native builders

- Arch ISO: build within a disposable Arch Linux builder with `archiso` and `mkarchiso`.
- NixOS ISO: build with Nix flakes using the native NixOS ISO image configuration in `experiments/nixos/flake.nix`.
- VM matrix: use an approved hypervisor with disposable UEFI guests and network access.

Build outputs go under ignored `out/` or Nix `result` paths. ISO targets do not invoke privilege escalation automatically.
