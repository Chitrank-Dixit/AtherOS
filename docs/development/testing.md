# Testing and validation

## Development dependencies

Install the pinned JSON Schema validator before running the Python tests or record checks:

```bash
python3 -m pip install -r requirements-dev.txt
make test
make validate-records
```

The record validator, report generator, unit tests, and CI fixture job all use the same Draft 2020-12 schema through `jsonschema`.

Podman security-profile and runtime-gate unit tests are included in `make test`. Their evidence boundaries are documented in the [Sprint 0.3 Podman security profile report](sprint-0.3-podman-security.md).

## Repository checks

`make validate` checks required structure and available Bash/Python/JSON syntax, then validates experiment fixtures and machine-readable experiment results. `make test` runs Python `unittest` cases for repository tooling, record validation, snapshot inputs, artifact discovery, and Podman security-profile/runtime gates. CI runs these checks plus Ruff, Pyright, ShellCheck, markdownlint, and yamllint without secrets.

## Experiment evidence

For every experiment record: environment, exact commands, configuration/revision, expected outcome, actual outcome, evidence location, and limitations. A prerequisite check is not an experiment result. Use `BLOCKED` when an external dependency prevents the test and `NOT TESTED` when no attempt was made.

## Required scenario coverage

- UEFI boot and clean install for each candidate ISO.
- GNOME, Plasma, and Hyprland login/logout/reboot plus service checks, including co-install and switch-back.
- Network, audio, portals, lock, notifications, screenshots, and monitor behavior.
- NixOS declared rebuild, activation, generation selection, and rollback.
- Arch upgrade, partial-upgrade avoidance, package signature, snapshot, and recovery workflow.
- Physical NVIDIA behavior is separate from virtual graphics and requires a live USB plus explicit approval.
