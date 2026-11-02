# Sprint 0.1 implementation audit

**Audit date:** 2026-11-03  
**Branch:** `research/build-environment`  
**Worktree:** existing changes preserved; no commit, push, merge, reset, or cleanup performed.

## Summary

The working tree contains substantial Sprint 0.1 implementation artifacts, including Arch/Nix build wrappers, diagnostics, a QEMU live-ISO harness, experiment records, documentation, and Podman builders. These artifacts have not established successful ISO builds or boots. The host has a Podman CLI, but the existing Podman machine is unreachable and its configured default is a root connection. Rootless mode and container execution are therefore unverified. No Podman machine, connection, image, volume, or container was modified.

The checked-out branch is `research/build-environment` and tracks `origin/research/build-environment`. The worktree has tracked modifications in `.github/workflows/lint.yml`, `AGENTS.md`, `Makefile`, `README.md`, ADR/research indexes, Arch/Nix READMEs and build scripts, the experiment schema, repository validation, and the original experiment fixture. Untracked additions are under `docs/adr`, `docs/architecture`, `docs/guides`, `docs/research`, `docs/security`, `experiments/containers`, `scripts/environment`, `scripts/experiments`, `scripts/podman`, `tests/fixtures/experiment-records`, plus `tests/unit/test_experiment_records.py`. All were retained.

## Implemented functionality

- **Arch experiment:** minimal and desktop-GNOME profiles remain separate. The wrapper requires a disposable acknowledgement and dated Arch Archive snapshot, creates timestamped output, writes an isolated pacman configuration, logs `mkarchiso`, records Archiso/Git/builder details, captures package versions when available, and emits SHA-256/SHA-512 checksums.
- **NixOS experiment:** the wrapper requires Nix, Python, Linux, a disposable acknowledgement, a VM signal (or the explicit Podman wrapper marker), and `flake.lock`. It records Nix/flakes metadata and locked nixpkgs revision, separates evaluation from build, captures logs and checksums, and keeps sandboxing enabled with sandbox fallback disabled.
- **Podman:** separate Arch and Nix OCI Containerfiles exist. Runtime checks require local rootless Podman and check subordinate IDs and user namespaces. Build wrappers mount source read-only and a separate artifact directory read-write, drop container capabilities, set no-new-privileges, avoid host sockets and Compose, record Podman/image details, and use `--rm` only for their own temporary build container.
- **UEFI:** a QEMU/OVMF live-ISO harness records ISO and firmware hashes, resources, QEMU logs, and serial logs. It creates no virtual disk; it does not itself establish that the observed guest reached each requested boot milestone.
- **Records and reporting:** the JSON Schema adds build/boot, distribution, checksum, firmware, VM, logs, and blocker fields with status conditions. There are examples for each status. CI's `check-jsonschema` job lists those fixtures. A deterministic report helper excludes explicitly synthetic fixtures.
- **Documentation:** architecture, build, UEFI, Podman, licensing, assessment, feasibility, and results documents exist. ADR-001 still leaves the base distribution unselected; the Podman runtime decision is documented as accepted.

## Findings and gaps

1. **Resolved during this audit — ADR identifier collision:** `ADR-002-desktop-environments.md` already exists. The Podman decision now uses `ADR-007-container-runtime.md`, and the new references point to ADR-007.
2. **Resolved during this audit — README placement:** the Sprint 0.1 links are integrated in the existing “Start here” list; no duplicate title was retained.
3. **Resolved during this audit — stale status reports:** this audit and the results report now reflect the checked-out branch, current Windows diagnostic output, and current Podman/WSL access failures.
4. **Report validation is weaker than its name implies:** `scripts/experiments/validate-records.py` implements a partial handwritten contract check, not general JSON Schema validation. `generate-results-report.py` relies on that partial checker, so it may accept a record rejected by Draft 2020-12 schema validation. CI does run `check-jsonschema` on its explicit fixture list, but the report generator should not imply arbitrary input has passed that validator.
5. **Resolved during this audit — Nix result-link collision:** the Nix wrapper now refuses an existing output directory or result-link path before writing.
6. **Remaining implementation gap — failure metadata:** Arch writes failure metadata; Nix metadata/evaluation failures have partial stage markers, while a few early failures (including missing ISO output) do not yet produce a complete normalized experiment record. Preserve logs and fix this before treating build evidence as fully machine-readable.
7. **Podman does not run its own investigation checks:** the repository check script verifies the engine, rootless flag, remote flag, subordinate IDs, and namespace probes; the requested Windows read-only diagnostics separately query machine state. The current command-line connection and engine results below are current host observations, not evidence that the Linux builder wrappers work.
8. **CI build lane is absent:** fast validation remains split across independent lint jobs. No manual Podman ISO-build workflow is present. The documentation correctly treats runner Podman/nested namespace support as unverified; build/boot CI must not be represented as passing.
9. **Nix lock and result evidence are absent:** `experiments/nixos/flake.lock` does not exist. No Nix toolchain is available in the current shell environment, so a lock must not be generated or guessed.

