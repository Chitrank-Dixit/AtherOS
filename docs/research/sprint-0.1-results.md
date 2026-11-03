# Sprint 0.1 results

## Evidence status

This report reflects reviewed PR head `3be9b87481796dccceb6706991d11954754f1408` and its GitHub Actions run 11 results. The Validate workflow and all Lint jobs except Ruff passed. A local Ruff import-order correction and report updates are currently uncommitted and have not been CI-validated. Windows-side diagnostics ran previously; WSL enumeration and the Podman engine remain inaccessible. No Linux ISO build or UEFI boot was attempted.

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
| AC-09 Experiment schema validates | PASSED | Draft 2020-12 validation passed in both [Lint run 11](https://github.com/Chitrank-Dixit/AtherOS/actions/runs/41663324475) and [Validate run 11](https://github.com/Chitrank-Dixit/AtherOS/actions/runs/41663324521). |
| AC-10 CI checks pass | FAILED | Validate run 11 passed. Lint run 11 failed only on Ruff import ordering; Markdown, YAML, ShellCheck, Pyright, and JSON Schema jobs passed. |
| AC-11 Results documented | PASSED | This report and the implementation audit capture current statuses and blockers. |

## Commands executed

Commands executed include branch/status inspection, the four requested Podman diagnostics, registry DNS/TCP reachability checks, Windows host diagnostics, Git Bash shell syntax checks, PowerShell AST parsing, JSON syntax parsing, and `git diff --check`. The host report was run in a child PowerShell process with a process-only execution-policy override after confirming all persistent policy scopes are `Undefined`; no persistent host policy was changed. Repository validation stopped at Python compilation because the WindowsApps Python alias returned Permission denied. See the [implementation audit](sprint-0.1-implementation-audit.md) for exact outcomes.

## Remaining work

Run the remaining repository checks in a Linux environment with Python and validators; resolve Podman/WSL access through the user's approved environment process; complete isolated Arch/Nix builder workflows; generate and review `flake.lock` using Nix; build both ISOs; and boot each in disposable UEFI VMs. A dedicated manual CI image-build workflow remains pending tested runner isolation. Physical NVIDIA validation remains outside Sprint 0.1 and must not be inferred from virtual tests.

## Podman infrastructure decision

ADR-007 accepts Podman as the primary local container runtime. Independent OCI builder definitions and rootless run wrappers have been added for Archiso and NixOS. The current Podman CLI reports 6.1.4, but its engine cannot read the machine identity; the configured default remains a root connection. WSL distro enumeration is denied. Rootless mode, nested namespaces, image preparation, and ISO builds remain NOT TESTED. See the [Podman feasibility assessment](podman-build-feasibility.md).

## PR #1 final review remediation and CI evidence

The Nix/Arch record, result-link, and evidence regression tests passed in Validate run 11 at the reviewed commit. CI also passed repository/shell validation, JSON Schema validation, ShellCheck, Pyright, YAML lint, and Markdown lint. Ruff was the only failing CI job. The focused import-order correction and these report updates are local and still need CI verification. Locally, the Python alias and Ruff are unavailable, so no local Python lint or unit-test result is claimed. The read-only Podman diagnostic previously found client 6.1.4 but could not access the existing machine identity; rootless operation on this development machine remains NOT TESTED.

## Review-remediation implementation status

The reviewed implementation corrects optional-property assertions, routes record/report checks through the pinned Draft 2020-12 validator, adds schema and artifact-discovery regression tests, introduces recursive Nix ISO discovery with store-boundary checks, requires digest-pinned dated Arch base inputs for container builds, separates Arch build/artifact/checksum/manifest statuses, adds failure records, corrects ADR references, and emits a UEFI record template whose milestones remain NOT TESTED. At reviewed commit `3be9b87481796dccceb6706991d11954754f1408`, the Validate workflow passed unit tests and repository validation; Lint passed JSON Schema, ShellCheck, Pyright, Markdown, and YAML checks but failed Ruff import ordering. These are CI results, not local validation. The current local import-order correction has not yet been run by Ruff or CI.

## Outstanding evidence

- Arch ISO build: BLOCKED / NOT TESTED; no suitable isolated Arch builder or build evidence is available.
- NixOS ISO build: BLOCKED / NOT TESTED; `experiments/nixos/flake.lock` is absent and must not be fabricated.
- UEFI boot for either ISO: BLOCKED / NOT TESTED; no ISO and disposable UEFI VM evidence exist.
- Rootless Podman on this development machine: NOT TESTED; the existing engine is inaccessible and was not modified.
- NVIDIA physical hardware validation: NOT TESTED.
- Base distribution decision: NOT DECIDED; Arch versus NixOS remains subject to human approval.
