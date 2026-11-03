# Sprint 0.1 implementation audit

**Audit date:** 2026-11-03  
**Review context:** PR #1 before merge
**Reviewed PR head:** `681eed2ed313eed8ef613b6a1c306cd561eaec6f`
**Merge commit:** `a2d00306ac941aa2676e0069cc7c3a1df772c833`

## Summary

The reviewed branch contains Sprint 0.1 implementation artifacts, including Arch/Nix build wrappers, diagnostics, a QEMU live-ISO harness, experiment records, documentation, and Podman builders. PR #1 was merged into `main` at `a2d00306ac941aa2676e0069cc7c3a1df772c833`. On the exact pre-merge PR head `681eed2ed313eed8ef613b6a1c306cd561eaec6f`, [Validate #21](https://github.com/Chitrank-Dixit/AtherOS/actions/runs/41693563477) and [Lint #21](https://github.com/Chitrank-Dixit/AtherOS/actions/runs/41693563501) passed. Validate covered repository validation and lightweight unit tests; Lint covered Ruff, Pyright, ShellCheck, Markdown lint, YAML, and JSON Schema validation. These are PR-head CI results only; post-merge CI and local Windows/WSL validation are not established. No successful ISO build or boot has been established.

Post-merge CI status: **NOT VERIFIED**. The workflow evidence recorded here is tied to PR-head events; no post-merge workflow result is claimed.

## Implemented functionality

- **Arch experiment:** minimal and desktop-GNOME profiles remain separate. The wrapper requires a disposable acknowledgement and dated Arch Archive snapshot, creates timestamped output, writes an isolated pacman configuration, logs `mkarchiso`, records Archiso/Git/builder details, captures package versions when available, and emits SHA-256/SHA-512 checksums.
- **NixOS experiment:** the wrapper requires Nix, Linux, checksum utilities, a disposable acknowledgement, a VM signal (or the explicit Podman wrapper marker), and `flake.lock`. It records Nix/flakes metadata and locked nixpkgs revision, separates evaluation from build, captures logs and checksums, and keeps sandboxing enabled with sandbox fallback disabled.
- **Podman:** separate Arch and Nix OCI Containerfiles exist. Runtime checks require local rootless Podman and check subordinate IDs and user namespaces. Build wrappers mount source read-only and a separate artifact directory read-write, drop container capabilities, set no-new-privileges, avoid host sockets and Compose, record Podman/image details, and use `--rm` only for their own temporary build container.
- **UEFI:** a QEMU/OVMF live-ISO harness records ISO and firmware hashes, resources, QEMU logs, and serial logs. It creates no virtual disk; it does not itself establish that the observed guest reached each requested boot milestone.
- **Records and reporting:** the JSON Schema adds build/boot, distribution, checksum, firmware, VM, logs, and blocker fields with status conditions. There are examples for each status. The shared pinned Draft 2020-12 validator passed in both the Lint schema job and the Validate workflow at the reviewed commit.
- **Documentation:** architecture, build, UEFI, Podman, licensing, assessment, feasibility, and results documents exist. ADR-001 still leaves the base distribution unselected; the Podman runtime decision is documented as accepted.

## Findings and gaps

1. **Resolved — ADR identifier collision:** `ADR-002-desktop-environments.md` already exists. The Podman decision now uses `ADR-007-container-runtime.md`, and the new references point to ADR-007.
2. **Resolved during this audit — README placement:** the Sprint 0.1 links are integrated in the existing “Start here” list; no duplicate title was retained.
3. **Resolved during this audit — stale status reports:** the reports distinguish the reviewed PR head, merge status, PR-head CI evidence, and unverified post-merge CI. Host observations are dated and identified by diagnostic session.
4. **Resolved and CI-verified — report validation:** record validation and report generation use the pinned `jsonschema` Draft 2020-12 implementation. Schema validation passed in the Lint workflow and repository validation in the Validate workflow at the reviewed commit. Local execution remains unavailable.
5. **Resolved during this audit — Nix result-link collision:** the Nix wrapper now refuses an existing output directory or result-link path before writing.
6. **Implemented in current worktree — failure metadata:** Nix failures now produce a stage-specific experiment record for prerequisite, metadata, evaluation, build, artifact discovery, checksum, and metadata-generation stages. Arch records build and evidence statuses separately. These paths have not been exercised in a builder.
7. **Podman does not run its own investigation checks:** the repository check script verifies the engine, rootless flag, remote flag, subordinate IDs, and namespace probes; the requested Windows read-only diagnostics separately query machine state. The current command-line connection and engine results below are current host observations, not evidence that the Linux builder wrappers work.
8. **CI build lane is absent:** fast validation remains split across independent lint jobs. No manual Podman ISO-build workflow is present. The documentation correctly treats runner Podman/nested namespace support as unverified; build/boot CI must not be represented as passing.
9. **Nix lock and result evidence are absent:** `experiments/nixos/flake.lock` does not exist. No Nix toolchain is available in the current shell environment, so a lock must not be generated or guessed.

