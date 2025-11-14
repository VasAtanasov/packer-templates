# DDD Plan: Refactor lib.sh into Modular OS-Specific Libraries

**Feature**: Split monolithic `lib.sh` into `lib-core.sh` (OS-agnostic) + OS-specific libraries (lib-debian.sh, lib-rhel.sh)

**Status**: Phase 1 - Planning Complete

**Created**: 2025-11-14

---

## Problem Statement

### What We're Solving

The current `packer_templates/scripts/_common/lib.sh` (870 lines, 60+ functions) is a monolithic Bash library that:

1. **Blocks OS expansion**: Hardcodes Debian-specific logic (dpkg, APT) throughout
2. **Will break on AlmaLinux**: Adding RHEL-based OSes (AlmaLinux, Rocky Linux) is blocked
3. **Violates "common" designation**: File in `_common/` contains OS-specific code
4. **No clear boundaries**: OS-agnostic and OS-specific functions are intermixed

### Why It Matters (User Value)

**Immediate blocker**: Cannot add AlmaLinux/Rocky Linux support (planned next expansion) without refactoring

**Future scalability**: Project aims to support multiple providers (VMware, QEMU) × multiple OSes (Debian, Ubuntu, AlmaLinux, Rocky)

**Maintainability**: Current approach would require:
- Massive if/else blocks as more OSes are added
- Duplication across multiple lib files (lib-debian.sh, lib-almalinux.sh with 80% overlap)
- High risk of drift and bugs

**Quality**: Refactoring now (at 2 OS families) prevents technical debt from becoming blocking debt

### Success Criteria

✅ **Debian builds continue to work** (regression-free)
✅ **Clear path for AlmaLinux** (lib-rhel.sh ready to implement)
✅ **OS-agnostic code separated** (lib-core.sh has zero OS assumptions)
✅ **Scripts updated** (all 17+ scripts source both libraries)
✅ **Documentation aligned** (AGENTS.md, README.md reflect new structure)
✅ **Philosophy compliant** (ruthless simplicity, modular design)

---

## Proposed Solution

### High-Level Approach

**Split lib.sh into three files:**

```
_common/
├── lib-core.sh           # OS-agnostic functions (logging, traps, files, services)
├── lib-debian.sh         # Debian/Ubuntu APT-specific functions
└── lib-rhel.sh           # AlmaLinux/Rocky DNF-specific functions (new)
```

**Scripts source both files:**

```bash
# Old (single source):
source "${LIB_SH}"

# New (two sources):
source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"
```

**Packer templates set both variables:**

```hcl
environment_vars = [
  "LIB_CORE_SH=/usr/local/lib/k8s/scripts/_common/lib-core.sh",
  "LIB_OS_SH=/usr/local/lib/k8s/scripts/_common/lib-debian.sh",  // or lib-rhel.sh
]
```

**Function dispatch within OS libraries:**

```bash
# lib-debian.sh
lib::pkg_installed() { dpkg -l "$1" 2>/dev/null | grep -q '^ii'; }
lib::ensure_packages() { apt-get install -y "$@"; }

# lib-rhel.sh (new)
lib::pkg_installed() { rpm -q "$1" >/dev/null 2>&1; }
lib::ensure_packages() { dnf install -y "$@"; }
```

### Architecture Diagram

```
Current State:
┌──────────────────────────────┐
│   lib.sh (870 lines)         │
│                              │
│ ┌──────────────────────────┐ │
│ │ OS-agnostic functions    │ │
│ │ (logging, traps, files)  │ │
│ └──────────────────────────┘ │
│ ┌──────────────────────────┐ │
│ │ Debian-specific          │ │ ← PROBLEM: Mixed together
│ │ (dpkg, apt)              │ │
│ └──────────────────────────┘ │
└──────────────────────────────┘
         ↓ sourced by
   [All 17+ scripts]


Target State:
┌──────────────────────┐   ┌──────────────────────┐
│  lib-core.sh         │   │  lib-debian.sh       │
│                      │   │                      │
│  OS-agnostic:        │   │  Debian-specific:    │
│  • logging           │   │  • dpkg functions    │
│  • traps             │   │  • apt functions     │
│  • file helpers      │   │  • deb packaging     │
│  • service helpers   │   │                      │
└──────────────────────┘   └──────────────────────┘
         ↓                          ↓
         └──────────┬───────────────┘
                    ↓
             [All 17+ scripts]
             (source both)

                             ┌──────────────────────┐
                             │  lib-rhel.sh (NEW)   │
                             │                      │
                             │  RHEL-specific:      │
                             │  • rpm functions     │
                             │  • dnf functions     │
                             │  • rpm packaging     │
                             │                      │
                             └──────────────────────┘
                                      ↑
                              (ready for AlmaLinux)
```

