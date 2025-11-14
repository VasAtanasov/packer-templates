# DDD Plan: Packer Scripts Multi-OS Scalability Refactoring

**Project**: Packer Box Builder - Multi-OS/Provider/Variant Support
**Status**: Phase 1 - Planning Complete
**Version**: 1.0
**Date**: 2025-11-14

---

## Problem Statement

**What we're building**: Scalable packer script organization that supports multiple operating systems (Debian, RHEL, OpenSUSE), virtualization providers (VirtualBox, VMware, QEMU), and specialized variants (base, k8s-node, docker-host) without code duplication or hidden complexity.

**Why it matters**:
- **Maintainers**: Need to add RHEL/AlmaLinux and VMware support without refactoring entire codebase
- **Scalability**: Current structure breaks when variant scripts contain OS-specific package manager commands
- **Discoverability**: No clear way to know which OS/variant combinations are supported
- **Quality**: Avoid code duplication vs over-abstraction tension

**Current Problem**:
Variant scripts like `variants/k8s-node/install_kubernetes.sh` contain Debian-specific APT commands:
```bash
lib::ensure_apt_updated               # Debian only
lib::ensure_apt_key_from_url ...      # Debian only
lib::ensure_apt_source_file ...       # Debian only
```

These scripts fail silently or catastrophically on RHEL systems which use DNF/YUM instead of APT.

**User value**:
- **Transparent**: File structure = documentation (see exactly which OS/variant combos exist)
- **Incremental**: Add RHEL support to k8s-node without touching Debian implementation
- **Maintainable**: OS-specific scripts stay focused, common scripts stay generic
- **Discoverable**: `SUPPORTED.md` manifest explicitly lists capabilities

**Problem solved**: Enable packer to scale from single OS (Debian) to multi-OS (Debian + RHEL + OpenSUSE) without hidden complexity, code duplication, or breaking existing builds.

---

## Proposed Solution

### High-Level Approach

Implement **Option 1: OS-Specific Subdirectories within Variants** with clear separation:

```
variants/{variant}/
├── common/              # OS-agnostic scripts (networking, kernel config)
├── debian/              # Debian/Ubuntu APT-based scripts
├── rhel/                # RHEL/AlmaLinux DNF-based scripts
├── opensuse/            # OpenSUSE Zypper-based scripts (future)
└── SUPPORTED.md         # Explicit capability matrix
```

**Core Insight**:
- **What varies**: Package installation, repository setup, OS-specific tooling
- **What's common**: Kernel configuration, service management, file operations
- **How to select**: Packer template uses `${var.os_family}` for dynamic script paths
- **How to validate**: Each variant has `SUPPORTED.md` listing tested OS combinations

### Incremental Delivery (Phases)

**Phase 1** (Restructure): Move k8s-node scripts into common/ and debian/ subdirectories (~1-2 hours)
**Phase 2** (Add RHEL): Implement RHEL-specific scripts for k8s-node (~2-4 hours)
**Phase 3** (Update Templates): Modify Packer template for dynamic OS-based selection (~1 hour)
**Phase 4** (Documentation): Create SUPPORTED.md manifests, update AGENTS.md (~1 hour)
**Phase 5** (Validation): Add capability discovery tooling, test matrix (~2-3 hours)

---

## Alternatives Considered

### Alternative 1: Default + Override Pattern

**Approach**: Keep scripts at `variants/k8s-node/*.sh`, add `_overrides/{os}/` for OS-specific logic

```
variants/k8s-node/
├── install_kubernetes.sh       # Default (Debian)
└── _overrides/
    └── rhel/
        └── install_kubernetes.sh   # RHEL override
```

**Pros**:
- Optimizes common case (most users use Debian)
- Less file duplication for OS-agnostic scripts
- Simpler for single-OS users

**Cons**:
- Hidden complexity (override mechanism not obvious)
- Harder to discover which OSes are supported
- Asymmetric (Debian is "default", others are "special")
- Violates transparency principle

**Decision**: ❌ Rejected - hidden logic violates ruthless simplicity

---

### Alternative 2: Shared Library + OS Implementations

**Approach**: Abstract ALL package operations into variant-specific libraries

```
variants/k8s-node/
├── install_kubernetes.sh       # Generic (calls lib functions only)
├── debian.lib.sh               # lib::k8s_install_debian()
└── rhel.lib.sh                 # lib::k8s_install_rhel()
```

**Pros**:
- Strongest abstraction (main script OS-agnostic)
- Reusable functions across variants
- Clearest separation of concerns

**Cons**:
- Highest indirection (3-layer: script → lib → OS lib)
- Harder to debug (function calls span 3 files)
- More complex for simple cases
- Violates "start minimal" principle

**Decision**: ❌ Rejected - over-abstraction for current needs

---

### Alternative 3: Explicit Support Matrix

**Approach**: Each variant explicitly lists supported OSes and fails fast

```
variants/k8s-node/
├── MATRIX.sh                   # Validates OS support, fails if unsupported
├── install-debian.sh           # Debian implementation
└── install-rhel.sh             # RHEL implementation
```

**Pros**:
- Fail-fast validation (clear error messages)
- Self-documenting (MATRIX.sh lists supported OSes)
- Explicit over implicit

**Cons**:
- More boilerplate (every variant needs MATRIX.sh)
- Runtime overhead (validation on every provisioner run)
- Duplicates information (MATRIX.sh + SUPPORTED.md)

