# Roadmap

## Sprint 0 — Foundation and feasibility

- Establish contribution, security, architecture, and validation practices.
- Evaluate Arch and NixOS with disposable VMs, ISO builds, desktop sessions, update behavior, and recovery.
- Research NVIDIA support and compare maintenance costs.
- Publish an evidence-based base distribution proposal for human review.

Current limitation: VM and ISO experiments are blocked in the present environment. See [the Sprint 0 report](docs/research/sprint-0-report.md).

## Sprint 1 — After base review

Subject to Sprint 0 evidence and approval: define a small end-to-end distribution prototype, validate its image build in CI or a disposable Linux builder, and refine adapter and configuration boundaries. Defer production repository infrastructure and a full installer until the base decision.