---

## Alternatives Considered

### Option 1: Single lib.sh with OS Dispatch (case statements)

**Approach**: Keep single file, add `case "${LIB_OS_FAMILY}"` to every OS-specific function

**Pros**:
- Minimal changes to scripts (single source)
- Simple to implement

**Cons**:
- Grows linearly with OS families (870 → 1200+ lines with 3 OSes)
- Testing becomes unwieldy (all OS paths in one file)
- Case statements in 15+ functions create noise

**Verdict**: Works for 2-3 OS families, breaks beyond that. Not chosen because we're planning 4+ OS families.

### Option 2: Inline Functions (eliminate lib.sh entirely)

**Approach**: Copy 60+ functions into each script

**Pros**:
- No shared library dependency
- Each script fully self-contained

**Cons**:
- Massive duplication (60 functions × 17 scripts = 1020+ function definitions)
- Bug fixes require updating ALL scripts
- Violates DRY principle
- No consistency guarantees

**Verdict**: Anti-pattern. Rejected.

### Option 3: Plugin System with Auto-Detection

**Approach**: lib.sh auto-detects OS and loads appropriate plugin

**Pros**:
- Scripts unchanged (single source)
- Elegant auto-detection
- Scales to 5+ OS families

**Cons**:
- Over-engineered for current needs (2 OS families)
- Adds abstraction layer (plugin loading)
- More complex to debug

**Verdict**: Too complex for current scale. Save for 5+ OS families.

### **Option 2: lib-core.sh + OS-Specific Libraries** ← CHOSEN

**Why chosen**:
1. ✅ **Right-sized for 2-4 OS families** (current plan)
2. ✅ **Clear conceptual model** (core vs OS-specific)
3. ✅ **Minimal abstraction** (two files vs one, clean split)
4. ✅ **Testable** (each library independently testable)
5. ✅ **Aligns with philosophy** (ruthless simplicity)

**Trade-offs accepted**:
- ❌ Requires two source statements (explicit > implicit)
- ❌ Packer templates must set two environment variables (worth the clarity)

---

## Architecture & Design

### Key Interfaces

#### Environment Variables (Packer → Scripts)

**Current**:
```hcl
environment_vars = ["LIB_SH=/usr/local/lib/k8s/scripts/_common/lib.sh"]
```

**New**:
```hcl
environment_vars = [
  "LIB_CORE_SH=/usr/local/lib/k8s/scripts/_common/lib-core.sh",
  "LIB_OS_SH=/usr/local/lib/k8s/scripts/_common/lib-debian.sh",
]
```

**OS Selection Logic** (in Packer template):
```hcl
locals {
  lib_os_sh = {
    debian    = "/usr/local/lib/k8s/scripts/_common/lib-debian.sh"
    ubuntu    = "/usr/local/lib/k8s/scripts/_common/lib-debian.sh"  // Ubuntu uses Debian lib
    almalinux = "/usr/local/lib/k8s/scripts/_common/lib-rhel.sh"
    rocky     = "/usr/local/lib/k8s/scripts/_common/lib-rhel.sh"
  }
}

environment_vars = [
  "LIB_CORE_SH=${local.lib_core_sh}",
  "LIB_OS_SH=${local.lib_os_sh[var.os_name]}",
]
```

#### Script Sourcing Pattern

**Current**:
```bash
source "${LIB_SH}"
lib::strict
lib::setup_traps
```

**New**:
```bash
source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"
lib::strict
lib::setup_traps
```

### Module Boundaries

#### lib-core.sh (OS-Agnostic)

**Functions to extract** (from current lib.sh):

