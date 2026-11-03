SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c

.PHONY: help validate validate-arch validate-nixos build-arch-iso build-nixos-iso validate-records podman-env-check podman-prepare-arch podman-prepare-nixos podman-build-arch-iso podman-build-nixos-iso test

help: ## Show available targets
	@grep -E '^[a-zA-Z0-9_-]+:.*## ' $(MAKEFILE_LIST) | sed 's/:.*## /\t/'

validate: ## Validate repository structure and available source syntax
	@bash scripts/validate-repository.sh

validate-arch: ## Check Arch experiment prerequisites without changing the host
	@bash scripts/validate-environment.sh arch

validate-nixos: ## Check NixOS experiment prerequisites without changing the host
	@bash scripts/validate-environment.sh nixos

build-arch-iso: ## Build minimal Arch ISO (disposable Linux VM, ack, and pinned archive date required)
	@bash experiments/arch/scripts/build-iso.sh

build-nixos-iso: ## Build NixOS ISO (disposable Linux VM, ack, Nix flakes, and reviewed lock required)
	@bash experiments/nixos/scripts/build-iso.sh

validate-records: ## Validate experiment records and schema fixtures
	@python3 scripts/experiments/validate-records.py

podman-env-check: ## Read-only check for a usable local rootless Podman runtime
	@bash scripts/podman/check-runtime.sh --require-local-rootless

podman-prepare-arch: ## Prepare Archiso builder (ARCHIVE_DATE and digest-pinned ARCH_BASE_IMAGE required)
	@test -n "$(ARCHIVE_DATE)" -a -n "$(ARCH_BASE_IMAGE)" || { echo 'Set ARCHIVE_DATE=YYYY/MM/DD and ARCH_BASE_IMAGE=archlinux/archlinux:<dated-tag>@sha256:<digest>.' >&2; exit 2; }
	@bash scripts/podman/prepare-builders.sh arch "$(ARCHIVE_DATE)" "$(ARCH_BASE_IMAGE)"

podman-prepare-nixos: ## Pull the digest-pinned Nix builder image
	@bash scripts/podman/prepare-builders.sh nixos

podman-build-arch-iso: ## Build Arch ISO in rootless Podman (set acknowledgements and snapshot)
	@bash scripts/podman/run-build.sh arch "$(PROFILE)"

podman-build-nixos-iso: ## Build NixOS ISO in rootless Podman with sandbox fallback disabled
	@bash scripts/podman/run-build.sh nixos

test: validate ## Run repository validation and standard-library unit tests
	@command -v python3 >/dev/null 2>&1 || { echo 'ERROR: Python 3 is required for unit tests.' >&2; exit 1; }
	@python3 -m unittest discover -s tests/unit -v
