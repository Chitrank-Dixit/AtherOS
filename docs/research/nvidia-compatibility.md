# NVIDIA compatibility

Target system from the project brief: Ryzen 7 9700X, MSI MAG B850 Tomahawk WiFi, RTX 5060 Ti 16 GB, 32 GB DDR5, currently Windows-based.

## Documentation findings (checked 2026-11-03)

- NVIDIA's Linux driver documentation says Blackwell and later GPUs are supported only by the open kernel module flavor; NVIDIA recommends the open flavor on GPUs that support it. The RTX 5060 Ti is a Blackwell-generation card, so the evaluation should start with the open kernel module path. This is a documentation-based conclusion, not a test on the target card. [NVIDIA open kernel modules](https://download.nvidia.com/XFree86/Linux-x86_64/615.71.09/README/kernel_open.html)
- NVIDIA's CUDA architecture matrix lists Blackwell support beginning with CUDA 12.8. The current CUDA installation guide lists qualified distribution versions and requires a supported Linux/toolchain combination. Arch and NixOS are not listed in that guide's supported-distribution table, so CUDA packaging on either candidate needs separate community/package integration and validation; do not describe it as vendor-qualified. [CUDA architecture matrix](https://docs.nvidia.com/datacenter/tesla/drivers/cuda-toolkit-driver-and-architecture-matrix.html), [CUDA Linux installation guide](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/)
- PyTorch's Linux installation selector offers CUDA builds and documents checking `torch.cuda.is_available()` after installation. A successful package install alone does not prove the driver, toolkit, or GPU works. [PyTorch install selector](https://pytorch.org/get-started/locally/)
- Hyprland's NVIDIA guidance identifies explicit synchronization requirements for avoiding common XWayland flicker, including compatible NVIDIA driver, Xwayland, and Wayland protocols. Confirm requirements against the tested versions at experiment time. [Hyprland NVIDIA guidance](https://wiki.hypr.land/0.45.0/Nvidia/)
- GNOME 50 release notes describe explicit-sync integration and NVIDIA-specific compositor workarounds. This is upstream release-note evidence, not a guarantee for a particular distribution packaging set. [GNOME 50 release notes](https://release.gnome.org/50/)

## Validation still required

**Physical test status: NOT TESTED.** No live USB or host configuration was performed. The host OS and bootloader remain untouched. **VM status: BLOCKED.** No VM boot was available; even a VM without GPU passthrough would validate virtual graphics only, not NVIDIA hardware.

Still to investigate and test: current kernel/driver pairing on both candidates, GDM/SDDM Wayland behavior for GNOME and KDE, Hyprland startup, CUDA/PyTorch workload, suspend/resume, multi-monitor, and Secure Boot. Record driver, kernel, desktop, and toolkit versions. Physical validation requires a live USB and a non-destructive procedure with explicit user approval.