**Decision**: ❌ Rejected - unnecessary runtime validation

---

### Alternative 4: OS-Specific Subdirectories (Chosen)

**Approach**: Explicit subdirectories within each variant

```
variants/k8s-node/
├── common/prepare.sh
├── debian/install_kubernetes.sh
├── rhel/install_kubernetes.sh
└── SUPPORTED.md
```

**Pros**:
- ✅ Transparent (file structure = documentation)
- ✅ Discoverable (ls variants/k8s-node/ shows supported OSes)
- ✅ Incremental (add rhel/ without touching debian/)
- ✅ Preserves library abstraction (generic ops still in lib-core.sh)
- ✅ Aligns with ruthless simplicity

**Cons**:
- More files (but clarity > brevity)
- Packer template complexity (dynamic path resolution)

**Decision**: ✅ **CHOSEN** - balances transparency, scalability, simplicity

**Mitigation**: Use clear Packer local variables for path construction

---

## Architecture & Design

### Key Interfaces (The "Studs")

#### 1. Variant Script Contract

**What**: Every variant script follows standard structure

**Contract**:
```bash
#!/usr/bin/env bash
set -o pipefail

# MUST source both libraries
source "${LIB_CORE_SH}"   # OS-agnostic helpers
source "${LIB_OS_SH}"     # OS-specific helpers (debian or rhel)

# MUST enable strict mode and traps
lib::strict
lib::setup_traps
lib::require_root

# MUST have main() function
main() {
    lib::header "Descriptive action"
    export DEBIAN_FRONTEND=noninteractive  # If OS-specific

    # Implementation here

    lib::success "Completed"
}

main "$@"
```

**Side Effects**:
- Installs packages
- Modifies system configuration
- Enables systemd services

**Dependencies**:
- `LIB_CORE_SH` environment variable
- `LIB_OS_SH` environment variable
- Root privileges

---

#### 2. OS Family Selection (Packer Template)

**What**: Packer dynamically selects scripts based on OS family

**Contract**:
```hcl
// Map OS names to OS families
locals {
  os_family_map = {
    debian    = "debian"
    ubuntu    = "debian"
    almalinux = "rhel"
    rocky     = "rhel"
    opensuse  = "opensuse"  // future
  }

  os_family = lookup(local.os_family_map, var.os_name, "unknown")

  variant_scripts = {
    "k8s-node" = [
      "variants/k8s-node/common/prepare.sh",
      "variants/k8s-node/common/configure_kernel.sh",
      "variants/k8s-node/${local.os_family}/install_container_runtime.sh",
      "variants/k8s-node/${local.os_family}/install_kubernetes.sh",
      "variants/k8s-node/common/configure_networking.sh",
    ]
  }
}
```

**Input**: `var.os_name` (debian, ubuntu, almalinux, rocky)
**Output**: `local.os_family` (debian, rhel, opensuse)
**Validation**: Fail if `os_family == "unknown"`

---

#### 3. Library Abstraction (Shared Helpers)

**What**: OS-agnostic operations remain in lib-core.sh, OS-specific in lib-{os}.sh

**Contract**:

**lib-core.sh** (OS-agnostic):
```bash
lib::log "message"              # Logging
lib::ensure_directory /path     # Create directories
lib::ensure_service name        # Enable+start systemd service
lib::ensure_file src dest       # Copy file with permissions
```

**lib-debian.sh** (Debian/APT-specific):
```bash
lib::ensure_apt_updated         # apt-get update (cached)
lib::ensure_packages pkg1 pkg2  # apt-get install
lib::ensure_apt_key_from_url url dest
lib::ensure_apt_source_file file line
```

**lib-rhel.sh** (RHEL/DNF-specific):
```bash
lib::ensure_yum_dnf_updated     # dnf makecache (cached)
lib::ensure_packages pkg1 pkg2  # dnf install
lib::ensure_yum_dnf_key_from_url url dest
lib::ensure_yum_dnf_repo_file file content
```

**Side Effects**: All modify system state
**Dependencies**: Root privileges, specific package manager present

---

#### 4. Capability Manifest (SUPPORTED.md)

**What**: Explicit documentation of supported OS/variant combinations

**Contract**:
```markdown
# variants/k8s-node/SUPPORTED.md

## Supported Operating Systems

| OS Family | Tested Versions | Status |
|-----------|----------------|--------|
| Debian    | 12 (Bookworm)  | ✅ Stable |
| RHEL      | AlmaLinux 9    | ✅ Stable |
| OpenSUSE  | TBD            | ⏳ Planned |

## Script Organization

- `common/`: OS-agnostic scripts (all OSes)
- `debian/`: Debian/Ubuntu APT-based scripts
- `rhel/`: RHEL/AlmaLinux DNF-based scripts
```

**Purpose**: Single source of truth for capability matrix

---

### Module Boundaries

**4 Tiers (Current Architecture)**:

#### Tier 1: `_common/` - Provider-Agnostic + OS-Family-Agnostic
- **Responsibility**: Scripts that work identically on all OSes and providers
- **Examples**: `update_packages.sh`, `sshd.sh`, `vagrant.sh`, `minimize.sh`
- **Libraries**:
  - `lib-core.sh` (OS-agnostic helpers)
  - `lib-debian.sh` (Debian/Ubuntu APT helpers)
  - `lib-rhel.sh` (RHEL/AlmaLinux DNF helpers)
