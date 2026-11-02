SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c

.PHONY: help validate validate-arch validate-nixos build-arch-iso build-nixos-iso test

help: ## Show available targets
	@grep -E '^[a-zA-Z0-9_-]+:.*## ' $(MAKEFILE_LIST) | sed 's/:.*## /\t/'

validate: ## Validate repository structure and available source syntax
	@bash scripts/validate-repository.sh

validate-arch: ## Check Arch experiment prerequisites without changing the host
	@bash scripts/validate-environment.sh arch

validate-nixos: ## Check NixOS experiment prerequisites without changing the host
	@bash scripts/validate-environment.sh nixos

build-arch-iso: ## Build an Arch ISO from the checked-in profile (requires Linux and archiso)
	@bash experiments/arch/scripts/build-iso.sh

build-nixos-iso: ## Build the native NixOS ISO (requires Nix with flakes)
	@bash experiments/nixos/scripts/build-iso.sh

test: validate ## Run repository validation and standard-library unit tests
	@command -v python3 >/dev/null 2>&1 || { echo 'ERROR: Python 3 is required for unit tests.' >&2; exit 1; }
	@python3 -m unittest discover -s tests/unit -v
