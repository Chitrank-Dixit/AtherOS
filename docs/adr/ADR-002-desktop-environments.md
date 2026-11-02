# ADR-002: Desktop environments

- **Status:** Proposed for validation

## Context and proposal

Aether's product requirement is GNOME, KDE Plasma, and Hyprland, with one primary session at install and the ability to add another later. Evaluate GDM and SDDM rather than assuming they are interchangeable. Test co-installation and preserve the chosen primary session across reboot.

## Evidence and decision

No desktop session has been tested in the current environment. The compatibility matrix is maintained in `docs/research/desktop-compatibility.md`. Accept a concrete desktop packaging strategy only after the matrix has evidence on the selected base.
