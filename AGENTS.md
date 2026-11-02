# AGENTS.md — Aether Linux

## Project Identity

Aether Linux is a modular, developer-focused Linux distribution.

Philosophy: Your system. Your way.

The project prioritizes user choice, modularity, reproducibility, security and maintainability.

## Engineering Principles

1. Follow specifications before implementation.
2. Do not make undocumented architectural decisions.
3. Prefer modular components and clear interfaces.
4. Preserve distribution independence at product-layer boundaries.
5. Keep desktop integrations isolated.
6. Keep AI capabilities optional.
7. Preserve user configuration.
8. Use declarative configuration wherever practical.
9. Write tests for meaningful functionality.
10. Document implementation and operational procedures.

## Technology Principles

- Arch Linux and NixOS are the initial base candidates.
- GNOME, KDE Plasma and Hyprland are supported desktop targets.
- System Studio will be a graphical management application.
- Tauri, React, TypeScript and Rust are the proposed System Studio stack.
- Python is the proposed AI runtime language.
- Podman is the preferred developer container runtime.

Do not treat proposed technology selections as final unless an ADR has accepted them.

## Security

- Never execute unrestricted commands as root.
- Never run destructive host operations without explicit approval.
- Never modify host bootloaders or partitions without explicit approval.
- Keep secrets outside source control.
- Validate external inputs.
- Use least privilege.
- Maintain auditability for privileged operations.
- Do not use `sudo` on the host without explicit approval for a specific operation.
- Keep VM experiments in disposable guests. Physical validation requires explicit approval.

## Testing

- Do not fabricate test results.
- Report failures accurately.
- Distinguish unit, integration, VM and physical hardware testing.
- Document environmental limitations.
- Never treat a successful ISO build as proof that it boots.
- Never treat VM graphics testing as proof of NVIDIA compatibility.
- Mark unavailable evidence `NOT TESTED` or `BLOCKED`; never imply it passed.

## Documentation

Maintain:

- README.md
- ROADMAP.md
- Architecture documentation
- Architecture Decision Records
- Research reports
- Testing instructions
- Security documentation

Every major architectural change requires an ADR proposal. Keep documentation synchronized with implementation.

## Git

Use Conventional Commits.

Do not publish releases or create tags without approval.

Do not modify public repository settings without approval.

## Agent Behavior

Work autonomously on routine implementation tasks inside the repository and disposable test environments.

Before major changes:

1. Inspect existing code.
2. Identify affected components.
3. Explain the proposed implementation.
4. Implement incrementally.
5. Run tests.
6. Review changes.

Never silently change product requirements.

If a specification is ambiguous, document the ambiguity and choose the safest reversible implementation rather than inventing a product decision.

## Sprint 0 project-specific rules

- Sprint 0 establishes feasibility; it does not implement a complete operating system or commit the project to Arch or NixOS.
- Do not modify the host OS, host WSL configuration, partitions, or bootloader. Do not install another OS on the primary machine.
- Build ISO images only in suitable isolated Linux builders. A build is not a boot test.
- Record experiment environment, exact commands, configuration/revisions, expected and actual outcome, evidence, and limitations.
- Prefer the standard library and avoid unnecessary dependencies. Keep developer and AI profiles independent.
- Validate and document the existing implementation before making architectural changes.
- The final base distribution selection requires human approval.