## Current environment diagnostics

All listed Podman commands were read-only.

| Check | Result |
| --- | --- |
| Podman CLI version observations | Separate Windows diagnostic sessions dated 2026-11-03 recorded 6.0.2 in the build-environment assessment and 6.1.4 in this later audit. These observations differ and neither confirms engine operation. |
| `podman version` | The later session displayed CLI 6.1.4, then failed to connect because it could not read the machine SSH identity (Access denied). |
| `podman info` | Exit 1; reports Windows/amd64, provider WSL, and the same identity access failure. Engine details and rootless status unavailable. |
| `podman machine list` | Exit 1 before inventory; Podman reports it cannot create `C:\Users\Admin\.config` because a file already exists at that path. No change was attempted. |
| `podman system connection list` | Succeeded. `podman-machine-default-root` is the configured default and points to `root@127.0.0.1`; the non-root machine connection is not default. Do not switch connections or start the machine as part of this audit. |
| Container smoke test | NOT TESTED. The engine is unreachable and default connection is rootful; no image was pulled or container created. |
| Registry reachability | DNS resolved for `ghcr.io`, `registry-1.docker.io`, and `archive.archlinux.org`; direct TCP/443 checks failed. Registry access through a proxy/runtime was not tested. |
| WSL | `wsl.exe --list --quiet` still returns `Wsl/EnumerateDistros/Service/E_ACCESSDENIED`; Linux tools cannot be run in the reported WSL distro from this host session. |
| Build tools | `python3` resolves only to a Windows Store execution alias and fails with Permission denied; `make`, Nix, Archiso, QEMU, ShellCheck, Ruff, Pyright, yamllint, markdownlint, and check-jsonschema are unavailable on the Windows PATH. |

## Checks that executed