- **Logging**: `lib::log`, `lib::success`, `lib::warn`, `lib::error`, `lib::debug`
- **Error handling**: `lib::strict`, `lib::setup_traps`, `lib::on_err`
- **UI helpers**: `lib::hr`, `lib::header`, `lib::subheader`, `lib::kv`, `lib::cmd`
- **Command checks**: `lib::require_commands`, `lib::require_root`, `lib::cmd_exists`, `lib::confirm`
- **Retry logic**: `lib::retry`
- **File helpers**: `lib::ensure_directory`, `lib::ensure_file`, `lib::ensure_symlink`, `lib::ensure_line_in_file`
- **Downloads**: `lib::ensure_downloaded`, `lib::install_binary`
- **Environment**: `lib::ensure_env_export`, `lib::ensure_env_kv`
- **Verification (OS-agnostic parts)**: `lib::verify_files`
- **Idempotency**: `lib::lock_path`, `lib::ensure_lock_dir`
- **Version parsing**: `lib::semver_from_string`
- **Hooks/scoped envs**: `lib::source_if_exists`, `lib::run_hook_dir`, `lib::source_scoped_envs`, `lib::run_pre_hooks`, `lib::run_post_hooks`
- **Services** (systemd is OS-agnostic): `lib::ensure_service_enabled`, `lib::ensure_service_running`, `lib::ensure_service`, `lib::systemd_active`
- **System (OS-agnostic parts)**: `lib::ensure_swap_disabled`, `lib::ensure_kernel_module`, `lib::ensure_sysctl`, `lib::ensure_user_in_group`

**Total**: ~45 functions (OS-agnostic)

#### lib-debian.sh (Debian/Ubuntu Specific)

**Functions to move** (from current lib.sh):

- **Package management**:
    - `lib::pkg_installed` (uses dpkg)
    - `lib::ensure_package`, `lib::ensure_packages` (use apt-get)
    - `lib::ensure_apt_updated` (APT-specific caching)
    - `lib::ensure_apt_key_from_url` (APT keyring)
    - `lib::ensure_apt_source_file` (APT sources)
- **Kernel/build tools**: `lib::install_kernel_build_deps` (apt-specific)
- **Reboot detection**: `lib::check_reboot_required` (Debian uses /var/run/reboot-required)
- **Azure helpers** (if Debian-specific): May need to keep in core if OS-agnostic

**Total**: ~10 functions (Debian-specific)

#### lib-rhel.sh (AlmaLinux/Rocky Specific) - NEW

**Functions to implement** (equivalent to Debian):

