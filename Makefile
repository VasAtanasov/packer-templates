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
TEMPLATE_DIR_BASE := packer_templates
PKRVARS_DIR       := os_pkrvars
BUILDS_DIR        := builds

# Default provider and OS
PROVIDER  ?= virtualbox
TARGET_OS ?= debian

# Default Kubernetes version for k8s-node variant
K8S_VERSION ?= 1.33

# Minimum versions
PACKER_MIN_VER ?= 1.7.0
VBOX_MIN_VER   ?= 7.1.6

# Find all .pkrvars.hcl files for current TARGET_OS
PKRVARS_FILES := $(shell find $(PKRVARS_DIR)/$(TARGET_OS) -name "*.pkrvars.hcl" 2>/dev/null | sort)

# Build configuration
PROVIDERS ?= virtualbox-iso.vm

##@ General

.PHONY: help
help: ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make $(GREEN)<target>$(RESET)\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  $(GREEN)%-15s$(RESET) %s\n", $$1, $$2 } /^##@/ { printf "\n$(YELLOW)%s$(RESET)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Validation

.PHONY: validate
validate: ## Validate all Packer templates for current provider/OS
	@echo -e "$(GREEN)Validating $(PROVIDER)/$(TARGET_OS) templates...$(RESET)\n"
	@template_dir=$(TEMPLATE_DIR_BASE); \
	for var_file in $(PKRVARS_FILES); do \
		echo -e "\n$(GREEN)Validating with $$var_file$(RESET)\n"; \
		packer validate -syntax-only -var-file=$$var_file $$template_dir || { \
			echo -e "$(RED)Validation failed for $$var_file$(RESET)"; \
			exit 1; \
		}; \
	done
	@echo -e "\n$(GREEN)All templates validated successfully!$(RESET)"

