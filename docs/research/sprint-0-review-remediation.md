# Sprint 0 review remediation

**Date:** 2026-11-03  
**Status:** Local workspace changes prepared; pull request blocked by GitHub write permissions.

## Review findings and response

### P0 — Markdown lint and CI independence

The failed main-branch Lint run reported 31 MD022 heading-spacing errors in 12 files. The remediation inserts blank lines after the affected headings; it does not rewrite or remove their existing Markdown text. The markdownlint configuration now excludes generated `out/`, `build/`, `dist/`, `result/`, `result-*`, and `.git/` paths.

The lint workflow separates Markdown, Ruff, Pyright, ShellCheck, YAML, and JSON Schema validation into independent jobs. A failure in one job no longer skips the other checks, while each failed job still contributes a failing overall workflow result. All jobs use read-only repository permissions and no secrets. ShellCheck is installed from the Ubuntu runner package repository rather than through an action.

The failed run logged a Node.js 20 deprecation warning for `actions/checkout@v4` and `actions/setup-node@v4`. The current official releases were checked: checkout v7.0.1, setup-node v7.1.0, and setup-python v7.1.0 all declare the Node 24 runtime. The workflows use those versions. The separate npm `punycode` deprecation warning came from the earlier run's Node/npm tooling and was not itself an Actions runtime warning.

### P1 — NixOS lock

**BLOCKED.** No disposable Linux/Nix environment was available. No `flake.lock` was generated or invented, and the flake was not evaluated or built. The tested nixpkgs revision is **none**. The existing ISO target continues to require a reviewed lock before building.

### P1 — Arch profiles and outputs

The existing minimal Archiso profile remains independent. A separate GNOME package experiment profile is added with its package choices documented. It is explicitly a package-composition scaffold; no GNOME session result is claimed. The build wrapper requires a disposable-VM acknowledgement and VM detection, writes profile-specific outputs, and records SHA-256 and SHA-512 manifests after a successful build. Neither profile has been built or booted.

### P1 — Experiment record examples

The schema now requires OS revision and package revision fields. Fixtures cover all four statuses using recorded evidence: the existing environment blocker, the earlier passing repository-validation workflow, the failed Markdown workflow, and the unperformed physical NVIDIA check. CI validates every fixture against the schema. These records do not imply that the remediation itself has passed CI.

### P1/P2 — Licensing and report generation

The MIT license text is unchanged. A licensing note clarifies its scope for original Aether contributions and that upstream packages/assets retain their own licenses and attribution requirements; future ISO distribution needs an inventory and corresponding notices. Report automation is deferred: the current helper prints a manually authored report, and the documentation describes a later deterministic record summary while preserving human analysis and withholding scores where evidence is missing.

## Validation status

The original failing CI run provides the precise MD022 list and confirms that later serial lint steps were skipped. The earlier main-branch Validate workflow completed successfully, but neither run validates these remediation changes.

Local `make validate`, `make test`, Ruff, Pyright, ShellCheck, markdownlint, yamllint, and schema checks have **not been run** on the changed files. The command runner fails during setup refresh, and GitHub rejected creation of the requested branch with HTTP 403 (`Resource not accessible by integration`). Therefore no remediation branch or PR was created.