```bash
#!/usr/bin/env bash

# Package management (DNF/YUM)
lib::pkg_installed() {
    rpm -q "$1" >/dev/null 2>&1
}

lib::ensure_package() {
    local package=$1
    if lib::pkg_installed "$package"; then
        lib::log "$package already installed"
        return 0
    fi
    lib::ensure_dnf_updated
    lib::log "Installing $package..."
    if dnf install -y "$package" >/dev/null 2>&1; then
        lib::log "$package installed"
    else
        lib::error "Failed to install $package"
        return 1
    fi
}

lib::ensure_packages() {
    local to_install=() p
    for p in "$@"; do
        if lib::pkg_installed "$p"; then
            lib::log "$p already installed"
        else
            to_install+=("$p")
        fi
    done
    if [ ${#to_install[@]} -eq 0 ]; then
        return 0
    fi
    lib::ensure_dnf_updated
    lib::log "Installing packages: ${to_install[*]}..."
    if dnf install -y "${to_install[@]}" >/dev/null 2>&1; then
        lib::log "Packages installed"
        return 0
    else
        lib::error "Failed to install packages: ${to_install[*]}"
        return 1
    fi
}

# DNF cache management (equivalent to apt update)
lib::ensure_dnf_updated() {
    local ttl="${DNF_UPDATE_TTL:-300}"
    local now
    now=$(date +%s)

    if [ -n "${DNF_UPDATED_TS:-}" ] && [ $((now - DNF_UPDATED_TS)) -lt "$ttl" ]; then
        lib::debug "dnf cache considered fresh (ttl=${ttl}s)"
        return 0
    fi

    lib::log "Updating dnf cache..."
    # dnf check-update returns 100 if updates available, 0 if no updates
    if dnf check-update -q >/dev/null 2>&1 || [ $? -eq 100 ]; then
        DNF_UPDATED_TS=$now; export DNF_UPDATED_TS
        lib::log "dnf cache updated"
        return 0
    else
        DNF_UPDATED_TS=$now; export DNF_UPDATED_TS
        lib::warn "dnf update encountered warnings/errors"
        return 0
    fi
}

# Kernel build dependencies
lib::install_kernel_build_deps() {
    lib::log "Installing kernel build dependencies..."
    export DEBIAN_FRONTEND=noninteractive  # Keep for consistency

    lib::ensure_dnf_updated

    local kernel_headers="kernel-devel-$(uname -r)"
    lib::ensure_packages gcc make perl bzip2 tar dkms "$kernel_headers"

    lib::success "Kernel build dependencies installed"
}

# Reboot detection (RHEL uses needs-restarting)
lib::check_reboot_required() {
    if command -v needs-restarting >/dev/null 2>&1; then
        if needs-restarting -r >/dev/null 2>&1; then
            lib::log "Reboot required (needs-restarting)"
            return 0
        fi
    fi

    lib::log "No reboot required"
    return 1
}

# APT keyring/sources equivalents (DNF uses repos differently)
lib::ensure_yum_repo() {
    local repo_id=$1 repo_url=$2
    local repo_file="/etc/yum.repos.d/${repo_id}.repo"

    if [ -f "$repo_file" ]; then
        lib::log "YUM repo present: $repo_id"
        return 0
    fi

    lib::log "Adding YUM repo: $repo_id"
    dnf config-manager --add-repo "$repo_url"
    lib::log "YUM repo added: $repo_id"
}
```

**Total**: ~10 functions (RHEL equivalent)

### Data Models

**No new data structures**. This is a refactoring, not a feature addition.

**Environment variable contract** (Packer template → scripts):

```bash
# Current:
LIB_SH=/usr/local/lib/k8s/scripts/_common/lib.sh

# New:
LIB_CORE_SH=/usr/local/lib/k8s/scripts/_common/lib-core.sh
LIB_OS_SH=/usr/local/lib/k8s/scripts/_common/lib-debian.sh  # or lib-rhel.sh
```

---

## Files to Change

### Non-Code Files (Phase 2)

**Documentation updates** (retcon to reflect target state):

- [ ] `AGENTS.md` - Update lib.sh references, add lib-core/OS split explanation
- [ ] `packer_templates/scripts/AGENTS.md` - Update script skeleton, sourcing pattern
- [ ] `README.md` - Update lib.sh section, architecture diagram
- [ ] `CHANGELOG.md` - Add entry under Unreleased > Changed

**Total**: 4 documentation files

### Code Files (Phase 4)

**Library files**:

- [ ] `packer_templates/scripts/_common/lib.sh` → split into:
    - [ ] `lib-core.sh` (extract OS-agnostic functions)
    - [ ] `lib-debian.sh` (move Debian-specific functions)
    - [ ] `lib-rhel.sh` (create new with RHEL equivalents)
- [ ] Delete original `lib.sh` after split complete

**Packer templates** (environment variable updates):

- [ ] `packer_templates/virtualbox/debian/builds.pkr.hcl` - Update all provisioner environment_vars

**Provisioning scripts** (add second source statement):

- [ ] `packer_templates/scripts/_common/minimize.sh`
- [ ] `packer_templates/scripts/_common/sshd.sh`
- [ ] `packer_templates/scripts/_common/update_packages.sh`
- [ ] `packer_templates/scripts/_common/vagrant.sh`
- [ ] `packer_templates/scripts/debian/cleanup.sh`
- [ ] `packer_templates/scripts/debian/networking.sh`
- [ ] `packer_templates/scripts/debian/systemd.sh`
- [ ] `packer_templates/scripts/debian/sudoers.sh`
- [ ] `packer_templates/scripts/providers/virtualbox/guest_additions.sh`
- [ ] `packer_templates/scripts/providers/virtualbox/install_dependencies.sh`
- [ ] `packer_templates/scripts/variants/docker-host/configure_docker.sh`
- [ ] `packer_templates/scripts/variants/docker-host/install_docker.sh`
- [ ] `packer_templates/scripts/variants/k8s-node/configure_kernel.sh`
- [ ] `packer_templates/scripts/variants/k8s-node/configure_networking.sh`
- [ ] `packer_templates/scripts/variants/k8s-node/install_container_runtime.sh`
- [ ] `packer_templates/scripts/variants/k8s-node/install_kubernetes.sh`
- [ ] `packer_templates/scripts/variants/k8s-node/prepare.sh`