- **Dependencies**: None (foundational tier)

#### Tier 2: `providers/{name}/` - Provider-Specific Integration
- **Responsibility**: Provider-specific drivers and guest tools
- **Examples**: `virtualbox/guest_additions.sh`, `vmware/tools.sh` (future)
- **Pattern**: Two-script approach (install_dependencies.sh + integration_script.sh)
- **Dependencies**: Tier 1 libraries

#### Tier 3: `{os}/` - OS-Specific Configuration
- **Responsibility**: OS-specific system configuration (not in variants)
- **Examples**: `debian/systemd.sh`, `debian/networking.sh`, `debian/cleanup.sh`
- **Dependencies**: Tier 1 libraries

#### Tier 4: `variants/{name}/` - Variant-Specific Provisioning (THE CHANGE)
- **Responsibility**: Specialized configurations on top of base box
- **Examples**: `k8s-node/`, `docker-host/`
- **NEW Structure**:
  ```
  variants/{name}/
  ├── common/        # OS-agnostic scripts
  ├── {os_family}/   # OS-specific scripts (debian, rhel, opensuse)
  └── SUPPORTED.md   # Capability matrix
  ```
- **Dependencies**: All tiers above

---

### Data Models

#### OS Family Mapping

**Purpose**: Map OS names to OS families for script selection

```hcl
// Input: var.os_name (from .pkrvars.hcl)
variable "os_name" {
  type        = string
  description = "Operating system name (debian, ubuntu, almalinux, rocky)"
}

// Mapping
locals {
  os_family_map = {
    debian    = "debian"
    ubuntu    = "debian"     // Ubuntu uses Debian scripts
    almalinux = "rhel"
    rocky     = "rhel"
    opensuse  = "opensuse"   // future
  }

  os_family = lookup(local.os_family_map, var.os_name, "unknown")
}

// Validation
locals {
  validate_os_family = local.os_family != "unknown" ? true : (
    local.os_family == "unknown" ?
    file("ERROR: Unsupported OS name: ${var.os_name}. Add to os_family_map.") :
    false
  )
}
```

#### Variant Script Paths

**Purpose**: Dynamically construct script paths based on OS family

```hcl
locals {
  variant_scripts = {
    "k8s-node" = [
      # Common scripts (all OSes)
      "variants/k8s-node/common/prepare.sh",
      "variants/k8s-node/common/configure_kernel.sh",

      # OS-specific scripts (dynamic)
      "variants/k8s-node/${local.os_family}/install_container_runtime.sh",
      "variants/k8s-node/${local.os_family}/install_kubernetes.sh",

      # Common scripts (all OSes)
      "variants/k8s-node/common/configure_networking.sh",
    ],

    "docker-host" = [
      # OS-specific (docker repo setup differs by OS)
      "variants/docker-host/${local.os_family}/install_docker.sh",
      "variants/docker-host/${local.os_family}/configure_docker.sh",
    ],
  }

  selected_variant_scripts = var.variant == "base" ? [] : lookup(local.variant_scripts, var.variant, [])
}
```

#### Library Path Mapping

**Purpose**: Map OS names to correct library file (already exists)

```hcl
locals {
  lib_os_sh = {
    debian    = "/usr/local/lib/k8s/scripts/_common/lib-debian.sh"
    ubuntu    = "/usr/local/lib/k8s/scripts/_common/lib-debian.sh"
    almalinux = "/usr/local/lib/k8s/scripts/_common/lib-rhel.sh"
    rocky     = "/usr/local/lib/k8s/scripts/_common/lib-rhel.sh"
  }
}
```

---

## Files to Change

### Non-Code Files (Phase 2 - Documentation)

#### Updated Documentation

- [ ] `ai_working/packer/AGENTS.md` - Update 4-tier organization to reflect OS-specific subdirs in variants
  - Add section: "Variant Organization with OS-Specific Subdirectories"
  - Update example structure diagrams
  - Document `os_family` concept

- [ ] `ai_working/packer/packer_templates/scripts/AGENTS.md` - Add variant pattern details
  - Section: "OS-Specific Scripts within Variants"
  - Update "Variant Pattern" section with subdirectory structure
  - Add examples of common/ vs debian/ vs rhel/ separation

#### New Documentation

- [ ] `ai_working/packer/packer_templates/scripts/variants/k8s-node/SUPPORTED.md` - Capability matrix
  - List tested OS versions (Debian 12, future RHEL)
  - Document script organization (common/, debian/, rhel/)
  - Note tested provider combinations (VirtualBox + Debian)

- [ ] `ai_working/packer/packer_templates/scripts/variants/docker-host/SUPPORTED.md` - Capability matrix
  - Same structure as k8s-node
  - Initially: Debian only

- [ ] `ai_working/packer/packer_templates/scripts/variants/README.md` - Overview of variant system
  - How variants work
  - How to add new OS support to existing variant
  - How to create new variant

---

### Code Files (Phase 4 - Implementation)

#### Phase 1: Restructure k8s-node (Debian only)

**Goal**: Separate OS-specific from OS-agnostic scripts without breaking existing Debian builds

