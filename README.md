# Aether Linux

**Your system. Your way.**

Aether is a modular, developer-focused Linux distribution exploring user choice across desktop environments, development profiles, and optional AI capabilities.

This repository is in **Sprint 0: Foundation and technical feasibility**. It evaluates Arch Linux and NixOS and records evidence before a base distribution is selected. No base distribution has been approved.

## Project status
- Repository foundation: initialized.
- Arch and NixOS VM/ISO experiments: blocked until a supported disposable Linux VM environment is available; see [the Sprint 0 report](docs/research/sprint-0-report.md).
- Desktop and physical NVIDIA validation: not tested.
- Base distribution: proposal pending experiments and human approval.

## Start here
- [Product vision](docs/product/vision.md)
- [Architecture overview](docs/architecture/overview.md)
- [Developer setup](docs/development/getting-started.md)
- [Build environment](docs/development/build-environment.md)
- [Testing and validation](docs/development/testing.md)
- [Roadmap](ROADMAP.md)
- [Contributing](CONTRIBUTING.md)

## Quick commands
In a Linux environment with GNU Make and Bash:

```sh
make help
make validate
make validate-arch
make validate-nixos
make build-arch-iso
make build-nixos-iso
make test
```

Build targets fail with a prerequisite explanation when native tools are missing. They do not install tools, invoke `sudo`, or change host configuration. See [Arch experiment instructions](experiments/arch/README.md) and [NixOS experiments](experiments/nixos/README.md).

## Product direction
The long-term target includes GNOME, KDE Plasma, and Hyprland; independent developer profiles; optional AI features; and Aether Studio for declarative system management. Sprint 0 evaluates technical foundations without implementing those product features. See [scope](docs/product/scope.md) and [principles](docs/product/principles.md).