**Total**: 3 library files + 1 template + 17 scripts = **21 code files**

---

## Philosophy Alignment

### Ruthless Simplicity ✅

**Start minimal, grow as needed**:
- ✅ Splitting now (2 OS families) before it becomes blocking (3+ families)
- ✅ NOT adding plugin system or other abstractions
- ✅ Direct, explicit sourcing (two lines) vs. magic auto-detection

**Avoid future-proofing**:
- ✅ Creating lib-rhel.sh scaffold only (not full implementation)
- ✅ NOT creating lib-bsd.sh, lib-arch.sh speculatively
- ✅ Only handling Debian and AlmaLinux (planned OSes)

**Minimize abstractions**:
- ✅ Two files instead of one, but justified (core vs OS-specific)
- ✅ No factory patterns, no strategy pattern, no plugin loading
- ✅ Simple conditional in Packer: `lib_os_sh[var.os_name]`

**Clear over clever**:
- ✅ Explicit two source statements (readable, obvious)
- ✅ NOT using bash tricks to auto-detect and source
- ✅ Packer template makes OS selection explicit

### Modular Design ✅

**Bricks (modules)**:
- ✅ `lib-core.sh` = self-contained OS-agnostic helpers
- ✅ `lib-debian.sh` = self-contained Debian package management
- ✅ `lib-rhel.sh` = self-contained RHEL package management

**Studs (interfaces)**:
- ✅ Function signatures unchanged (e.g., `lib::ensure_packages "$@"`)
- ✅ Scripts call same functions, don't know which OS library is loaded
- ✅ Packer template decides which OS library to provide

**Regeneratable from spec**:
- ✅ Each library can be rewritten from function list
- ✅ OS detection logic lives in Packer (declarative), not bash (imperative)
- ✅ Scripts are consumer code, not plumbing

**Human architects, AI builds**:
- ✅ This plan is the blueprint
- ✅ AI will execute split mechanically
- ✅ Human approved architecture first (this document)

---

## Test Strategy

### Unit Tests

**Not applicable** - This project doesn't have unit test infrastructure for Bash scripts.

**Alternative**: ShellCheck validation

```bash
# Run ShellCheck on all three libraries
shellcheck packer_templates/scripts/_common/lib-core.sh
shellcheck packer_templates/scripts/_common/lib-debian.sh
shellcheck packer_templates/scripts/_common/lib-rhel.sh
```

### Integration Tests

**Packer validation** (ensures HCL syntax correct):

```bash
cd ai_working/packer
make validate-one TEMPLATE=debian/12-x86_64.pkrvars.hcl
```

**Packer build test** (ensures scripts execute):

```bash
# Build Debian 12 base box (minimal, fastest)
make build TEMPLATE=debian/12-x86_64.pkrvars.hcl

# Expected: All phases complete without error
# Scripts must source both libraries successfully
```

### User Testing

**Test as real user** (most important):

1. **Build Debian 12 base box**:
   ```bash
   make debian-12
   ```
    - ✅ Build completes without error
    - ✅ Box file created in `builds/build_complete/`

2. **Add box to Vagrant**:
   ```bash
   vagrant box add --name test-debian-12 builds/build_complete/debian-12.12-x86_64.virtualbox.box
   ```

3. **Boot box and verify**:
   ```bash
   # Create test Vagrantfile
   cat > Vagrantfile <<EOF
   Vagrant.configure("2") do |config|
     config.vm.box = "test-debian-12"
   end
   EOF

   vagrant up
   vagrant ssh -c "echo 'Box boots successfully'"
   vagrant destroy -f
   ```
    - ✅ Box boots
    - ✅ SSH works
    - ✅ Vagrant user exists