**Scripts to Move → common/**:
- [ ] Move `variants/k8s-node/prepare.sh` → `variants/k8s-node/common/prepare.sh`
  - **Analysis**: Disables swap, loads kernel modules, configures sysctl
  - **Verdict**: OS-agnostic (uses lib-core.sh functions only)

- [ ] Move `variants/k8s-node/configure_kernel.sh` → `variants/k8s-node/common/configure_kernel.sh`
  - **Analysis**: Sets kernel parameters for Kubernetes
  - **Verdict**: OS-agnostic (sysctl is universal)

- [ ] Move `variants/k8s-node/configure_networking.sh` → `variants/k8s-node/common/configure_networking.sh`
  - **Analysis**: Configures network plugins, CNI
  - **Verdict**: OS-agnostic (network config is OS-independent)

**Scripts to Move → debian/**:
- [ ] Move `variants/k8s-node/install_container_runtime.sh` → `variants/k8s-node/debian/install_container_runtime.sh`
  - **Analysis**: Contains `lib::ensure_apt_updated`, `lib::ensure_apt_key_from_url`, `lsb_release`
  - **Verdict**: Debian-specific (APT commands, Debian version detection)

- [ ] Move `variants/k8s-node/install_kubernetes.sh` → `variants/k8s-node/debian/install_kubernetes.sh`
  - **Analysis**: Contains `lib::ensure_apt_key_from_url`, `lib::ensure_apt_source_file`
  - **Verdict**: Debian-specific (APT repository setup)

**Create SUPPORTED.md**:
- [ ] Create `variants/k8s-node/SUPPORTED.md`
  - Initial content: Debian 12 supported, RHEL planned
  - Document common/ and debian/ organization

**Update Packer Template**:
- [ ] Update `packer_templates/virtualbox/debian/sources.pkr.hcl`
  - Modify `local.variant_scripts["k8s-node"]` to use new paths
  - Change: `"variants/k8s-node/prepare.sh"` → `"variants/k8s-node/common/prepare.sh"`
  - Change: `"variants/k8s-node/install_kubernetes.sh"` → `"variants/k8s-node/debian/install_kubernetes.sh"`

**Success Criteria**: Debian 12 k8s-node build works with new structure

---

#### Phase 2: Add RHEL Support to k8s-node

**Goal**: Implement RHEL-specific scripts for k8s-node variant

**New RHEL Scripts**:

- [ ] Create `variants/k8s-node/rhel/install_container_runtime.sh`
  - Port logic from `debian/install_container_runtime.sh`
  - Replace APT with DNF:
    - `lib::ensure_apt_updated` → `lib::ensure_yum_dnf_updated`
    - `lib::ensure_apt_key_from_url` → `lib::ensure_yum_dnf_key_from_url`
    - `lib::ensure_apt_source_file` → `lib::ensure_yum_dnf_repo_file`
    - `lsb_release -rs` → `/etc/os-release` parsing or `rpm --eval %{rhel}`
    - Repository URLs: Use RHEL-specific repos (not Debian URLs)
  - Test: containerd and cri-o installation on AlmaLinux 9

- [ ] Create `variants/k8s-node/rhel/install_kubernetes.sh`
  - Port logic from `debian/install_kubernetes.sh`
  - Replace APT with DNF (same substitutions as above)
  - Repository URLs: Use Kubernetes RHEL repos
  - SELinux considerations: May need `setenforce 0` or policy adjustments
  - Test: kubeadm, kubelet, kubectl installation on AlmaLinux 9

**Update SUPPORTED.md**:
- [ ] Update `variants/k8s-node/SUPPORTED.md`
  - Add RHEL family: AlmaLinux 9 ✅ Stable
  - Document rhel/ directory

**Update Packer Template**:
- [ ] Add `local.os_family` mapping to `sources.pkr.hcl`
- [ ] Update `local.variant_scripts["k8s-node"]` to use `${local.os_family}` for OS-specific scripts
- [ ] Add validation: Fail if `os_family == "unknown"`

**Success Criteria**: AlmaLinux 9 k8s-node build works

---

#### Phase 3: Restructure docker-host (Preparatory)

**Goal**: Apply same pattern to docker-host variant (Debian only initially)

**Scripts to Move → debian/**:
- [ ] Move `variants/docker-host/install_docker.sh` → `variants/docker-host/debian/install_docker.sh`
  - **Analysis**: Contains `lib::ensure_apt_updated`, `dpkg --print-architecture`, Docker Debian repos
  - **Verdict**: Debian-specific

- [ ] Move `variants/docker-host/configure_docker.sh` → `variants/docker-host/debian/configure_docker.sh`
  - **Analysis**: May contain OS-specific paths or configurations
  - **Review**: Check if truly OS-specific or common

**Create SUPPORTED.md**:
- [ ] Create `variants/docker-host/SUPPORTED.md`
  - Initial: Debian 12 only
  - Note: RHEL support can be added similarly to k8s-node

**Update Packer Template**:
- [ ] Update `local.variant_scripts["docker-host"]` for new paths

**Success Criteria**: Debian 12 docker-host build works

---

#### Phase 4: Add Template OS Family Logic

**Goal**: Make Packer templates OS-aware for dynamic script selection

**Template Changes** (`virtualbox/debian/sources.pkr.hcl`):

- [ ] Add `os_family_map` local variable (lines 108-120 area)
```hcl
locals {
  os_family_map = {
    debian    = "debian"
    ubuntu    = "debian"
    almalinux = "rhel"
    rocky     = "rhel"
  }

  os_family = lookup(local.os_family_map, var.os_name, "unknown")

  // Validation: Fail early if unsupported OS
  validate_os_family = local.os_family != "unknown" ? true : (
    file("ERROR: Unsupported OS '${var.os_name}'. Update os_family_map in sources.pkr.hcl")
  )
}
```

- [ ] Update `variant_scripts` map to use `${local.os_family}` (lines 132-144)
```hcl
variant_scripts = {
  "k8s-node" = [
    "variants/k8s-node/common/prepare.sh",
    "variants/k8s-node/common/configure_kernel.sh",
    "variants/k8s-node/${local.os_family}/install_container_runtime.sh",  // Dynamic
    "variants/k8s-node/${local.os_family}/install_kubernetes.sh",         // Dynamic
    "variants/k8s-node/common/configure_networking.sh",
  ],
  "docker-host" = [
    "variants/docker-host/${local.os_family}/install_docker.sh",          // Dynamic
    "variants/docker-host/${local.os_family}/configure_docker.sh",        // Dynamic
  ],
}
```

**Success Criteria**: Template generates correct paths for both Debian and RHEL

---

#### Phase 5: Create RHEL Templates (Future)

**Goal**: Create packer template structure for RHEL builds

**New Template Files** (Future):
- [ ] `packer_templates/virtualbox/rhel/pkr-plugins.pkr.hcl` - Plugin requirements
- [ ] `packer_templates/virtualbox/rhel/sources.pkr.hcl` - Variables and source definitions
- [ ] `packer_templates/virtualbox/rhel/builds.pkr.hcl` - Build orchestration

**Key Differences from Debian Template**:
- ISO URLs: RHEL/AlmaLinux ISOs
- Boot command: Different preseed/kickstart
- Guest OS type: `RedHat_64` or `RedHat_ARM64`
- Library: `LIB_OS_SH` points to `lib-rhel.sh`

**Note**: Not part of initial refactoring (Phase 1-4 focus on script organization)

---

### Summary: Files Changed by Phase

#### Phase 1 (Restructure k8s-node)
- Move: 5 scripts (3 to common/, 2 to debian/)
- Create: 1 SUPPORTED.md
- Update: 1 Packer template (sources.pkr.hcl)
- Update: 2 documentation files (AGENTS.md)

#### Phase 2 (Add RHEL to k8s-node)
- Create: 2 RHEL scripts
- Update: 1 SUPPORTED.md
- Update: 1 Packer template (add os_family logic)

#### Phase 3 (Restructure docker-host)
- Move: 2 scripts (to debian/)
- Create: 1 SUPPORTED.md
- Update: 1 Packer template (variant_scripts map)

#### Phase 4 (Template OS Family)
- Update: 1 Packer template (os_family_map, validation)
- Update: 1 variant_scripts map (dynamic paths)

**Total**: ~15 file operations (moves, creates, updates)

---

## Philosophy Alignment

### Ruthless Simplicity

#### Start Minimal
- **Phase 1**: Only restructure k8s-node (most complex variant)
- **Don't refactor everything**: docker-host comes later (Phase 3)
- **No speculative abstractions**: Don't create opensuse/ directories until needed

#### Avoid Future-Proofing
- **NOT building**:
  - OpenSUSE support (marked as future)
  - VMware provider integration (separate concern)
  - Capability discovery CLI tool (wait for need)
  - Automated testing matrix (manual validation first)

#### Clear Over Clever
- **Explicit subdirectories**: File structure = documentation
- **No hidden overrides**: Debian and RHEL are peers, not "default + special"
- **Fail-fast validation**: Packer fails immediately if `os_family == "unknown"`
- **Transparent paths**: `${local.os_family}` interpolation is obvious in template

---

### Modular Design (Bricks & Studs)

#### Bricks (Self-Contained Modules)

1. **Common Scripts** (`variants/k8s-node/common/`)
   - **Regeneratable**: Yes (from OS-agnostic contract)
   - **Stud**: Bash script contract (source libraries, main(), error handling)
   - **Dependencies**: lib-core.sh only

2. **OS-Specific Scripts** (`variants/k8s-node/{debian,rhel}/`)
   - **Regeneratable**: Yes (port logic between OSes)
   - **Stud**: Same Bash contract + lib-os.sh functions
   - **Dependencies**: lib-core.sh + lib-{os}.sh

3. **Packer Templates** (`packer_templates/virtualbox/*/`)
   - **Regeneratable**: Partially (structure is fixed, mappings can change)
   - **Stud**: Packer HCL contract (variables, locals, source, build blocks)
   - **Dependencies**: Script files existence

#### Studs (Clear Interfaces)

**Stud 1: Variant Script → Packer Template**
```
Contract: Script exists at path specified in variant_scripts map
Packer executes: bash /usr/local/lib/k8s/scripts/${script_path}
```

**Stud 2: Script → Libraries**
```
Contract: LIB_CORE_SH and LIB_OS_SH environment variables set
Script sources: source "${LIB_CORE_SH}" and source "${LIB_OS_SH}"
```

**Stud 3: OS Name → OS Family**
```
Contract: var.os_name maps to exactly one os_family
Template validates: local.os_family != "unknown"
```

#### Regeneratable Test

✅ **YES** for each brick:
- **Common script**: "Given kernel config requirements, create OS-agnostic sysctl configuration script"
- **OS-specific script**: "Given Kubernetes repository setup for Debian (APT), port to RHEL (DNF)"
- **Packer template**: "Given os_family_map, generate variant_scripts with dynamic ${os_family} paths"

Each brick's contract is ≤50 lines. Implementation can be fully regenerated from contract + examples.

---

## Test Strategy

### Manual Validation (100% for v1)

**Focus**: Real Packer builds, box verification, Vagrant smoke tests

#### Phase 1 Tests (After Restructure)
**Test**: Debian 12 k8s-node build
```bash
cd packer_templates/
make debian-12-k8s   # Builds Debian 12 x86_64 k8s-node
```

**Verify**:
1. Build succeeds without errors
2. Scripts execute in correct order (check Packer log)
3. Box created: `builds/build_complete/debian-12-x86_64-k8s-node.virtualbox.box`
4. Vagrant smoke test:
```bash
vagrant box add test/debian-12-k8s builds/build_complete/debian-12-x86_64-k8s-node.virtualbox.box
vagrant init test/debian-12-k8s
vagrant up
vagrant ssh -c 'kubectl version --client'  # Should work
vagrant ssh -c 'kubeadm version'            # Should work
vagrant destroy -f
vagrant box remove test/debian-12-k8s
```

**Success**: All commands succeed, no regressions from current build

---

#### Phase 2 Tests (After RHEL Addition)
**Test**: AlmaLinux 9 k8s-node build (requires RHEL template created)

**Future Test Commands**:
```bash
make almalinux-9-k8s
vagrant box add test/almalinux-9-k8s builds/build_complete/almalinux-9-x86_64-k8s-node.virtualbox.box
vagrant init test/almalinux-9-k8s
vagrant up
vagrant ssh -c 'kubectl version --client'
vagrant ssh -c 'kubeadm version'
```

**Success**: RHEL box builds and provisions correctly

---

#### Phase 3 Tests (After docker-host Restructure)
**Test**: Debian 12 docker-host build
```bash
make debian-12-docker
vagrant box add test/debian-12-docker builds/build_complete/debian-12-x86_64-docker-host.virtualbox.box
vagrant init test/debian-12-docker
vagrant up
vagrant ssh -c 'docker --version'
vagrant ssh -c 'docker compose version'
```

**Success**: Docker variant still works after restructure

---

### Automated Testing (Future)

**Not part of initial refactoring** - wait for need

**Future Considerations**:
- **Packer template validation**: `packer validate` in CI
- **Script linting**: ShellCheck on all .sh files
- **Build matrix**: Test all OS × Variant combinations
- **Capability discovery tool**: `make list-capabilities` generates matrix

---

## Implementation Approach

### Phase 2 (Docs) - Update Documentation

**Order** (docs come first):

1. **Root AGENTS.md** (`ai_working/packer/AGENTS.md`)
   - Add section: "Multi-OS Support in Variants"
   - Update directory structure example to show common/, debian/, rhel/ subdirs
   - Document os_family concept

2. **Scripts AGENTS.md** (`ai_working/packer/packer_templates/scripts/AGENTS.md`)
   - Update "Variant Pattern" section
   - Add subsection: "OS-Specific Subdirectories"
   - Document common/ vs {os}/ separation criteria
   - Add examples from k8s-node

3. **Variant README** (`ai_working/packer/packer_templates/scripts/variants/README.md`)
   - Create new file
   - Explain variant system overview
   - How to add OS support to existing variant
   - How to create new variant

4. **SUPPORTED.md Files** (per-variant)
   - `variants/k8s-node/SUPPORTED.md` - Initial: Debian 12
   - `variants/docker-host/SUPPORTED.md` - Initial: Debian 12

**Philosophy**: Document the "why" and "what" before implementing "how"

---

### Phase 4 (Code) - Implementation Chunks

**Chunk 1: Restructure k8s-node (Debian only)** (~1-2 hours)

*Goal*: Separate common from Debian-specific without breaking builds

**Steps**:
1. Create directory structure:
```bash
mkdir -p variants/k8s-node/common
mkdir -p variants/k8s-node/debian
```

2. Move scripts (git mv preserves history):
```bash
git mv variants/k8s-node/prepare.sh variants/k8s-node/common/
git mv variants/k8s-node/configure_kernel.sh variants/k8s-node/common/
git mv variants/k8s-node/configure_networking.sh variants/k8s-node/common/
git mv variants/k8s-node/install_container_runtime.sh variants/k8s-node/debian/
git mv variants/k8s-node/install_kubernetes.sh variants/k8s-node/debian/
```

3. Create SUPPORTED.md:
```bash
cat > variants/k8s-node/SUPPORTED.md << 'EOF'
# Kubernetes Node Variant - Supported Operating Systems

