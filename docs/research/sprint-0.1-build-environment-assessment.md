# Sprint 0.1 — Build environment assessment and implementation specification

**Assessment date:** 2026-11-03  
**Target branch:** `research/build-environment`  
**Branch revision observed remotely:** `0068f38c4774ea4247ae1073929e0dc989373699` (same as `main` at assessment)  
**Follow-up worktree status:** `research/build-environment`, tracking `origin/research/build-environment`, with the documented modifications and untracked implementation files preserved. No changes have been made to `main`.

## Objective and constraints

Sprint 0.1 creates a safe, evidence-producing build and UEFI test process for Arch and NixOS. It does not select a base distribution or claim full binary reproducibility. Host setup, VM creation, disk formatting, builds, boot testing, and cleanup remain separate operations. This document is the implementation specification; implementation should follow it in the order below.

## Existing capabilities

- Arch has a minimal package profile and separate GNOME package experiment profile. Its build wrapper requires `AETHER_ARCHISO_DISPOSABLE=1`, checks for Arch and VM detection, writes per-profile output, and emits SHA-256/SHA-512 files.
- NixOS exposes minimal, desktop, developer-tool, and native `isoImage` configurations. Its build wrapper requires a generated `flake.lock`; none exists.
- Experiment records already have `PASSED`, `FAILED`, `BLOCKED`, and `NOT TESTED` examples, and CI validates them against a JSON Schema.
- Pull-request CI already runs separate Markdown, Ruff, Pyright, ShellCheck, YAML, and JSON Schema jobs. The latest observed main-branch Validate and Lint runs succeeded; these are not evidence for Sprint 0.1 build or boot behavior.
- Existing Sprint 0 reports explicitly state that no Arch/NixOS image or VM was built or booted.

## Gaps and blockers

- No read-only Windows host or Linux builder diagnostic script exists.
- Arch builds do not currently require or record a dated Arch Linux Archive snapshot, Archiso version, full package manifest, complete build log, or structured metadata. Hash files alone are insufficient evidence.
- Nix has no lock file. Nix evaluation and ISO build remain BLOCKED until an isolated Linux/Nix builder is available; no lock may be fabricated.
- No UEFI/QEMU test harness or boot evidence exists. A VM detection result and a successful image build do not prove that a VM is disposable or that an ISO boots.
- The result schema lacks explicit distribution revision, builder, build/boot outcomes, checksum, firmware, VM allocation, log, and blocker fields.
- No manual build workflows or Sprint 0.1 architecture/build/boot guides exist.
- Current diagnostics were not run for this assessment. Existing Windows findings in the Sprint 0 report are historical and must be refreshed by the new diagnostic utility.
- The local Git status could not be inspected through the agent runner. Preserve any user changes and inspect `git status` before modifying existing files in the WSL checkout.

## Backend assessment

| Backend | Candidate use | Limitation / safety boundary |
|---|---|---|
| WSL2 | Linux shell/build tooling if already working | Uses a managed Linux VM and interoperates with Windows files; do not use the user's persistent distro as a disposable builder or assume UEFI guest boot is available. No WSL configuration changes. |
| Podman machine | Isolated Linux builder VM where already installed | Windows Podman requires a managed VM; machine creation and disk lifecycle require explicit user action. Containers alone are not guest boot tests. |
| Docker | Containerized profile/schema/tool checks | Docker Desktop's Linux backend is a VM, but containers are not UEFI guests. Do not install or configure Docker automatically. |
| QEMU + OVMF | Preferred UEFI boot-test candidate on an approved Linux builder | Requires installed QEMU and firmware; use only newly created qcow2 disks in a disposable VM. Never attach physical disks or host EFI partitions. |
| Hyper-V | Possible Windows-host VM backend | Availability and policy are unknown; enabling features or creating VMs is out of scope without explicit approval. |
| VMware / VirtualBox | Possible externally managed VM backend | Availability is unknown; no installation or host configuration is allowed by this sprint automation. |
| GitHub Actions | Fast validation and optional manual ISO build jobs | Build success does not prove boot; do not assume nested virtualization. Build jobs should be manual/controlled until cost and reliability are known. |