.PHONY: validate-all
validate-all: ## Validate templates for all OSes under os_pkrvars
	@for dir in $(PKRVARS_DIR)/*/; do \
		os=$$(basename $$dir); \
		echo -e "\n$(GREEN)=== Validating $$os ===$(RESET)\n"; \
		$(MAKE) validate TARGET_OS=$$os || exit 1; \
	done

.PHONY: validate-one
validate-one: ## Validate a single template (usage: make validate-one TEMPLATE=debian/12-x86_64.pkrvars.hcl)
ifndef TEMPLATE
	@echo -e "$(RED)Error: TEMPLATE variable not set$(RESET)"
	@echo "Usage: make validate-one TEMPLATE=debian/12-x86_64.pkrvars.hcl"
	@exit 1
endif
	@template_dir=$(TEMPLATE_DIR_BASE); \
	var_file=$(PKRVARS_DIR)/$(TEMPLATE); \
	echo -e "$(GREEN)Validating with $$var_file$(RESET)\n"; \
	packer validate -syntax-only -var-file=$$var_file $$template_dir

##@ Building

.PHONY: init
init: ## Initialize Packer plugins
	@echo -e "$(GREEN)Initializing Packer plugins...$(RESET)"
	@cd $(TEMPLATE_DIR_BASE) && packer init .

.PHONY: build
build: init ## Build a specific box (usage: make build TEMPLATE=debian/12-x86_64.pkrvars.hcl [VARIANT=k8s-node])
ifndef TEMPLATE
	@echo -e "$(RED)Error: TEMPLATE variable not set$(RESET)"
	@echo "Usage: make build TEMPLATE=debian/12-x86_64.pkrvars.hcl [VARIANT=k8s-node]"
	@exit 1
endif
	@template_dir=$(TEMPLATE_DIR_BASE); \
	var_file=$(PKRVARS_DIR)/$(TEMPLATE); \
	extra_vars=""; \
	if [ -n "$(VARIANT)" ]; then \
		extra_vars="-var=variant=$(VARIANT)"; \
		if [ "$(VARIANT)" = "k8s-node" ]; then \
			extra_vars="$$extra_vars -var=kubernetes_version=$(K8S_VERSION) -var=cpus=2 -var=memory=4096 -var=disk_size=61440"; \
		fi; \
	fi; \
	if [ -n "$(PRIMARY_SOURCE)" ]; then \
		extra_vars="$$extra_vars -var=primary_source=$(PRIMARY_SOURCE)"; \
	fi; \
	if [ -n "$(OVF_SOURCE_PATH)" ]; then \
		extra_vars="$$extra_vars -var=ovf_source_path=$(OVF_SOURCE_PATH)"; \
	fi; \
	if [ -n "$(OVF_CHECKSUM)" ]; then \
		extra_vars="$$extra_vars -var=ovf_checksum=$(OVF_CHECKSUM)"; \
	fi; \
	echo -e "$(GREEN)Building from $$var_file$(RESET)"; \
	if [ -n "$(VARIANT)" ]; then echo -e "$(YELLOW)Variant: $(VARIANT)$(RESET)"; fi; \
	packer build \
		-var-file=$$var_file \
		$$extra_vars \
		$$template_dir

.PHONY: ovf-clean
ovf-clean: init ## Build a clean OVF (no provisioners) for quick testing (usage: make ovf-clean TEMPLATE=debian/12-x86_64.pkrvars.hcl)
ifndef TEMPLATE
	@echo -e "$(RED)Error: TEMPLATE variable not set$(RESET)"
	@echo "Usage: make ovf-clean TEMPLATE=debian/12-x86_64.pkrvars.hcl"
	@exit 1
endif
	@template_dir=$(TEMPLATE_DIR_BASE); \
	var_file=$(PKRVARS_DIR)/$(TEMPLATE); \
	echo -e "$(GREEN)Building CLEAN OVF from $$var_file (no provisioners)$(RESET)"; \
	packer build \
		-var=skip_provisioners=true \
		-var-file=$$var_file \
		$$template_dir

.PHONY: build-all
build-all: init ## Build all boxes for current TARGET_OS
	@echo -e "$(GREEN)Building all boxes for $(TARGET_OS)...$(RESET)\n"
	@template_dir=$(TEMPLATE_DIR_BASE); \
	failed=0; \
	for var_file in $(PKRVARS_FILES); do \
		echo -e "\n$(GREEN)Building $$var_file$(RESET)\n"; \
		packer build -var-file=$$var_file $$template_dir || { \
			echo -e "$(RED)Build failed for $$var_file$(RESET)"; \
			failed=1; \
		}; \
	done; \
	if [ $$failed -eq 0 ]; then \
		echo -e "\n$(GREEN)All boxes built successfully!$(RESET)"; \
	else \
		echo -e "\n$(RED)Some builds failed$(RESET)"; \
		exit 1; \
	fi

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
inspect: ## Inspect a template (usage: make inspect TEMPLATE=debian/12-x86_64.pkrvars.hcl)
ifndef TEMPLATE
	@echo -e "$(RED)Error: TEMPLATE variable not set$(RESET)"
	@echo "Usage: make inspect TEMPLATE=debian/12-x86_64.pkrvars.hcl"
	@exit 1
endif
	@template_dir=$(TEMPLATE_DIR_BASE); \
	var_file=$(PKRVARS_DIR)/$(TEMPLATE); \
	echo -e "$(GREEN)Inspecting with $$var_file$(RESET)\n"; \
	packer inspect -var-file=$$var_file $$template_dir

##@ Quick Builds (VirtualBox + Debian)

.PHONY: debian-12
debian-12: ## Build Debian 12 x86_64 base box
	@$(MAKE) build TEMPLATE=debian/12-x86_64.pkrvars.hcl

.PHONY: debian-12-k8s
debian-12-k8s: ## Build Debian 12 x86_64 Kubernetes node box
	@$(MAKE) build TEMPLATE=debian/12-x86_64.pkrvars.hcl VARIANT=k8s-node

.PHONY: debian-12-k8s-ovf
debian-12-k8s-ovf: ## Build Debian 12 x86_64 Kubernetes node box from existing OVF
	@var_file=$(PKRVARS_DIR)/debian/12-x86_64.pkrvars.hcl; \
	os_version=$$(sed -n 's/^\s*os_version\s*=\s*"\(.*\)".*/\1/p' $$var_file | head -n1); \
	ovf_dir="ovf/packer-debian-$${os_version}-x86_64-virtualbox"; \
	ovf_path="$$ovf_dir/debian-$${os_version}-x86_64.ovf"; \
	$(MAKE) build TEMPLATE=debian/12-x86_64.pkrvars.hcl VARIANT=k8s-node PRIMARY_SOURCE=virtualbox-ovf OVF_SOURCE_PATH="$$ovf_path" OVF_CHECKSUM=none