- `git status`, branch inspection, and `git diff --check`: passed. Git emitted only line-ending conversion warnings for modified text files.
- Git Bash `bash -n` across all 13 shell scripts under `scripts/` and `experiments/`: passed.
- PowerShell parser check for `inspect-windows-host.ps1`: passed. The script was then run with a process-scoped `-ExecutionPolicy Bypass` (persistent scopes were previously confirmed `Undefined`); it returned exit 0 and printed all sections while individual protected checks reported access denied. No host configuration changed.
- PowerShell JSON parsing for the schema and eight JSON fixtures: passed. This checks JSON syntax only, not schema conformance.
- Repository validation: required-file checks and shell syntax passed, then stopped at Python compilation because the WindowsApps `python3` executable returned Permission denied.
- Direct Nix artifact-helper smoke testing in Git Bash was attempted, but the Windows filesystem symlink created by `ln -s` was not recognized by Bash as a symlink (`-L` false). The Linux symlink-based unit cases are therefore NOT TESTED on this host.
- On PR head `681eed2ed313eed8ef613b6a1c306cd561eaec6f`, [Validate #21](https://github.com/Chitrank-Dixit/AtherOS/actions/runs/41693563477) and [Lint #21](https://github.com/Chitrank-Dixit/AtherOS/actions/runs/41693563501) both passed. Validate passed repository validation and lightweight unit tests. Lint passed Ruff, Pyright, ShellCheck, Markdown lint, YAML, and JSON Schema validation. This evidence is PR-head CI only; it does not establish post-merge CI or local Windows/WSL results.
- Arch/Nix ISO builds and UEFI boots: BLOCKED / NOT TESTED; no suitable builder, reviewed Nix lock, generated ISO, or disposable UEFI test environment is available.

## Acceptance criteria

| ID | Status | Audit evidence |
| --- | --- | --- |
| AC-01 Host diagnostics work | PASSED | Script produced a report in a process-scoped PowerShell invocation; restricted checks reported their errors independently. |
| AC-02 Builder architecture documented | PASSED | Architecture document exists; no build backend has been validated. |
| AC-03 Arch profile validates | NOT TESTED | No Archiso environment. |
| AC-04 Arch ISO builds | BLOCKED | No reachable isolated Linux builder or Archiso. |
| AC-05 Nix flake is locked | BLOCKED | `experiments/nixos/flake.lock` is ABSENT; Nix is unavailable. |
| AC-06 NixOS ISO builds | BLOCKED | Depends on a generated/reviewed lock and isolated Nix builder. |
| AC-07 Arch ISO boots in UEFI VM | BLOCKED | No ISO or available disposable UEFI VM. |
| AC-08 NixOS ISO boots in UEFI VM | BLOCKED | No ISO or available disposable UEFI VM. |
| AC-09 Experiment schema validates | PASSED | Draft 2020-12 validation passed in [Validate #21](https://github.com/Chitrank-Dixit/AtherOS/actions/runs/41693563477) and [Lint #21](https://github.com/Chitrank-Dixit/AtherOS/actions/runs/41693563501) on the latest reviewed PR head. |
| AC-10 CI checks pass | PASSED | Both latest PR-triggered workflows, [Validate #21](https://github.com/Chitrank-Dixit/AtherOS/actions/runs/41693563477) and [Lint #21](https://github.com/Chitrank-Dixit/AtherOS/actions/runs/41693563501), passed. Post-merge CI is not verified. |
| AC-11 Results are documented | PASSED | `sprint-0.1-results.md` and this audit summarize current observations and explicitly mark unavailable checks. |

## Security and architectural assessment

The wrappers correctly refuse remote/rootful Podman and do not start existing machines. Arch and NixOS ISO builds remain BLOCKED / NOT TESTED; `experiments/nixos/flake.lock` is ABSENT. Arch and NixOS UEFI boot tests remain BLOCKED / NOT TESTED. Desktop compatibility, rootless Podman runtime, nested namespace support, physical NVIDIA validation, and operational update/recovery testing are NOT TESTED. The live ISO harness attaches no disk, and no privileged container or host socket is requested. The Nix wrapper fails closed instead of disabling sandboxing. Container images, nested namespaces, artifact mounts, and Nix sandbox execution have not been exercised; do not describe these paths as verified. The base distribution decision remains NOT DECIDED and requires human approval.

## Review-remediation implementation and verification

- Optional experiment properties are now checked against required and allowed keys, with actual Draft 2020-12 validation. The pinned validator is shared by CI and report generation; validation passed in both relevant CI paths at the reviewed commit.
- Nix artifact discovery recursively finds regular ISO files under the resolved result symlink, rejects targets outside `/nix/store`, requires exactly one artifact, and records its relative path. The Validate workflow's unit tests passed at the reviewed commit.
- Arch container preparation requires a digest-pinned official base image with a tag date matching the Archive date. It uses `pacman -Sy --needed`, records the mixed bootstrap/snapshot limitation, and separates build, artifact, checksum, and package-manifest status. Missing or incomplete manifests fail evidence validation.
- Nix build records capture failure stages. UEFI records leave all guest milestones NOT TESTED until an operator verifies them; QEMU exit status does not imply boot success.
- Architecture and Podman guide references now point to ADR-007.
- Ruff's I001 import-order issue in `scripts/experiments/arch_build_result.py` was corrected; Ruff passed in Lint #21 on PR head `681eed2ed313eed8ef613b6a1c306cd561eaec6f`.

The CI statements above apply to the pre-merge PR head `681eed2ed313eed8ef613b6a1c306cd561eaec6f`. PR #1 is merged at `a2d00306ac941aa2676e0069cc7c3a1df772c833`; no post-merge CI result is claimed. Local Windows Python and Ruff execution remain unavailable or inaccessible; passing CI is not a local validation result. ISO builds and UEFI boot tests remain BLOCKED/NOT TESTED.