4. **Build k8s-node variant**:
   ```bash
   make debian-12-k8s
   ```
    - ✅ Variant scripts execute
    - ✅ Build completes

5. **Verify k8s-node**:
   ```bash
   vagrant box add --name test-debian-12-k8s builds/build_complete/debian-12.12-x86_64-k8s-node.virtualbox.box
   vagrant up
   vagrant ssh -c "kubeadm version && kubelet --version"
   vagrant destroy -f
   ```
    - ✅ Kubernetes tools installed

### Regression Prevention

**Before considering done**:

- [ ] `make check-env` passes
- [ ] `make validate` passes (all templates)
- [ ] `make debian-12` completes (base box)
- [ ] `make debian-12-k8s` completes (variant)
- [ ] Built boxes boot in Vagrant
- [ ] SSH works with vagrant/vagrant credentials
- [ ] No error messages in Packer output

---

## Implementation Approach

### Phase 2 (Docs) - Update Documentation

**Goal**: Retcon all documentation to reflect target state

**Files to update**:

1. **`AGENTS.md`** (root guidance):
    - Update "lib.sh Library" section → "Modular Library System"
    - Document lib-core.sh and lib-debian.sh split
    - Update sourcing pattern in examples
    - Add environment variable requirements (LIB_CORE_SH, LIB_OS_SH)

2. **`packer_templates/scripts/AGENTS.md`** (script guidance):
    - Update "Library Usage" section
    - Update script skeleton (two source statements)
    - Document OS-specific library contract

3. **`README.md`**:
    - Update architecture section
    - Update lib.sh references
    - Add explanation of OS-specific libraries

4. **`CHANGELOG.md`**:
    - Add entry:
      ```markdown
      ### Changed
      - **BREAKING**: Refactored monolithic `lib.sh` into modular libraries: `lib-core.sh` (OS-agnostic) + `lib-debian.sh` (Debian/Ubuntu) + `lib-rhel.sh` (AlmaLinux/Rocky). All scripts now source both core and OS-specific libraries.
      ```

**Technique**: [Retcon writing](../../../docs/document_driven_development/core_concepts/retcon_writing.md) - Write as if already exists

**Time estimate**: 1-2 hours

### Phase 4 (Code) - Implementation

**Chunk 1: Split lib.sh** (critical path)

1. Read current `lib.sh` in full
2. Create `lib-core.sh`:
    - Copy header (color detection, strict mode)
    - Extract all OS-agnostic functions (~45 functions)
    - Test: `shellcheck lib-core.sh`

3. Create `lib-debian.sh`:
    - Copy header (guard against re-sourcing)
    - Move all Debian-specific functions (~10 functions)
    - Test: `shellcheck lib-debian.sh`

4. Create `lib-rhel.sh`:
    - Copy header
    - Implement RHEL equivalents (~10 functions)
    - Test: `shellcheck lib-rhel.sh`

5. Delete original `lib.sh`

**Time estimate**: 2-3 hours

**Chunk 2: Update Packer Template** (critical path)

1. Update `builds.pkr.hcl`:
    - Add locals for lib path mapping
    - Update all provisioner `environment_vars` blocks
    - Replace `LIB_SH=...` with `LIB_CORE_SH=...` and `LIB_OS_SH=...`

**Time estimate**: 30 minutes

**Chunk 3: Update All Scripts** (parallelizable)

For each of the 17 scripts:

1. Change:
   ```bash
   source "${LIB_SH}"
   ```
   To:
   ```bash
   source "${LIB_CORE_SH}"
   source "${LIB_OS_SH}"
   ```

2. No other changes needed (function signatures unchanged)

**Time estimate**: 1 hour (mechanical find-replace + verification)

**Dependencies**:
- Chunk 2 depends on Chunk 1 (need libraries to exist)
- Chunk 3 depends on Chunk 1 (need libraries to exist)
- Chunks 2 and 3 can proceed in parallel

---

## Success Criteria

### Functional Requirements

✅ **All Debian builds work**:
- [ ] `make debian-12` completes successfully
- [ ] `make debian-12-arm` completes successfully
- [ ] `make debian-12-k8s` completes successfully
- [ ] `make debian-12-docker` completes successfully

