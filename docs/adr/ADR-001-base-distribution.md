# ADR-001: Base distribution

- **Status:** Proposed; no base selected
- **Date:** 2026-11-03
- **Decision owners:** Project owner and maintainers

## Context
Aether requires selectable GNOME, KDE Plasma, and Hyprland sessions; broad developer tooling; optional AI; predictable updates; usable recovery; reproducible image generation; and an adapter boundary that can support more than one base. Arch and NixOS are candidates. The required VM and ISO experiments have not run in the current environment.

## Options
- **Arch Linux:** conventional mutable package management, broad developer ecosystem, rolling releases; requires Aether to engineer image composition, package-set promotion, and recovery integration.
- **NixOS:** declarative system configuration, generations and rollback, reproducible package-set selection; requires user education and careful integration with imperative workflows and hardware-specific configuration.

## Proposal
No recommendation is made from the current evidence. Complete the weighted evaluation in `docs/research/base-distribution-decision.md`, run both candidates in disposable UEFI VMs, and review the evidence. A final selection requires human approval.

## Consequences and review
Until experiments complete, keep product boundaries distribution-neutral and avoid irreversible architecture choices. Revisit after verified ISO/VM tests, desktop matrix, NVIDIA research, update/recovery comparison, and a maintenance-cost estimate.