## Current environment diagnostics

All listed Podman commands were read-only.

| Check | Result |
| --- | --- |
| `podman version` | CLI 6.0.2 is installed; exit 1 because the engine could not read the machine SSH identity (`C:\Users\Admin\.local\share\containers\podman\machine\machine`: Access denied). |
| `podman info` | Exit 1; reports Windows/amd64, provider WSL, and the same identity access failure. Engine details and rootless status unavailable. |
| `podman machine list` | Exit 1 before inventory; Podman reports it cannot create `C:\Users\Admin\.config` because a file already exists at that path. No change was attempted. |
| `podman system connection list` | Succeeded. `podman-machine-default-root` is the configured default and points to `root@127.0.0.1`; the non-root machine connection is not default. Do not switch connections or start the machine as part of this audit. |
| Container smoke test | NOT TESTED. The engine is unreachable and default connection is rootful; no image was pulled or container created. |
| Registry reachability | DNS resolved for `ghcr.io`, `registry-1.docker.io`, and `archive.archlinux.org`; direct TCP/443 checks failed. Registry access through a proxy/runtime was not tested. |
| WSL | `wsl.exe --list --quiet` still returns `Wsl/EnumerateDistros/Service/E_ACCESSDENIED`; Linux tools cannot be run in the reported WSL distro from this host session. |
| Build tools | `python3` resolves only to a Windows Store execution alias and fails with Permission denied; `make`, Nix, Archiso, QEMU, ShellCheck, Ruff, Pyright, yamllint, markdownlint, and check-jsonschema are unavailable on the Windows PATH. |

## Checks that executed

- `git status`, branch inspection, and `git diff --check`: passed. Git emitted only line-ending conversion warnings for modified text files.
- Git Bash `bash -n` across 12 shell scripts: passed.
- PowerShell parser check for `inspect-windows-host.ps1`: passed. The script was then run with a process-scoped `-ExecutionPolicy Bypass` (persistent scopes were previously confirmed `Undefined`); it returned exit 0 and printed all sections while individual protected checks reported access denied. No host configuration changed.
- PowerShell JSON parsing for the schema and eight JSON fixtures: passed. This checks JSON syntax only, not schema conformance.
- Repository validation: required-file checks and shell syntax passed, then stopped at Python compilation because the WindowsApps `python3` executable returned Permission denied.
- Unit tests, actual JSON Schema validation, Markdown lint, Ruff, Pyright, ShellCheck, yamllint, ISO builds, and VM boots: NOT TESTED because their required tools or engine are unavailable.

## Acceptance criteria

| ID | Status | Audit evidence |
| --- | --- | --- |
| AC-01 Host diagnostics work | PASSED | Script produced a report in a process-scoped PowerShell invocation; restricted checks reported their errors independently. |
| AC-02 Builder architecture documented | PASSED | Architecture document exists; no build backend has been validated. |
| AC-03 Arch profile validates | NOT TESTED | No Archiso environment. |
| AC-04 Arch ISO builds | BLOCKED | No reachable isolated Linux builder or Archiso. |
| AC-05 Nix flake is locked | BLOCKED | `flake.lock` absent and Nix unavailable. |
| AC-06 NixOS ISO builds | BLOCKED | Depends on a generated/reviewed lock and isolated Nix builder. |
| AC-07 Arch ISO boots in UEFI VM | BLOCKED | No ISO or available disposable UEFI VM. |
| AC-08 NixOS ISO boots in UEFI VM | BLOCKED | No ISO or available disposable UEFI VM. |
| AC-09 Experiment schema validates | NOT TESTED | JSON syntax parsed; schema validator could not run. |
| AC-10 CI checks pass | NOT TESTED | No CI run was triggered for the working tree. |
| AC-11 Results are documented | PASSED | `sprint-0.1-results.md` and this audit summarize current observations and explicitly mark unavailable checks. |

## Security and architectural assessment

The wrappers correctly refuse remote/rootful Podman and do not start existing machines. The live ISO harness attaches no disk, and no privileged container or host socket is requested. The Nix wrapper fails closed instead of disabling sandboxing. Container images, nested namespaces, artifact mounts, or Nix sandbox execution have not been exercised; do not describe these paths as verified. Continue using an explicitly disposable Linux VM when rootless namespace or sandbox requirements fail. The base distribution remains unresolved and requires human approval.