| OS Family | Tested Versions | Status |
|-----------|----------------|--------|
| Debian    | 12 (Bookworm)  | ✅ Stable |
| RHEL      | TBD            | ⏳ Planned |

## Script Organization

- `common/`: OS-agnostic scripts (kernel config, networking)
- `debian/`: Debian/Ubuntu APT-based scripts
- `rhel/`: RHEL/AlmaLinux DNF-based scripts (future)
EOF
```

4. Update Packer template (`virtualbox/debian/sources.pkr.hcl` lines 132-139):
```hcl
variant_scripts = {
  "k8s-node" = [
    "variants/k8s-node/common/prepare.sh",
    "variants/k8s-node/common/configure_kernel.sh",
    "variants/k8s-node/debian/install_container_runtime.sh",  // Updated path
    "variants/k8s-node/debian/install_kubernetes.sh",         // Updated path
    "variants/k8s-node/common/configure_networking.sh",
  ],
  ...
}
```

5. Test build:
```bash
cd packer_templates/
make debian-12-k8s
# Verify build succeeds
```

**Success**: Debian 12 k8s-node build works with new structure

---

**Chunk 2: Add RHEL Scripts** (~2-4 hours)

*Goal*: Implement RHEL-specific scripts for k8s-node

**Steps**:
1. Create RHEL directory:
```bash
mkdir -p variants/k8s-node/rhel
```

2. Port `install_container_runtime.sh`:
```bash
cp variants/k8s-node/debian/install_container_runtime.sh \
   variants/k8s-node/rhel/install_container_runtime.sh
