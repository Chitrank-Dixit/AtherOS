# Getting started

## Prerequisites

Use a Linux environment with Bash and GNU Make for repository commands. Python 3 is optional for the report helper. Nix with flakes and Archiso are only needed for their respective build targets. Do not install host features as an implicit step.

## Validate

From the repository root, run `make help`, `make validate`, and `make test`. To inspect candidate-specific prerequisites, use `make validate-arch` or `make validate-nixos`.

## Experiments

Run candidate experiments only in disposable UEFI VMs. Follow [Arch](../../experiments/arch/README.md) and [NixOS](../../experiments/nixos/README.md) guides; record all outcomes in `docs/research/` and candidate `results/` directories.
