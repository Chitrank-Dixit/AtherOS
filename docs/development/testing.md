# Testing and validation

## Repository checks

`make validate` checks required structure and available Bash/Python/JSON syntax. `make test` runs standard-library unit tests for repository tooling and fixtures. CI runs these checks plus Ruff, Pyright, ShellCheck, markdownlint, yamllint, and JSON Schema validation without secrets.

## Experiment evidence

For every experiment record: environment, exact commands, configuration/revision, expected outcome, actual outcome, evidence location, and limitations. A prerequisite check is not an experiment result. Use `BLOCKED` when an external dependency prevents the test and `NOT TESTED` when no attempt was made.

## Required scenario coverage

- UEFI boot and clean install for each candidate ISO.
- GNOME, Plasma, and Hyprland login/logout/reboot plus service checks, including co-install and switch-back.
- Network, audio, portals, lock, notifications, screenshots, and monitor behavior.
- NixOS declared rebuild, activation, generation selection, and rollback.
- Arch upgrade, partial-upgrade avoidance, package signature, snapshot, and recovery workflow.
- Physical NVIDIA behavior is separate from virtual graphics and requires a live USB plus explicit approval.