Podman and Docker are suitable for reproducible tooling containers, not by themselves for UEFI boot acceptance. QEMU/OVMF is the initial boot-test implementation only when already available in a disposable Linux environment. No backend is installed or enabled by these scripts.

## Follow-up host evidence (2026-11-03)

- Windows host diagnostics ran and emitted a report. CIM and Hyper-V queries returned access denied; WSL enumeration returned `E_ACCESSDENIED`. The script did not change host settings.
- Podman CLI 6.0.2 is installed. `podman info`/`podman version` cannot reach the engine because access to the machine identity is denied. `podman machine list` fails while attempting to create `C:\Users\Admin\.config`, where a file already exists. The successful read-only connection listing shows the root machine connection as default. No machine/connection was started or edited. Rootless behavior and container execution remain unverified.
- DNS resolves for `ghcr.io`, `registry-1.docker.io`, and `archive.archlinux.org`; direct TCP/443 checks failed. No image pull was attempted.
- Git Bash shell syntax, PowerShell parser, JSON syntax, and `git diff --check` ran successfully. Repository validation reached Python compilation and stopped because the WindowsApps Python alias returned Permission denied. See `sprint-0.1-implementation-audit.md` for acceptance statuses.

## Implementation specification

1. **Assessment and diagnostics:** keep Windows PowerShell and Linux shell inspectors read-only, with per-check error isolation, sanitized output, capability versus working-state distinctions, and optional report output paths. Do not print usernames, full environment blocks, serial numbers, or secrets.
2. **Arch build:** require an explicit disposable acknowledgement, VM signal as an additional check, and an explicit dated ALA snapshot. Supply that snapshot through a generated temporary pacman configuration passed with `mkarchiso -C`. Capture the full command output, tool versions, exact installed package manifest, Git revision, ISO size, and hashes in a structured build record. Preserve minimal and GNOME profiles as separate inputs. Do not claim byte-for-byte reproducibility.
3. **NixOS build:** require a reviewed flake lock, record locked nixpkgs revision, Nix version, system architecture, configuration revision, build log, ISO size, and hashes. Generate the lock only with Nix in a suitable isolated environment. Keep flake evaluation and image build as separately reportable operations.
4. **UEFI test:** require an explicit disposable-test acknowledgement before creating any VM disk. Default only to a new qcow2 path that does not already exist; never overwrite or delete an existing disk. Use QEMU with OVMF if present, capture serial/boot logs and the exact ISO hash, firmware path/version, CPU/memory allocation, and test timestamp. Boot testing must not be part of image build scripts. Cleanup is a separate documented, user-confirmed operation.
5. **Records and reports:** extend the schema compatibly, require status-specific evidence/blocker explanations, and validate every fixture in CI. Generate summaries only from schema-valid records; leave editorial analysis manual, deterministic, and without scores when evidence is missing.
6. **CI:** keep fast PR validation separate from manual/controlled Arch and Nix build workflows. Give each job minimal read permissions, do not use secrets, and report image build separately from UEFI boot.

## Files to change or add

- Change `experiments/arch/scripts/build-iso.sh`, Arch profile documentation, `experiments/nixos/scripts/build-iso.sh`, and NixOS experiment documentation.
- Change `schemas/experiment-record.schema.json`, all experiment fixtures, and unit/schema validation.
- Change or add `.github/workflows/` jobs for manual builds; keep existing fast lint/validation jobs.
- Add `scripts/environment/inspect-windows-host.ps1` and `scripts/environment/inspect-linux-builder.sh`.
- Add `scripts/experiments/` metadata/report helpers and a separate UEFI boot-test script only if its safety checks can be validated without running it against user data.
- Add `docs/architecture/build-environment.md`, guides under `docs/guides/`, and `docs/research/sprint-0.1-results.md`.

## Validation and acceptance policy

Run each static check independently and record skipped versus failed outcomes. Do not run a host setup step, ISO build, VM creation, disk format, or cleanup as part of diagnostics. A Nix lock is accepted only if generated by Nix and its revision inspected. Build and boot are separate statuses. Sprint 0.1 remains incomplete while critical build or boot evidence is BLOCKED or NOT TESTED.
