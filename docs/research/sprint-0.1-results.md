# Sprint 0.1 results

## Evidence status

The latest reviewed PR head was `681eed2ed313eed8ef613b6a1c306cd561eaec6f`. PR-triggered [Validate #21](https://github.com/Chitrank-Dixit/AtherOS/actions/runs/41693563477) and [Lint #21](https://github.com/Chitrank-Dixit/AtherOS/actions/runs/41693563501) both passed on that exact commit. Validate covered repository validation and lightweight unit tests. Lint covered Ruff, Pyright, ShellCheck, Markdown lint, YAML validation, and JSON Schema validation. These are PR-head CI results, not local Windows/WSL checks or post-merge CI evidence.

PR #1 has been merged into `main` at `a2d00306ac941aa2676e0069cc7c3a1df772c833`. Post-merge CI status is **NOT VERIFIED**; no post-merge workflow result is recorded here.

| Acceptance criterion | Status | Evidence / next step |
| --- | --- | --- |
| AC-01 Host diagnostics work | PASSED | `inspect-windows-host.ps1` produced a human-readable console report; restricted CIM, WSL, Docker, Podman, and Hyper-V checks reported errors independently. |
| AC-02 Builder architecture documented | PASSED | `docs/architecture/build-environment.md` added. |
| AC-03 Arch profile validates | NOT TESTED | Requires Archiso tooling in a disposable Arch builder. |
| AC-04 Arch ISO builds | BLOCKED | No verified disposable Arch builder or executed build evidence available here. |
| AC-05 Nix flake is locked | BLOCKED | `experiments/nixos/flake.lock` is ABSENT; no verified Nix environment is available to generate and review it. |
| AC-06 NixOS ISO builds | BLOCKED | Depends on a reviewed lock and disposable Nix builder. |
| AC-07 Arch ISO boots in UEFI VM | BLOCKED | Requires a generated ISO and available QEMU/UEFI disposable VM. |
| AC-08 NixOS ISO boots in UEFI VM | BLOCKED | Requires a generated ISO and available QEMU/UEFI disposable VM. |
| AC-09 Experiment schema validates | PASSED | Draft 2020-12 validation passed in [Validate #21](https://github.com/Chitrank-Dixit/AtherOS/actions/runs/41693563477) and [Lint #21](https://github.com/Chitrank-Dixit/AtherOS/actions/runs/41693563501) on the latest reviewed PR head. |
| AC-10 CI checks pass | PASSED | Both latest PR-triggered workflows, [Validate #21](https://github.com/Chitrank-Dixit/AtherOS/actions/runs/41693563477) and [Lint #21](https://github.com/Chitrank-Dixit/AtherOS/actions/runs/41693563501), passed on that head. Post-merge CI is not verified. |
| AC-11 Results documented | PASSED | This report and the implementation audit capture current statuses and blockers. |

## Commands executed

Commands executed include branch/status inspection, the four requested Podman diagnostics, registry DNS/TCP reachability checks, Windows host diagnostics, Git Bash shell syntax checks, PowerShell AST parsing, JSON syntax parsing, and `git diff --check`. The host report was run in a child PowerShell process with a process-only execution-policy override after confirming all persistent policy scopes are `Undefined`; no persistent host policy was changed. Repository validation stopped at Python compilation because the WindowsApps Python alias returned Permission denied. See the [implementation audit](sprint-0.1-implementation-audit.md) for exact outcomes.

## Remaining work

Run the remaining repository checks in a Linux environment with Python and validators; resolve Podman/WSL access through the user's approved environment process; complete isolated Arch/Nix builder workflows; generate and review `flake.lock` using Nix; build both ISOs; and boot each in disposable UEFI VMs. A dedicated manual CI image-build workflow remains pending tested runner isolation. Physical NVIDIA validation remains outside Sprint 0.1 and must not be inferred from virtual tests.

## Podman infrastructure decision and observations

ADR-007 accepts Podman as the primary local container runtime. Independent OCI builder definitions and rootless run wrappers have been added for Archiso and NixOS. Separate Windows diagnostic sessions dated 2026-11-03 recorded Podman CLI 6.0.2 in the build-environment assessment and 6.1.4 in the later implementation audit. These are observations from different sessions/environments; neither establishes that the Podman engine is operational. The later audit could not read the machine identity, and the configured default was a root connection. WSL distro enumeration was denied. Rootless mode, nested namespace support, image preparation, and ISO builds remain NOT TESTED. See the [Podman feasibility assessment](podman-build-feasibility.md).

## PR #1 final review remediation and pre-merge CI evidence

The Nix/Arch record, result-link, and evidence regression tests passed in Validate #21 at PR head `681eed2ed313eed8ef613b6a1c306cd561eaec6f`. Validate also passed repository validation and lightweight unit tests; Lint #21 passed Ruff, Pyright, ShellCheck, YAML, Markdown, and JSON Schema checks. PR #1 was subsequently merged at `a2d00306ac941aa2676e0069cc7c3a1df772c833`; these links document PR-head validation only. Post-merge CI and local Windows/WSL checks are not verified.

## Review-remediation implementation status

The reviewed implementation corrects optional-property assertions, routes record/report checks through the pinned Draft 2020-12 validator, adds schema and artifact-discovery regression tests, introduces recursive Nix ISO discovery with store-boundary checks, requires digest-pinned dated Arch base inputs for container builds, separates Arch build/artifact/checksum/manifest statuses, adds failure records, corrects ADR references, and emits a UEFI record template whose milestones remain NOT TESTED. The Ruff I001 import-order issue was corrected and passed Lint #21 on PR head `681eed2ed313eed8ef613b6a1c306cd561eaec6f`.

## Outstanding evidence

- Arch ISO build: BLOCKED / NOT TESTED; no suitable isolated Arch builder or build evidence is available.
- NixOS ISO build: BLOCKED / NOT TESTED; `experiments/nixos/flake.lock` is absent and must not be fabricated.
- UEFI boot for either ISO: BLOCKED / NOT TESTED; no ISO and disposable UEFI VM evidence exist.
- Desktop compatibility: NOT TESTED.
- Rootless Podman on this development machine: NOT TESTED; the existing engine is inaccessible and was not modified.
- Nested namespace support: NOT TESTED.
- NVIDIA physical hardware validation: NOT TESTED.
- Update/recovery operational testing: NOT TESTED; current material is research/framework only.
- Base distribution decision: NOT DECIDED; Arch versus NixOS remains subject to human approval.