.PHONY: debian-12-ovf
debian-12-ovf: ## Build Debian 12 x86_64 base box from existing OVF
	@var_file=$(PKRVARS_DIR)/debian/12-x86_64.pkrvars.hcl; \
	os_version=$$(sed -n 's/^\s*os_version\s*=\s*"\(.*\)".*/\1/p' $$var_file | head -n1); \
	ovf_dir="ovf/packer-debian-$${os_version}-x86_64-virtualbox"; \
	ovf_path="$$ovf_dir/debian-$${os_version}-x86_64.ovf"; \
	$(MAKE) build TEMPLATE=debian/12-x86_64.pkrvars.hcl VARIANT=base PRIMARY_SOURCE=virtualbox-ovf OVF_SOURCE_PATH="$$ovf_path" OVF_CHECKSUM=none

.PHONY: debian-12-docker
debian-12-docker: ## Build Debian 12 x86_64 Docker host box
	@$(MAKE) build TEMPLATE=debian/12-x86_64.pkrvars.hcl VARIANT=docker-host

.PHONY: debian-12-docker-ovf
debian-12-docker-ovf: ## Build Debian 12 x86_64 Docker host box from existing OVF
	@var_file=$(PKRVARS_DIR)/debian/12-x86_64.pkrvars.hcl; \
	os_version=$$(sed -n 's/^\s*os_version\s*=\s*"\(.*\)".*/\1/p' $$var_file | head -n1); \
	ovf_dir="ovf/packer-debian-$${os_version}-x86_64-virtualbox"; \
	ovf_path="$$ovf_dir/debian-$${os_version}-x86_64.ovf"; \
	$(MAKE) build TEMPLATE=debian/12-x86_64.pkrvars.hcl VARIANT=docker-host PRIMARY_SOURCE=virtualbox-ovf OVF_SOURCE_PATH="$$ovf_path" OVF_CHECKSUM=none

.PHONY: debian-13
debian-13: ## Build Debian 13 x86_64 base box
	@$(MAKE) build TEMPLATE=debian/13-x86_64.pkrvars.hcl

.PHONY: debian-13-docker
debian-13-docker: ## Build Debian 13 x86_64 Docker host box
	@$(MAKE) build TEMPLATE=debian/13-x86_64.pkrvars.hcl VARIANT=docker-host

##@ Quick Builds (VirtualBox + AlmaLinux)

.PHONY: almalinux-9
almalinux-9: ## Build AlmaLinux 9 x86_64 base box
	@$(MAKE) build TEMPLATE=almalinux/9-x86_64.pkrvars.hcl PROVIDER=virtualbox TARGET_OS=almalinux

##@ Development

.PHONY: debug
debug: ## Show debug information
	@echo -e "$(GREEN)Packer Configuration Debug Info$(RESET)"
	@echo "TEMPLATE_DIR_BASE: $(TEMPLATE_DIR_BASE)"
	@echo "PROVIDER:          $(PROVIDER)"
	@echo "TARGET_OS:         $(TARGET_OS)"
	@echo "Template Dir:      $(TEMPLATE_DIR_BASE)"
	@echo "PKRVARS_DIR:       $(PKRVARS_DIR)"
	@echo "BUILDS_DIR:        $(BUILDS_DIR)"
	@echo "K8S_VERSION:       $(K8S_VERSION)"
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
	@[ -d "$(TEMPLATE_DIR_BASE)" ] || { echo -e "$(RED)Error: $(TEMPLATE_DIR_BASE) directory not found$(RESET)"; exit 1; }
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

.PHONY: vbox-export
vbox-export: ## Export a registered VirtualBox VM to OVA (usage: make vbox-export TEMPLATE=debian/12-x86_64.pkrvars.hcl [VARIANT=k8s-node])
ifndef TEMPLATE
	@echo -e "$(RED)Error: TEMPLATE variable not set$(RESET)"
	@echo "Usage: make vbox-export TEMPLATE=debian/12-x86_64.pkrvars.hcl [VARIANT=k8s-node]"
	@exit 1
