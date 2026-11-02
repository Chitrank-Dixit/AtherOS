# Sprint 0.1 results

## Evidence status

This report records the checked-out `research/build-environment` worktree as uncommitted and does not claim build or boot success without direct execution evidence. Windows-side diagnostics now run. WSL enumeration and the Podman engine remain inaccessible; no Linux ISO build or UEFI boot was attempted.

| Acceptance criterion | Status | Evidence / next step |
| --- | --- | --- |
| AC-01 Host diagnostics work | PASSED | `inspect-windows-host.ps1` produced a human-readable console report; restricted CIM, WSL, Docker, Podman, and Hyper-V checks reported errors independently. |
| AC-02 Builder architecture documented | PASSED | `docs/architecture/build-environment.md` added. |
| AC-03 Arch profile validates | NOT TESTED | Requires Archiso tooling in a disposable Arch builder. |
| AC-04 Arch ISO builds | BLOCKED | No verified disposable Arch builder or executed build evidence available here. |
| AC-05 Nix flake is locked | BLOCKED | No verified Nix environment; do not invent `flake.lock`. |
| AC-06 NixOS ISO builds | BLOCKED | Depends on a reviewed lock and disposable Nix builder. |
| AC-07 Arch ISO boots in UEFI VM | BLOCKED | Requires a generated ISO and available QEMU/UEFI disposable VM. |
| AC-08 NixOS ISO boots in UEFI VM | BLOCKED | Requires a generated ISO and available QEMU/UEFI disposable VM. |
| AC-09 Experiment schema validates | NOT TESTED | Run schema validation after schema/fixture changes. |
| AC-10 CI checks pass | NOT TESTED | No workflow run from this work is available. |
| AC-11 Results documented | PASSED | This report and the implementation audit capture current statuses and blockers. |

## Commands executed

Commands executed include branch/status inspection, the four requested Podman diagnostics, registry DNS/TCP reachability checks, Windows host diagnostics, Git Bash shell syntax checks, PowerShell AST parsing, JSON syntax parsing, and `git diff --check`. The host report was run in a child PowerShell process with a process-only execution-policy override after confirming all persistent policy scopes are `Undefined`; no persistent host policy was changed. Repository validation stopped at Python compilation because the WindowsApps Python alias returned Permission denied. See the [implementation audit](sprint-0.1-implementation-audit.md) for exact outcomes.

## Remaining work

Run the remaining repository checks in a Linux environment with Python and validators; resolve Podman/WSL access through the user's approved environment process; complete isolated Arch/Nix builder workflows; generate and review `flake.lock` using Nix; build both ISOs; and boot each in disposable UEFI VMs. A dedicated manual CI image-build workflow remains pending tested runner isolation. Physical NVIDIA validation remains outside Sprint 0.1 and must not be inferred from virtual tests.

## Podman infrastructure decision

ADR-007 accepts Podman as the primary local container runtime. Independent OCI builder definitions and rootless run wrappers have been added for Archiso and NixOS. Podman is installed, but its engine is unreachable, the configured default is a root connection, and direct registry HTTPS checks failed. Rootless mode, nested namespaces, image preparation, and ISO builds remain NOT TESTED. See the [Podman feasibility assessment](podman-build-feasibility.md).
