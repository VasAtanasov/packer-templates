# Makefile for Packer Vagrant Box Building

SHELL := /bin/bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help

# Colors for output
GREEN  := \033[0;32m
YELLOW := \033[0;33m
RED    := \033[0;31m
RESET  := \033[0m

# Directories
TEMPLATE_DIR := packer_templates
PKRVARS_DIR  := os_pkrvars
BUILDS_DIR   := builds

# Minimum versions
PACKER_MIN_VER ?= 1.7.0
VBOX_MIN_VER   ?= 7.1.6

# Find all .pkrvars.hcl files
PKRVARS_FILES := $(shell find $(PKRVARS_DIR) -name "*.pkrvars.hcl" 2>/dev/null | sort)

# Build configuration
PROVIDERS ?= virtualbox-iso.vm

##@ General

.PHONY: help
help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make $(GREEN)<target>$(RESET)\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  $(GREEN)%-15s$(RESET) %s\n", $$1, $$2 } /^##@/ { printf "\n$(YELLOW)%s$(RESET)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Validation

.PHONY: validate
validate: ## Validate all Packer templates
	@echo -e "$(GREEN)Validating all Packer templates...$(RESET)\n"
	@for template in $(PKRVARS_FILES); do \
		template_dir=$$(dirname $$template); \
		filename=$$(basename $$template); \
		echo -e "\n$(GREEN)Validating $$template$(RESET)\n"; \
		(cd $$template_dir && packer validate -var-file=$$filename ../../$(TEMPLATE_DIR)) || { \
			echo -e "$(RED)Validation failed for $$template$(RESET)"; \
			exit 1; \
		}; \
	done
	@echo -e "\n$(GREEN)All templates validated successfully!$(RESET)"

.PHONY: validate-one
validate-one: ## Validate a single template (usage: make validate-one TEMPLATE=debian/debian-12-x86_64.pkrvars.hcl)
ifndef TEMPLATE
	@echo -e "$(RED)Error: TEMPLATE variable not set$(RESET)"
	@echo "Usage: make validate-one TEMPLATE=debian/debian-12-x86_64.pkrvars.hcl"
	@exit 1
endif
	@template_path=$(PKRVARS_DIR)/$(TEMPLATE); \
	template_dir=$$(dirname $$template_path); \
	filename=$$(basename $$template_path); \
	echo -e "$(GREEN)Validating $$template_path$(RESET)\n"; \
	(cd $$template_dir && packer validate -var-file=$$filename ../../$(TEMPLATE_DIR))

##@ Building

.PHONY: init
init: ## Initialize Packer plugins
	@echo -e "$(GREEN)Initializing Packer plugins...$(RESET)"
	@cd $(TEMPLATE_DIR) && packer init .

.PHONY: build
build: init ## Build a specific box (usage: make build TEMPLATE=debian/debian-12-x86_64.pkrvars.hcl)
ifndef TEMPLATE
	@echo -e "$(RED)Error: TEMPLATE variable not set$(RESET)"
	@echo "Usage: make build TEMPLATE=debian/debian-12-x86_64.pkrvars.hcl"
	@exit 1
endif
	@template_path=$(PKRVARS_DIR)/$(TEMPLATE); \
	template_dir=$$(dirname $$template_path); \
	filename=$$(basename $$template_path); \
	echo -e "$(GREEN)Building box from $$template_path$(RESET)\n"; \
	(cd $$template_dir && packer build \
		-var-file=$$filename \
		-only=$(PROVIDERS) \
		../../$(TEMPLATE_DIR))

.PHONY: build-all
build-all: init ## Build all boxes
	@echo -e "$(GREEN)Building all boxes...$(RESET)\n"
	@for template in $(PKRVARS_FILES); do \
		template_dir=$$(dirname $$template); \
		filename=$$(basename $$template); \
		echo -e "\n$(GREEN)Building $$template$(RESET)\n"; \
		(cd $$template_dir && packer build \
			-var-file=$$filename \
			-only=$(PROVIDERS) \
			../../$(TEMPLATE_DIR)) || { \
			echo -e "$(RED)Build failed for $$template$(RESET)"; \
			exit 1; \
		}; \
	done
	@echo -e "\n$(GREEN)All boxes built successfully!$(RESET)"

.PHONY: force-build
force-build: clean build ## Clean and rebuild

##@ Cleaning

.PHONY: clean
clean: ## Remove build artifacts
	@echo -e "$(YELLOW)Cleaning build artifacts...$(RESET)"
	@if [ -d "$(BUILDS_DIR)" ]; then \
		echo "Removing $(BUILDS_DIR)/*"; \
		rm -rf $(BUILDS_DIR)/*; \
	fi
	@echo -e "$(GREEN)Clean complete$(RESET)"

.PHONY: clean-cache
clean-cache: ## Remove Packer cache
	@echo -e "$(YELLOW)Removing Packer cache...$(RESET)"
	@rm -rf packer_cache/
	@echo -e "$(GREEN)Cache cleaned$(RESET)"

.PHONY: clean-all
clean-all: clean clean-cache ## Remove all build artifacts and cache

##@ Inspection

.PHONY: list-templates
list-templates: ## List all available templates
	@echo -e "$(GREEN)Available templates:$(RESET)"
	@for template in $(PKRVARS_FILES); do \
		echo "  - $${template#$(PKRVARS_DIR)/}"; \
	done

.PHONY: list-builds
list-builds: ## List all built boxes
	@if [ -d "$(BUILDS_DIR)/build_complete" ]; then \
		echo -e "$(GREEN)Built boxes:$(RESET)"; \
		find $(BUILDS_DIR)/build_complete -name "*.box" -exec basename {} \; 2>/dev/null | sort || echo "No boxes found"; \
	else \
		echo -e "$(YELLOW)No builds found$(RESET)"; \
	fi

.PHONY: inspect
inspect: ## Inspect a template (usage: make inspect TEMPLATE=debian/debian-12-x86_64.pkrvars.hcl)
ifndef TEMPLATE
	@echo -e "$(RED)Error: TEMPLATE variable not set$(RESET)"
	@echo "Usage: make inspect TEMPLATE=debian/debian-12-x86_64.pkrvars.hcl"
	@exit 1
endif
	@template_path=$(PKRVARS_DIR)/$(TEMPLATE); \
	template_dir=$$(dirname $$template_path); \
	filename=$$(basename $$template_path); \
	echo -e "$(GREEN)Inspecting $$template_path$(RESET)\n"; \
	(cd $$template_dir && packer inspect \
		-var-file=$$filename \
		../../$(TEMPLATE_DIR))

##@ Quick Builds (Debian)

.PHONY: debian-12
debian-12: ## Build Debian 12 x86_64 base box
	@$(MAKE) build TEMPLATE=debian/debian-12-x86_64.pkrvars.hcl

.PHONY: debian-12-arm
debian-12-arm: ## Build Debian 12 aarch64 base box
	@$(MAKE) build TEMPLATE=debian/debian-12-aarch64.pkrvars.hcl

.PHONY: debian-12-k8s
debian-12-k8s: ## Build Debian 12 x86_64 Kubernetes node box
	@$(MAKE) build TEMPLATE=debian/debian-12-x86_64-k8s-node.pkrvars.hcl

.PHONY: debian-12-arm-k8s
debian-12-arm-k8s: ## Build Debian 12 aarch64 Kubernetes node box
	@$(MAKE) build TEMPLATE=debian/debian-12-aarch64-k8s-node.pkrvars.hcl

.PHONY: debian-12-docker
debian-12-docker: ## Build Debian 12 x86_64 Docker host box
	@$(MAKE) build TEMPLATE=debian/debian-12-x86_64-docker-host.pkrvars.hcl

.PHONY: debian-12-arm-docker
debian-12-arm-docker: ## Build Debian 12 aarch64 Docker host box
	@$(MAKE) build TEMPLATE=debian/debian-12-aarch64-docker-host.pkrvars.hcl

.PHONY: debian-13
debian-13: ## Build Debian 13 x86_64 base box
	@$(MAKE) build TEMPLATE=debian/debian-13-x86_64.pkrvars.hcl

.PHONY: debian-13-arm
debian-13-arm: ## Build Debian 13 aarch64 base box
	@$(MAKE) build TEMPLATE=debian/debian-13-aarch64.pkrvars.hcl

##@ Development

.PHONY: debug
debug: ## Show debug information
	@echo -e "$(GREEN)Packer Configuration Debug Info$(RESET)"
	@echo "TEMPLATE_DIR: $(TEMPLATE_DIR)"
	@echo "PKRVARS_DIR:  $(PKRVARS_DIR)"
	@echo "BUILDS_DIR:   $(BUILDS_DIR)"
	@echo "PROVIDERS:    $(PROVIDERS)"
	@echo ""
	@echo -e "$(GREEN)Packer version:$(RESET)"
	@packer version || echo "Packer not found in PATH"
	@echo ""
	@echo -e "$(GREEN)VBoxManage version:$(RESET)"
	@VBoxManage --version || echo "VBoxManage not found in PATH"

.PHONY: check-env
check-env: ## Check environment and dependencies
	@echo -e "$(GREEN)Checking environment...$(RESET)"
	@command -v packer >/dev/null 2>&1 || { echo -e "$(RED)Error: packer not found$(RESET)"; exit 1; }
	@command -v VBoxManage >/dev/null 2>&1 || { echo -e "$(RED)Error: VBoxManage not found (required for VirtualBox builds)$(RESET)"; exit 1; }
	@[ -d "$(TEMPLATE_DIR)" ] || { echo -e "$(RED)Error: $(TEMPLATE_DIR) directory not found$(RESET)"; exit 1; }
	@[ -d "$(PKRVARS_DIR)" ] || { echo -e "$(RED)Error: $(PKRVARS_DIR) directory not found$(RESET)"; exit 1; }
	@# Version checks (fail early)
	@pv=$$(packer version | sed -n 's/.*v\([0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' | head -n1); \
		if [ -z "$$pv" ]; then echo -e "$(RED)Error: unable to parse Packer version$(RESET)"; exit 1; fi; \
		if [ "$$pv" = "$$(printf '%s\n%s\n' "$$pv" "$(PACKER_MIN_VER)" | sort -V | tail -n1)" ]; then :; else \
		  echo -e "$(RED)Error: Packer $$pv < required $(PACKER_MIN_VER)$(RESET)"; exit 1; fi
	@vv=$$(VBoxManage --version 2>/dev/null | sed -E 's/^([0-9]+\.[0-9]+\.[0-9]+).*$/\1/'); \
		if [ -z "$$vv" ]; then echo -e "$(RED)Error: unable to parse VirtualBox version$(RESET)"; exit 1; fi; \
		if [ "$$vv" = "$$(printf '%s\n%s\n' "$$vv" "$(VBOX_MIN_VER)" | sort -V | tail -n1)" ]; then :; else \
		  echo -e "$(RED)Error: VirtualBox $$vv < required $(VBOX_MIN_VER)$(RESET)"; exit 1; fi
	@echo -e "$(GREEN)Environment check passed!$(RESET)"
