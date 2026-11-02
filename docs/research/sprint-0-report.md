# Sprint 0 report — foundation and feasibility

**Report date:** 2026-11-03  
**Overall status:** Foundation scaffold created; required candidate experiments remain blocked. This is not a completed Sprint 0 evaluation.

## Executive summary

The workspace now has engineering guidance, documentation structure, validation entry points, CI scaffolding, and minimal Arch/NixOS ISO experiment scaffolds. The available Windows environment did not demonstrate usable WSL, Docker, or a VM builder. Consequently, no guest, ISO, desktop, update, or recovery experiment was run. No candidate is recommended and no score is assigned. The base distribution remains undecided pending evidence and human approval.

## Environment and evidence

- `D:\Projects\AetherOS` was empty and had no Git repository at inspection.
- `wsl.exe` was discoverable; `wsl --status` returned `E_ACCESSDENIED` while enumerating distros.
- Docker CLI was discoverable; `docker info` could not connect because the Docker engine pipe was absent. Reading Docker config returned access denied.
- `qemu-system-x86_64` and `VBoxManage` were not found in PATH. Hyper-V cmdlets were discoverable, but no VM configuration was inspected or changed.
- These observations are environment checks, not proof that virtualization is impossible on the host.

## Results

| Area | Status | Result |
|---|---|---|
| Repository and engineering scaffold | Implemented | Files, validation workflow, and tooling unit tests added; local checks pending |
| Arch VM / ISO / desktops / updates / recovery | BLOCKED | No usable disposable Linux builder or VM was demonstrated |
| NixOS VM / ISO / desktops / generations | BLOCKED | Nix unavailable; no guest or build attempted |
| Desktop compatibility matrix | NOT TESTED | All six candidate cells remain untested |
| NVIDIA research and physical validation | PARTIAL / NOT TESTED | Vendor and upstream docs now establish Blackwell open-module requirement, CUDA 12.8 floor, and desktop integration notes; target hardware and remaining driver/session scenarios are untested |
| Update/recovery comparison | Research framework only | Candidate trade-offs documented; no operational tests |
| Evaluation scores/base recommendation | NOT DECIDED | Withheld until comparable evidence; final decision needs human approval |

## Acceptance criteria

- [x] Repository structure and AGENTS.md established.
- [x] Engineering conventions and documented Make targets added.
- [ ] CI pipeline passes — workflows and checks added; remote CI has not run.
- [ ] Arch VM and ISO operational — BLOCKED; no builder/VM evidence.
- [ ] NixOS VM and ISO operational — BLOCKED; Nix unavailable.
- [ ] Both ISOs boot in UEFI VMs — BLOCKED.
- [ ] Desktop compatibility and multi-session switching evaluated — NOT TESTED.
- [x] NVIDIA compatibility research documented — initial primary-source findings recorded; remaining areas and physical hardware NOT TESTED.
- [ ] Update and recovery strategies compared with experiments — NOT TESTED.
- [ ] Evaluation matrix scored and recommendation documented — NOT DECIDED pending evidence and human approval.

## Reproduction commands

In a suitable Linux checkout:

```sh
make help
make validate
make validate-arch
make validate-nixos
make build-arch-iso
make build-nixos-iso
make test
```

`make build-arch-iso` requires a disposable Arch Linux builder with `archiso`; `make build-nixos-iso` requires Nix with flakes and a reviewed `flake.lock`. These commands were not run because the required environment was unavailable.

## Sprint 1 recommendations

1. Provide an approved disposable UEFI VM environment or separate Linux builder and record its version/configuration.
2. Resolve and review the Nix flake lock; build and boot both candidate images.
3. Execute the desktop matrix, update flows, and failure/recovery tests with evidence.
4. Research NVIDIA using current vendor/kernel documentation, then schedule any physical live-USB test only with explicit approval.
5. Score candidates from evidence and submit ADR-001 for human decision.