endif
	@var_file=$(PKRVARS_DIR)/$(TEMPLATE); \
	os_name=$$(sed -n 's/^\s*os_name\s*=\s*"\(.*\)".*/\1/p' $$var_file | head -n1); \
	os_version=$$(sed -n 's/^\s*os_version\s*=\s*"\(.*\)".*/\1/p' $$var_file | head -n1); \
	os_arch=$$(sed -n 's/^\s*os_arch\s*=\s*"\(.*\)".*/\1/p' $$var_file | head -n1); \
	k8s_version="$(K8S_VERSION)"; \
	variant_env="$(VARIANT)"; \
	variant_file=$$(sed -n 's/^\s*variant\s*=\s*"\(.*\)".*/\1/p' $$var_file | head -n1); \
	variant=$${variant_env:-$${variant_file:-base}}; \
	base_box_name="$$os_name-$$os_version-$$os_arch"; \
	if [ "$$variant" = "base" ] || [ -z "$$variant" ]; then \
		box_name="$$base_box_name"; \
	elif [ "$$variant" = "k8s-node" ]; then \
		box_name="$$base_box_name-$$variant-$$k8s_version"; \
	else \
		box_name="$$base_box_name-$$variant"; \
	fi; \
	out_dir=$(BUILDS_DIR)/build_complete; \
	mkdir -p "$$out_dir"; \
	if VBoxManage showvminfo "$$box_name" >/dev/null 2>&1; then \
		echo -e "$(GREEN)Exporting $$box_name to $$out_dir/$$box_name.ova$(RESET)"; \
		VBoxManage export "$$box_name" --output "$$out_dir/$$box_name.ova"; \
		echo -e "$(GREEN)Export complete: $$out_dir/$$box_name.ova$(RESET)"; \
	else \
		echo -e "$(RED)VM '$$box_name' not found or not registered.$(RESET)"; \
		echo -e "$(YELLOW)Build with -var=vbox_keep_registered=true, then run this target.$(RESET)"; \
		exit 1; \
	fi

.PHONY: vagrant-add
vagrant-add: ## Add a built box to local Vagrant (usage: make vagrant-add TEMPLATE=debian/12-x86_64.pkrvars.hcl [VARIANT=k8s-node] [BOX_ALIAS=name])
ifndef TEMPLATE
	@echo -e "$(RED)Error: TEMPLATE variable not set$(RESET)"
	@echo "Usage: make vagrant-add TEMPLATE=debian/12-x86_64.pkrvars.hcl [VARIANT=k8s-node] [BOX_ALIAS=name]"
	@exit 1
endif
	@var_file=$(PKRVARS_DIR)/$(TEMPLATE); \
	os_name=$$(sed -n 's/^\s*os_name\s*=\s*"\(.*\)".*/\1/p' $$var_file | head -n1); \
	os_version=$$(sed -n 's/^\s*os_version\s*=\s*"\(.*\)".*/\1/p' $$var_file | head -n1); \
	os_arch=$$(sed -n 's/^\s*os_arch\s*=\s*"\(.*\)".*/\1/p' $$var_file | head -n1); \
	k8s_version="$(K8S_VERSION)"; \
	variant_env="$(VARIANT)"; \
	variant_file=$$(sed -n 's/^\s*variant\s*=\s*"\(.*\)".*/\1/p' $$var_file | head -n1); \
	variant=$${variant_env:-$${variant_file:-base}}; \
	base_box_name="$$os_name-$$os_version-$$os_arch"; \
	if [ "$$variant" = "base" ] || [ -z "$$variant" ]; then \
		box_name="$$base_box_name"; \
	elif [ "$$variant" = "k8s-node" ]; then \
		box_name="$$base_box_name-$$variant-$$k8s_version"; \
	else \
		box_name="$$base_box_name-$$variant"; \
	fi; \
	box_path="$(BUILDS_DIR)/build_complete/$$box_name.virtualbox.box"; \
	if [ ! -f "$$box_path" ]; then \
		echo -e "$(RED)Box file not found: $$box_path$(RESET)"; \
		exit 1; \
	fi; \
	box_alias="$(BOX_ALIAS)"; \
	if [ -z "$$box_alias" ]; then \
		box_alias="$$box_name"; \
	fi; \
	echo -e "$(GREEN)Adding box '$$box_alias' from $$box_path$(RESET)"; \
	vagrant box add --name "$$box_alias" "$$box_path"