```

3. Edit RHEL version - replace APT with DNF:
   - Change: `lib::ensure_apt_updated` → `lib::ensure_yum_dnf_updated`
   - Change: `lib::ensure_apt_key_from_url` → `lib::ensure_yum_dnf_key_from_url`
   - Change: `lib::ensure_apt_source_file` → `lib::ensure_yum_dnf_repo_file`
   - Change: `lsb_release -rs` → `rpm --eval %{rhel}` or parse `/etc/os-release`
   - Change: Repository URLs to RHEL-specific (OpenSUSE build service for CRI-O)

4. Port `install_kubernetes.sh` (same APT → DNF substitutions)

5. Update SUPPORTED.md:
```markdown
| OS Family | Tested Versions | Status |
|-----------|----------------|--------|
| Debian    | 12 (Bookworm)  | ✅ Stable |
| RHEL      | AlmaLinux 9    | ✅ Stable |  // Updated
```

**Note**: Can't test until RHEL Packer templates exist (future work)

**Success**: RHEL scripts created, SUPPORTED.md updated

---

**Chunk 3: Add Template OS Family Logic** (~1 hour)

*Goal*: Make Packer template dynamically select scripts based on OS family

**Steps**:
1. Add OS family mapping to `sources.pkr.hcl` (after line 108):
```hcl
locals {
  // NEW: Map OS names to OS families
  os_family_map = {
    debian    = "debian"
    ubuntu    = "debian"
    almalinux = "rhel"
    rocky     = "rhel"
  }

  // NEW: Determine OS family from OS name
  os_family = lookup(local.os_family_map, var.os_name, "unknown")

  // NEW: Validation - fail if unsupported OS
  validate_os_family = local.os_family != "unknown" ? true : (
    file("ERROR: Unsupported OS '${var.os_name}'. Add to os_family_map in sources.pkr.hcl.")
  )

  // Existing locals...
  box_name = ...
}
```

2. Update `variant_scripts` map (lines 132-144):
```hcl
variant_scripts = {
  "k8s-node" = [
    "variants/k8s-node/common/prepare.sh",
    "variants/k8s-node/common/configure_kernel.sh",
    "variants/k8s-node/${local.os_family}/install_container_runtime.sh",  // Dynamic
    "variants/k8s-node/${local.os_family}/install_kubernetes.sh",         // Dynamic
    "variants/k8s-node/common/configure_networking.sh",
  ],
  "docker-host" = [
    "variants/docker-host/${local.os_family}/install_docker.sh",          // Dynamic
    "variants/docker-host/${local.os_family}/configure_docker.sh",        // Dynamic
  ],
}
```

3. Test validation (intentionally trigger error):
```bash
# In a test .pkrvars.hcl file:
os_name = "unsupported_os"