✅ **Packer validation passes**:
- [ ] `make validate` shows no errors

✅ **Built boxes boot**:
- [ ] Base box boots in Vagrant
- [ ] K8s variant has Kubernetes installed
- [ ] Docker variant has Docker installed

### Code Quality

✅ **ShellCheck clean**:
- [ ] `lib-core.sh` passes ShellCheck
- [ ] `lib-debian.sh` passes ShellCheck
- [ ] `lib-rhel.sh` passes ShellCheck

✅ **No duplication**:
- [ ] lib-core.sh has zero OS-specific code
- [ ] No function definitions duplicated across libraries

✅ **Clear boundaries**:
- [ ] Core library = OS-agnostic only
- [ ] Debian library = APT/dpkg only
- [ ] RHEL library = DNF/rpm only

### Documentation

✅ **Docs retconned**:
- [ ] AGENTS.md reflects new structure
- [ ] README.md updated
- [ ] Script guidance updated
- [ ] CHANGELOG.md entry added

✅ **Examples work**:
- [ ] Script skeleton in AGENTS.md has correct sourcing pattern
- [ ] Environment variables documented

### Philosophy Compliance

✅ **Ruthless simplicity**:
- [ ] Only two files instead of one (justified split)
- [ ] No over-engineering (plugins, factories)
- [ ] Explicit > implicit (two source statements)

✅ **Modular design**:
- [ ] Clear module boundaries
- [ ] Stable interfaces (function signatures)
- [ ] Regeneratable from spec

---

## Next Steps

### Current Phase: Phase 1 Complete ✅

✅ Planning complete
✅ Architecture designed
✅ Files identified
✅ Philosophy alignment verified
✅ Test strategy defined

### Awaiting User Approval

**User review required**:
- Is this the right approach?
- Any concerns about the split?
- Approval to proceed to Phase 2 (docs)?

### After Approval

**Phase 2**: Update all documentation (retcon to target state)
- Run: `/ddd:2-docs`

**Phase 3**: Code implementation planning
- Run: `/ddd:3-code-plan`

**Phase 4**: Implement code changes
- Run: `/ddd:4-code`

**Phase 5**: Test and verify
- Run: `/ddd:5-finish`

---

## Risk Analysis

### Low Risk

✅ **Well-understood problem**: Splitting a library is straightforward
✅ **No new features**: Pure refactoring, no behavior changes
✅ **Strong test strategy**: Build-based integration testing
✅ **Incremental approach**: Documentation first, then code

### Medium Risk

⚠️ **17 scripts to update**: High number of files touched
**Mitigation**: Mechanical find-replace, automated verification

⚠️ **Packer template changes**: Environment variable changes across all provisioners
**Mitigation**: Validate template before building, test with single build first

### Minimal Risk

🟢 **No data migration**: Scripts don't persist state
🟢 **No user-facing changes**: Internal refactoring only
🟢 **Easy rollback**: Git revert if issues found

---

## Decision Criteria

**When to proceed with this plan**:
- ✅ User approves approach
- ✅ No blocking concerns raised
- ✅ Philosophy alignment confirmed

**When to reconsider**:
- ❌ User prefers Option 1 (single lib.sh with dispatch)
- ❌ User wants to defer until more OSes added
- ❌ Different split boundaries suggested

---

## References

### Previous Analysis

This plan is based on the architectural analysis from `/ultrathink-task` which evaluated:
- Current state of lib.sh (870 lines, 60+ functions)
- Four alternative architectural patterns
- Trade-offs and scalability analysis
- Recommendation: Option 2 (lib-core + OS-specific libraries)

### Related Documentation

- **DDD Overview**: `docs/document_driven_development/overview.md`
- **Implementation Philosophy**: `ai_context/IMPLEMENTATION_PHILOSOPHY.md`
- **Modular Design**: `ai_context/MODULAR_DESIGN_PHILOSOPHY.md`
- **Project AGENTS.md**: `AGENTS.md`

---

**Plan Status**: ✅ Complete, awaiting user approval

**Next Command**: `/ddd:2-docs` (after approval)