.PHONY: vagrant-metadata
vagrant-metadata: ## Generate Vagrant metadata JSON (usage: make vagrant-metadata TEMPLATE=debian/12-x86_64.pkrvars.hcl [VARIANT=k8s-node] [BOX_NAME=name] [BOX_VERSION=version])
ifndef TEMPLATE
	@echo -e "$(RED)Error: TEMPLATE variable not set$(RESET)"
	@echo "Usage: make vagrant-metadata TEMPLATE=debian/12-x86_64.pkrvars.hcl [VARIANT=k8s-node] [BOX_NAME=name] [BOX_VERSION=version]"
	@exit 1
endif
	@var_file=$(PKRVARS_DIR)/$(TEMPLATE); \
	os_name=$$(sed -n 's/^\s*os_name\s*=\s*"\(.*\)".*/\1/p' $$var_file | head -n1); \
	os_version=$$(sed -n 's/^\s*os_version\s*=\s*"\(.*\)".*/\1/p' $$var_file | head -n1); \
	os_arch=$$(sed -n 's/^\s*os_arch\s*=\s*"\(.*\)".*/\1/p' $$var_file | head -n1); \
	k8s_version="$(K8S_VERSION)"; \
	variant_env="$(VARIANT)"; \
	variant_file=$$(sed -n 's/^\s*variant\s*=\s*"\(.*\)".*/\1/p' $$var_file | head -n1); \
	variant=$${variant_env:-$${variant_file:-base}}; \
	base_box_name="$$os_name-$$os_version-$$os_arch"; \
	if [ "$$variant" = "base" ] || [ -z "$$variant" ]; then \
		box_name="$$base_box_name"; \
		meta_name="$(BOX_NAME)"; \
		if [ -z "$$meta_name" ]; then meta_name="$$box_name"; fi; \
		meta_version="$(BOX_VERSION)"; \
		if [ -z "$$meta_version" ]; then meta_version="0"; fi; \
	elif [ "$$variant" = "k8s-node" ]; then \
		box_name="$$base_box_name-$$variant-$$k8s_version"; \
		meta_name="$(BOX_NAME)"; \
		if [ -z "$$meta_name" ]; then meta_name="$$base_box_name-$$variant"; fi; \
		meta_version="$(BOX_VERSION)"; \
		if [ -z "$$meta_version" ]; then meta_version="$$k8s_version"; fi; \
	else \
		box_name="$$base_box_name-$$variant"; \
		meta_name="$(BOX_NAME)"; \
		if [ -z "$$meta_name" ]; then meta_name="$$box_name"; fi; \
		meta_version="$(BOX_VERSION)"; \
		if [ -z "$$meta_version" ]; then meta_version="0"; fi; \
	fi; \
	box_dir=$(BUILDS_DIR)/build_complete; \
	box_file="$$box_name.virtualbox.box"; \
	box_path="$$box_dir/$$box_file"; \
	if [ ! -f "$$box_path" ]; then \
		echo -e "$(RED)Box file not found: $$box_path$(RESET)"; \
		exit 1; \
	fi; \
	meta_path="$$box_dir/$$meta_name-$$meta_version.json"; \
	echo -e "$(GREEN)Writing Vagrant metadata to $$meta_path$(RESET)"; \
	printf '{\n  "name": "%s",\n  "versions": [\n    {\n      "version": "%s",\n      "providers": [\n        {\n          "name": "virtualbox",\n          "url": "%s"\n        }\n      ]\n    }\n  ]\n}\n' "$$meta_name" "$$meta_version" "$$box_file" > "$$meta_path"; \
	echo -e "$(GREEN)Metadata JSON written successfully$(RESET)"