# Run packer validate:
packer validate .
# Should fail with: ERROR: Unsupported OS 'unsupported_os'. Add to os_family_map in sources.pkr.hcl.
```

4. Test correct path generation (Debian):
```bash
# Check Packer build log for script paths:
make debian-12-k8s
# Should see: bash /usr/local/lib/k8s/scripts/variants/k8s-node/debian/install_kubernetes.sh
```

**Success**: Template generates correct paths, fails fast on unsupported OS

---

**Chunk 4: Restructure docker-host** (~1 hour)

*Goal*: Apply same pattern to docker-host variant

**Steps**:
1. Create directory structure:
```bash
mkdir -p variants/docker-host/debian
```

2. Move scripts:
```bash
git mv variants/docker-host/install_docker.sh variants/docker-host/debian/
git mv variants/docker-host/configure_docker.sh variants/docker-host/debian/
```

3. Create SUPPORTED.md (same format as k8s-node)

4. Test build:
```bash
make debian-12-docker
```

**Success**: docker-host build works with new structure

---

**Dependencies Between Chunks**:
- Chunk 2 depends on Chunk 1 (must have structure before adding RHEL)
- Chunk 3 depends on Chunk 2 (os_family logic needs both debian/ and rhel/ to exist)
- Chunk 4 independent (can be done anytime after Chunk 1)

**Philosophy**: Each chunk is complete and testable (Debian builds work after each)

---

## Success Criteria

### Functional Success

✅ **Restructure works**:
- Debian 12 k8s-node build succeeds after Phase 1
- Debian 12 docker-host build succeeds after Phase 3
- Vagrant smoke tests pass (kubectl/docker commands work)

✅ **OS family logic works**:
- Template generates correct paths: `variants/k8s-node/debian/install_kubernetes.sh`
- Unsupported OS fails fast with clear error message
- SUPPORTED.md files accurate

✅ **Ready for RHEL**:
- RHEL scripts exist in `variants/k8s-node/rhel/`
- Template has `os_family_map` with RHEL entries
- Documentation explains how to add OS support

---

### Quality Success

✅ **Philosophy aligned**:
- Transparent (file structure = documentation)
- Incremental (added structure without breaking Debian)
- Simple (no hidden override logic)

✅ **Documentation complete**:
- AGENTS.md explains multi-OS variant pattern
- SUPPORTED.md lists tested combinations
- README.md guides contributors

✅ **No regressions**:
- Existing Debian builds work identically
- No performance changes
- Same provisioning time

---

### Developer Experience

✅ **Easy to add OS support**:
1. Create `variants/{name}/{os_family}/` directory
2. Port scripts (APT → DNF substitutions)
3. Update SUPPORTED.md
4. Test build

✅ **Easy to discover capabilities**:
- `ls variants/k8s-node/` shows: common/, debian/, rhel/, SUPPORTED.md
- SUPPORTED.md explicitly lists tested OS versions
- No hidden mappings or overrides

✅ **Clear boundaries**:
- Common scripts: No OS-specific commands
- OS-specific scripts: Only OS-specific package operations
- Template: Maps OS names to families, selects paths

---

## Next Steps

✅ **Phase 1 Complete**: Planning Approved

**Ready for**:

```bash
/ddd:2-docs
```

**This will**:
- Update `AGENTS.md` files (root and scripts)
- Create `SUPPORTED.md` manifests for variants
- Create `variants/README.md` overview
- Write as if the system already exists (retcon writing)

**After Phase 2**, proceed to:
- `/ddd:3-code-plan` - Detailed per-chunk implementation plan
- `/ddd:4-code` - Implementation (git commits per chunk)
- `/ddd:5-finish` - Testing, Makefile updates, final verification

---

## Notes for AI Assistants

### When Implementing

**Chunk-by-chunk approach**:
1. Create directory structure (mkdir, git mv)
2. Update Packer template (modify paths in variant_scripts)
3. Test Debian build (make debian-12-k8s)
4. Commit (one chunk = one commit)

**Validation checks before committing**:
- [ ] Did Debian build succeed with new paths?
- [ ] Are common scripts truly OS-agnostic (no apt/dnf commands)?
- [ ] Are OS-specific scripts properly isolated (all package ops via lib functions)?
- [ ] Is SUPPORTED.md updated?
- [ ] Would a contributor understand which OSes are supported?

**Red flags**:
- ⚠️ APT commands in common/ scripts
- ⚠️ Hardcoded Debian paths in RHEL scripts
- ⚠️ os_family_map missing new OS
- ⚠️ SUPPORTED.md out of date

---

### When Adding New OS Support

**To add OpenSUSE support to k8s-node**:
1. Check if lib-opensuse.sh exists (if not, create it first)
2. Create `variants/k8s-node/opensuse/` directory
3. Port scripts (APT → Zypper substitutions)
4. Add to `os_family_map`: `opensuse = "opensuse"`
5. Update `SUPPORTED.md`: Add OpenSUSE row
6. Test build (once OpenSUSE Packer template exists)

**Pattern**: Same 5 steps for any OS, any variant

---

## Appendix: Key Design Decisions

### Decision 1: Subdirectories Over Prefixes

**Rejected**: `install_kubernetes_debian.sh` and `install_kubernetes_rhel.sh` in same directory

**Chosen**: Subdirectories `debian/install_kubernetes.sh` and `rhel/install_kubernetes.sh`

**Rationale**:
- Visual grouping (ls shows OS families)
- Clearer scope (everything in debian/ is Debian-specific)
- Easier to add new OS (create directory, not rename files)
- Conventional (matches _common/, providers/ pattern)

---

### Decision 2: common/ Instead of Shared or Generic

**Rejected**: `shared/`, `generic/`, `base/`

**Chosen**: `common/`

**Rationale**:
- Matches existing `_common/` tier
- Clear meaning ("common to all OSes")
- Shorter than "os-agnostic/"
- Familiar to developers

---

### Decision 3: os_family Over os_type

**Rejected**: `var.os_type`, `local.os_type`

**Chosen**: `local.os_family`

**Rationale**:
- "Family" implies grouping (Debian family includes Ubuntu)
- "Type" ambiguous (x86_64 vs aarch64 is also a "type")
- Matches common terminology (Red Hat family, Debian family)

---

### Decision 4: Fail-Fast Validation in Template

**Rejected**: Allow unknown OS, fall back to Debian scripts

**Chosen**: Fail immediately if `os_family == "unknown"`

**Rationale**:
- Prevents silent failures (running wrong scripts)
- Clear error message guides fix
- Aligns with ruthless simplicity (explicit > implicit)

---

### Decision 5: SUPPORTED.md Over Code Comments

**Rejected**: Document supported OSes in source code comments

**Chosen**: Separate SUPPORTED.md file per variant

**Rationale**:
- Single source of truth (not scattered in multiple files)
- Markdown tables more readable than comments
- Easier for non-programmers to understand
- Can include testing notes, known issues

---

**Plan Version**: 1.0
**Last Updated**: 2025-11-14
**Status**: Ready for Phase 2 (Documentation)
