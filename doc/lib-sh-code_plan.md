# Code Implementation Plan: lib.sh Refactoring

**Generated**: 2025-11-14
**Based on**: zen-architect analysis (Option 2: lib-core.sh + OS-Specific Libraries)
**Project**: Packer shared scripts library refactoring
**Scope**: ai_working/packer/packer_templates/scripts/

---

## Executive Summary

Refactor the monolithic `_common/lib.sh` (870 lines, 60+ functions) into a modular architecture with OS-agnostic core and OS-specific libraries to support expansion from Debian-only to multi-OS (Debian, Ubuntu, AlmaLinux, Rocky Linux).

**Architecture**: lib-core.sh + lib-debian.sh + lib-rhel.sh
**Effort**: 5-7 days
**Risk**: Medium (touching core shared library used by 9+ scripts)
**Complexity**: Medium (clear separation, explicit dependencies, testable chunks)

---

## Current State Analysis

### Existing Architecture

**File**: `packer_templates/scripts/_common/lib.sh`
- **Size**: 870 lines
- **Functions**: 60+ helper functions
- **Problem**: Hardcoded Debian assumptions (dpkg, apt-get) in "common" library
- **Usage**: Sourced by 9 provisioning scripts via `source "${LIB_SH}"`

**Scripts Currently Using lib.sh** (9 files):
1. `providers/virtualbox/install_dependencies.sh`
2. `providers/virtualbox/guest_additions.sh`
3. `variants/k8s-node/prepare.sh`
4. `variants/k8s-node/configure_kernel.sh`
5. `variants/k8s-node/install_container_runtime.sh`
6. `variants/k8s-node/install_kubernetes.sh`
7. `variants/k8s-node/configure_networking.sh`
8. `variants/docker-host/install_docker.sh`
9. `variants/docker-host/configure_docker.sh`

**Scripts NOT Yet Using lib.sh** (Legacy, 8 files):
1. `_common/update_packages.sh` - uses direct apt commands
2. `_common/minimize.sh` - uses direct apt commands
3. `_common/sshd.sh` - no OS-specific commands
4. `_common/vagrant.sh` - no OS-specific commands
5. `debian/cleanup.sh` - uses direct dpkg/apt commands
6. `debian/systemd.sh` - no OS-specific commands
7. `debian/sudoers.sh` - no OS-specific commands
8. `debian/networking.sh` - no OS-specific commands

---

## Target Architecture

### Three-Library System

```
_common/
├── lib-core.sh          # OS-agnostic functions (45+ functions)
├── lib-debian.sh        # Debian/Ubuntu-specific (8 functions)
└── lib-rhel.sh          # AlmaLinux/Rocky-specific (8 functions, new)
```

### Usage Pattern

```bash
# New pattern (two source statements)
source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

# Packer sets these environment variables based on OS
LIB_CORE_SH=/usr/local/lib/k8s/scripts/_common/lib-core.sh
LIB_OS_SH=/usr/local/lib/k8s/scripts/_common/lib-debian.sh  # or lib-rhel.sh
```

### Packer Template Changes

```hcl
# In builds.pkr.hcl
locals {
  lib_core_sh = "/usr/local/lib/k8s/scripts/_common/lib-core.sh"

  # Map OS names to OS-specific libraries
  lib_os_sh = {
    debian    = "/usr/local/lib/k8s/scripts/_common/lib-debian.sh"
    ubuntu    = "/usr/local/lib/k8s/scripts/_common/lib-debian.sh"  # Debian-based
    almalinux = "/usr/local/lib/k8s/scripts/_common/lib-rhel.sh"
    rocky     = "/usr/local/lib/k8s/scripts/_common/lib-rhel.sh"
  }
}

# Pass to all provisioners
environment_vars = [
  "LIB_DIR=/usr/local/lib/k8s",
  "LIB_CORE_SH=${local.lib_core_sh}",
  "LIB_OS_SH=${local.lib_os_sh[var.os_name]}",
]
```

---

## Function Categorization

### lib-core.sh (OS-Agnostic Functions)

**45+ functions organized by category:**

#### 1. Color/TTY Detection (lines 11-21)
- Color variable exports
- TTY detection logic

#### 2. Logging Functions (lines 34-48)
- `lib::log()` - Blue info messages
- `lib::success()` - Green success messages
- `lib::warn()` - Yellow warnings to stderr
- `lib::error()` - Red errors to stderr
- `lib::debug()` - Dimmed debug messages (VERBOSE=1)

#### 3. Error Handling (lines 24-29, 51-58, 77-81)
- `lib::strict()` - Enable strict mode (set -Eeuo pipefail)
- `lib::setup_traps()` - Set ERR trap
- `lib::on_err()` - Error handler (logs exit code, line, command)

#### 4. UI Helpers (lines 61-75)
- `lib::hr()` - Horizontal rule separator
- `lib::header()` - Section header with HR
- `lib::subheader()` - Subsection header
- `lib::kv()` - Key-value pair display
- `lib::cmd()` - Display command being run

#### 5. Command Availability (lines 84-95, 121-123)
- `lib::require_commands()` - Fail if commands missing
- `lib::cmd_exists()` - Check if command available
- `lib::ensure_command()` - Install command if missing (lines 343-362)

#### 6. Root/Requirements (lines 98-105)
- `lib::require_root()` - Fail if not root

#### 7. Idempotency Helpers (lines 108-119)
- `lib::lock_path()` - Get path to idempotency marker
- `lib::ensure_lock_dir()` - Create lock directory

#### 8. Utilities (lines 135-141, 143-176)
- `lib::semver_from_string()` - Extract version from string
- `lib::retry()` - Retry with exponential backoff
- `lib::confirm()` - Interactive confirmation prompt

#### 9. Binary Installation (lines 364-384)
- `lib::install_binary()` - Download binary to /usr/local/bin

#### 10. File Management (lines 387-433)
- `lib::ensure_directory()` - Create dir with perms
- `lib::ensure_file()` - Copy file if changed
- `lib::ensure_symlink()` - Create symlink

#### 11. Service Management (lines 131-133, 436-477)
- `lib::systemd_active()` - Check if service active
- `lib::ensure_service_enabled()` - Enable systemd service
- `lib::ensure_service_running()` - Start systemd service
- `lib::ensure_service()` - Enable and start service

#### 12. User/Group Management (lines 480-495)
- `lib::ensure_user_in_group()` - Add user to group

#### 13. Downloads (lines 498-532)
- `lib::ensure_downloaded()` - Download with SHA256 verification

#### 14. Environment Management (lines 535-590)
- `lib::ensure_line_in_file()` - Append line if missing
- `lib::ensure_env_export()` - Add export to profile
- `lib::ensure_env_kv()` - Set key=value in file

#### 15. System Configuration (lines 593-646)
- `lib::ensure_swap_disabled()` - Disable swap (K8s requirement)
- `lib::ensure_kernel_module()` - Load kernel module
- `lib::ensure_sysctl()` - Set sysctl parameter

#### 16. Bootstrap Hooks (lines 652-760)
- `lib::source_if_exists()` - Source file if present
- `lib::run_hook_dir()` - Run all .sh files in directory
- `lib::source_scoped_envs()` - Source environment overrides
- `lib::run_pre_hooks()` - Run pre-bootstrap hooks
- `lib::run_post_hooks()` - Run post-bootstrap hooks

#### 17. Verification Helpers (lines 762-805)
- `lib::verify_commands()` - Verify commands exist
- `lib::verify_files()` - Verify files exist
- `lib::verify_services()` - Verify services running

#### 18. Azure Helpers (lines 808-869)
- `lib::check_azure_login()` - Check Azure CLI login
- `lib::ensure_provider_registered()` - Register Azure providers

**Total: ~45 functions** (100% OS-agnostic)

---

### lib-debian.sh (Debian-Specific Functions)

**8 functions for APT-based systems:**

#### 1. Package Query (lines 125-129)
```bash
lib::pkg_installed() {
    dpkg-query -W -f='${Status}\n' "$1" 2>/dev/null | grep -q "install ok installed"
}
```

#### 2. Cache Management (lines 179-217)
```bash
lib::ensure_apt_updated() {
    # Throttled apt-get update with TTL
    # Handles APT_CACHE_INVALIDATED flag
}
```

#### 3. Key Management (lines 220-239)
```bash
lib::ensure_apt_key_from_url() {
    # Fetch and install APT key (gpg --dearmor)
}
```

#### 4. Source Management (lines 242-256)
```bash
lib::ensure_apt_source_file() {
    # Write /etc/apt/sources.list.d/ entry
}
```

#### 5. Single Package Installation (lines 259-275)
```bash
lib::ensure_package() {
    # Install single package via apt-get
}
```

#### 6. Bulk Package Installation (lines 277-300)
```bash
lib::ensure_packages() {
    # Install multiple packages via apt-get
}
```

#### 7. Build Dependencies (lines 305-320)
```bash
lib::install_kernel_build_deps() {
    # Install build-essential, dkms, kernel headers
}
```

#### 8. Reboot Detection (lines 322-341)
```bash
lib::check_reboot_required() {
    # Check /var/run/reboot-required (Debian)
    # Also checks needs-restarting (RHEL) - multi-OS aware
}
```

**Total: 8 functions** (Debian/Ubuntu/APT-based)

---

### lib-rhel.sh (RHEL-Specific Functions)

**8 equivalent functions for YUM/DNF-based systems:**

#### 1. Package Query
```bash
lib::pkg_installed() {
    rpm -q "$1" >/dev/null 2>&1
}
```

#### 2. Cache Management
```bash
lib::ensure_yum_dnf_updated() {
    # Throttled dnf makecache with TTL
    # Mirror lib::ensure_apt_updated pattern
}
```

#### 3. Key Management
```bash
lib::ensure_yum_dnf_key_from_url() {
    # Fetch and install RPM GPG key
    # rpm --import or copy to /etc/pki/rpm-gpg/
}
```

#### 4. Repo Management
```bash
lib::ensure_yum_dnf_repo_file() {
    # Write /etc/yum.repos.d/ entry
}
```

#### 5. Single Package Installation
```bash
lib::ensure_package() {
    # Install single package via dnf install
}
```

#### 6. Bulk Package Installation
```bash
lib::ensure_packages() {
    # Install multiple packages via dnf install
}
```

#### 7. Build Dependencies
```bash
lib::install_kernel_build_deps() {
    # Install "Development Tools" group, kernel-devel, dkms
}
```

#### 8. Reboot Detection
```bash
lib::check_reboot_required() {
    # Use needs-restarting command (RHEL)
    # Already in current code at lines 330-336
}
```

**Total: 8 functions** (AlmaLinux/Rocky/RHEL/DNF-based)

---

## Files to Change

### New Files to Create

#### 1. `_common/lib-core.sh`
**Purpose**: OS-agnostic shared library
**Source**: Extract from current lib.sh lines 1-105, 108-141, 143-176, 343-433, 436-646, 652-805, 808-869
**Size**: ~750 lines
**Functions**: 45+ OS-agnostic helpers

#### 2. `_common/lib-debian.sh`
**Purpose**: Debian/Ubuntu-specific package management
**Source**: Extract from current lib.sh lines 125-129, 179-256, 259-341
**Size**: ~180 lines
**Functions**: 8 APT-based helpers

#### 3. `_common/lib-rhel.sh`
**Purpose**: AlmaLinux/Rocky-specific package management
**Source**: New implementations (DNF/YUM equivalents)
**Size**: ~180 lines
**Functions**: 8 DNF-based helpers

### Files to Delete

#### 1. `_common/lib.sh`
**Reason**: Replaced by lib-core.sh + lib-debian.sh + lib-rhel.sh
**Migration**: All functions moved to new libraries

### Files to Modify

#### Packer Template Changes

**File**: `packer_templates/virtualbox/debian/builds.pkr.hcl`
**Changes**:
1. Add `lib_os_sh` local variable (OS-to-library mapping)
2. Update all provisioner `environment_vars` to include both `LIB_CORE_SH` and `LIB_OS_SH`

**Before**:
```hcl
environment_vars = [
  "LIB_DIR=/usr/local/lib/k8s",
  "LIB_SH=/usr/local/lib/k8s/scripts/_common/lib.sh",
]
```

**After**:
```hcl
environment_vars = [
  "LIB_DIR=/usr/local/lib/k8s",
  "LIB_CORE_SH=${local.lib_core_sh}",
  "LIB_OS_SH=${local.lib_os_sh[var.os_name]}",
]
```

#### Script Changes (9 files currently using lib.sh)

**All scripts need two-line change**:

**Before**:
```bash
source "${LIB_SH}"
```

**After**:
```bash
source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"
```

**Files to update**:
1. `providers/virtualbox/install_dependencies.sh`
2. `providers/virtualbox/guest_additions.sh`
3. `variants/k8s-node/prepare.sh`
4. `variants/k8s-node/configure_kernel.sh`
5. `variants/k8s-node/install_container_runtime.sh`
6. `variants/k8s-node/install_kubernetes.sh`
7. `variants/k8s-node/configure_networking.sh`
8. `variants/docker-host/install_docker.sh`
9. `variants/docker-host/configure_docker.sh`

---

## Implementation Chunks

### Chunk 1: Create lib-core.sh (Extract OS-Agnostic)

**Goal**: Extract all OS-agnostic functions to new lib-core.sh

**Steps**:
1. Create `_common/lib-core.sh`
2. Copy guard header from lib.sh (lines 6-9)
3. Copy all OS-agnostic functions (see categorization above)
4. Remove OS-specific functions (package management)
5. Verify no dpkg/apt/rpm references remain

**Functions to extract** (lines from original lib.sh):
- Lines 1-105: Guards, colors, logging, error handling, UI, requirements
- Lines 108-141: Idempotency, utilities
- Lines 143-176: Retry, confirmation
- Lines 343-433: Binary install, file management
- Lines 436-495: Service management, user/group
- Lines 498-590: Downloads, environment
- Lines 593-646: System configuration (swap, modules, sysctl)
- Lines 652-760: Bootstrap hooks
- Lines 762-805: Verification
- Lines 808-869: Azure helpers

**Testing**:
```bash
# Verify no OS-specific commands
grep -E '(dpkg|apt-get|apt|rpm|yum|dnf)' _common/lib-core.sh
# Expected: No matches (except in comments/examples)

# Verify guard works
bash -c 'source _common/lib-core.sh; source _common/lib-core.sh; echo "Guard OK"'
```

**Commit Point**: lib-core.sh created with all OS-agnostic functions

---

### Chunk 2: Create lib-debian.sh (Extract Debian-Specific)

**Goal**: Extract all Debian-specific functions to new lib-debian.sh

**Steps**:
1. Create `_common/lib-debian.sh`
2. Add guard header (sourcing prevention)
3. Copy Debian-specific functions from lib.sh
4. Add comment header explaining Debian/Ubuntu/APT-based systems

**Functions to extract** (lines from original lib.sh):
- Lines 125-129: lib::pkg_installed (dpkg-query)
- Lines 179-217: lib::ensure_apt_updated
- Lines 220-239: lib::ensure_apt_key_from_url
- Lines 242-256: lib::ensure_apt_source_file
- Lines 259-275: lib::ensure_package (apt-get)
- Lines 277-300: lib::ensure_packages (apt-get)
- Lines 305-320: lib::install_kernel_build_deps (dpkg/apt)
- Lines 322-341: lib::check_reboot_required (Debian part)

**Header to add**:
```bash
#!/usr/bin/env bash

# Debian/Ubuntu-specific library functions (APT-based systems)
# Requires: lib-core.sh must be sourced first
# Compatible: Debian 11+, Ubuntu 20.04+

if [ -n "${_LIB_DEBIAN_INCLUDED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
readonly _LIB_DEBIAN_INCLUDED=1
```

**Testing**:
```bash
# Verify only Debian commands
grep -E '(rpm|yum|dnf)' _common/lib-debian.sh
# Expected: No matches

# Verify guard works
bash -c 'source _common/lib-core.sh; source _common/lib-debian.sh; source _common/lib-debian.sh; echo "Guard OK"'

# Verify dependencies on lib-core.sh
bash -c 'source _common/lib-debian.sh 2>&1 | grep -q "lib::log"' && echo "Dependency check OK"
```

**Commit Point**: lib-debian.sh created with Debian-specific functions

---

### Chunk 3: Create lib-rhel.sh (New RHEL Equivalents)

**Goal**: Create RHEL/AlmaLinux/Rocky-specific library with DNF/YUM equivalents

**Steps**:
1. Create `_common/lib-rhel.sh`
2. Add guard header and comment
3. Implement 8 RHEL equivalent functions
4. Use `dnf` as primary (RHEL 8+), fallback to `yum` if needed

**Functions to implement**:

1. **lib::pkg_installed()**
```bash
lib::pkg_installed() {
    rpm -q "$1" >/dev/null 2>&1
}
```

2. **lib::ensure_yum_dnf_updated()**
```bash
lib::ensure_yum_dnf_updated() {
    local ttl="${YUM_DNF_UPDATE_TTL:-300}"
    local now=$(date +%s)
    local need_update=0

    if [ "${YUM_DNF_CACHE_INVALIDATED:-0}" = "1" ]; then
        need_update=1
    fi

    if [ ${need_update} -eq 0 ] && [ -n "${YUM_DNF_UPDATED_TS:-}" ] && [ $((now - YUM_DNF_UPDATED_TS)) -lt "$ttl" ]; then
        lib::debug "dnf cache considered fresh (ttl=${ttl}s)"
        return 0
    fi

    lib::log "Updating dnf cache..."
    if dnf makecache -q; then
        YUM_DNF_UPDATED_TS=$now; export YUM_DNF_UPDATED_TS
        YUM_DNF_CACHE_INVALIDATED=0; export YUM_DNF_CACHE_INVALIDATED
        lib::log "dnf cache updated"
        return 0
    else
        YUM_DNF_UPDATED_TS=$now; export YUM_DNF_UPDATED_TS
        lib::warn "dnf makecache encountered warnings/errors"
        return 0
    fi
}
```

3. **lib::ensure_yum_dnf_key_from_url()**
```bash
lib::ensure_yum_dnf_key_from_url() {
    local url=$1 dest=$2
    lib::ensure_directory "$(dirname "$dest")"
    if [ -f "$dest" ]; then
        lib::log "RPM key present: $dest"
        return 0
    fi
    lib::log "Fetching RPM key from $url -> $dest"
    if curl -fsSL "$url" -o "$dest"; then
        chmod a+r "$dest" || true
        rpm --import "$dest" 2>/dev/null || true
        lib::log "RPM key installed: $dest"
        YUM_DNF_CACHE_INVALIDATED=1; export YUM_DNF_CACHE_INVALIDATED
    else
        lib::error "Failed to install RPM key: $url"
        return 1
    fi
}
```

4. **lib::ensure_yum_dnf_repo_file()**
```bash
lib::ensure_yum_dnf_repo_file() {
    local file=$1 content=$2
    lib::ensure_directory "$(dirname "$file")"
    if [ -f "$file" ]; then
        lib::log "YUM/DNF repo present: $file"
        return 0
    fi
    lib::log "Writing YUM/DNF repo: $file"
    printf '%s\n' "$content" > "$file"
    YUM_DNF_CACHE_INVALIDATED=1; export YUM_DNF_CACHE_INVALIDATED
    return 0
}
```

5. **lib::ensure_package()**
```bash
lib::ensure_package() {
    local package=$1
    if lib::pkg_installed "$package"; then
        lib::log "$package already installed"
        return 0
    fi
    lib::ensure_yum_dnf_updated
    lib::log "Installing $package..."
    if dnf install -y "$package" >/dev/null 2>&1; then
        lib::log "$package installed"
    else
        lib::error "Failed to install $package"
        return 1
    fi
}
```

6. **lib::ensure_packages()**
```bash
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
    lib::ensure_yum_dnf_updated
    lib::log "Installing packages: ${to_install[*]}..."
    if dnf install -y "${to_install[@]}" >/dev/null 2>&1; then
        lib::log "Packages installed"
        return 0
    else
        lib::error "Failed to install packages: ${to_install[*]}"
        return 1
    fi
}
```

7. **lib::install_kernel_build_deps()**
```bash
lib::install_kernel_build_deps() {
    lib::log "Installing kernel build dependencies..."
    lib::ensure_yum_dnf_updated

    local arch
    arch="$(uname -m)"

    # Install Development Tools group and kernel-devel
    local kernel_devel="kernel-devel-$(uname -r)"

    dnf groupinstall -y "Development Tools" >/dev/null 2>&1 || true
    lib::ensure_packages dkms tar bzip2 "$kernel_devel"
    lib::success "Kernel build dependencies installed"
}
```

8. **lib::check_reboot_required()** (already multi-OS in current code)
```bash
lib::check_reboot_required() {
    # Check for needs-restarting command (RHEL-based systems)
    if command -v needs-restarting >/dev/null 2>&1; then
        if needs-restarting -r >/dev/null 2>&1 || needs-restarting -s >/dev/null 2>&1; then
            lib::log "Reboot required (needs-restarting)"
            return 0
        fi
    fi

    lib::log "No reboot required"
    return 1
}
```

**Header to add**:
```bash
#!/usr/bin/env bash

# RHEL/AlmaLinux/Rocky-specific library functions (DNF/YUM-based systems)
# Requires: lib-core.sh must be sourced first
# Compatible: AlmaLinux 8+, Rocky Linux 8+, RHEL 8+

if [ -n "${_LIB_RHEL_INCLUDED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
readonly _LIB_RHEL_INCLUDED=1
```

**Testing**:
```bash
# Verify only RHEL commands
grep -E '(dpkg|apt-get|apt)' _common/lib-rhel.sh
# Expected: No matches

# Verify guard works
bash -c 'source _common/lib-core.sh; source _common/lib-rhel.sh; source _common/lib-rhel.sh; echo "Guard OK"'

# Mock test (no AlmaLinux available yet)
# Will be tested when AlmaLinux OS added to project
```

**Commit Point**: lib-rhel.sh created with RHEL-specific functions

---

### Chunk 4: Update Packer Template

**Goal**: Update builds.pkr.hcl to use new library structure

**File**: `packer_templates/virtualbox/debian/builds.pkr.hcl`

**Changes**:

1. **Add local variables** (after line 6, in sources.pkr.hcl actually):
```hcl
locals {
  # ... existing locals ...

  # Library paths
  lib_core_sh = "/usr/local/lib/k8s/scripts/_common/lib-core.sh"

  # OS-specific library mapping
  lib_os_sh = {
    debian    = "/usr/local/lib/k8s/scripts/_common/lib-debian.sh"
    ubuntu    = "/usr/local/lib/k8s/scripts/_common/lib-debian.sh"  # Debian-based
    almalinux = "/usr/local/lib/k8s/scripts/_common/lib-rhel.sh"
    rocky     = "/usr/local/lib/k8s/scripts/_common/lib-rhel.sh"
  }
}
```

2. **Update all provisioner blocks** (13 locations in builds.pkr.hcl):

**Old pattern** (lines 35-38, 51-53, 65-68, 83-86, 102-107, 124-127, 135-138):
```hcl
environment_vars = [
  "LIB_DIR=/usr/local/lib/k8s",
  "LIB_SH=/usr/local/lib/k8s/scripts/_common/lib.sh",
]
```

**New pattern**:
```hcl
environment_vars = [
  "LIB_DIR=/usr/local/lib/k8s",
  "LIB_CORE_SH=${local.lib_core_sh}",
  "LIB_OS_SH=${local.lib_os_sh[var.os_name]}",
]
```

**Specific locations to update**:
- Line 35-38: Phase 1 (update_packages.sh)
- Line 51-53: Phase 2a (install_dependencies.sh)
- Line 65-68: Phase 2b (guest_additions.sh)
- Line 83-86: Phase 2c (base config scripts)
- Line 102-107: Phase 2d (variant scripts) - **special case**, merge with existing concat()
- Line 124-127: Phase 3a (cleanup.sh)
- Line 135-138: Phase 3b (minimize.sh)

**Special handling for Phase 2d** (variant scripts, lines 102-115):
```hcl
environment_vars = concat(
  [
    "LIB_DIR=/usr/local/lib/k8s",
    "LIB_CORE_SH=${local.lib_core_sh}",
    "LIB_OS_SH=${local.lib_os_sh[var.os_name]}",
    "VARIANT=${var.variant}",
  ],
  # Add K8s-specific vars only for k8s-node variant
  var.variant == "k8s-node" ? [
    "K8S_VERSION=${var.kubernetes_version}",
    "CONTAINER_RUNTIME=${var.container_runtime}",
    "CRIO_VERSION=${var.crio_version}",
  ] : []
)
```

**Testing**:
```bash
# Validate template
cd packer_templates/virtualbox/debian
packer validate -var-file=../../../os_pkrvars/debian/12-x86_64.pkrvars.hcl .

# Expected: Validation successful
```

**Commit Point**: Packer template updated to use new library structure

---

### Chunk 5: Update Provisioning Scripts (9 files)

**Goal**: Update all scripts to source both lib-core.sh and lib-OS.sh

**Pattern**:
```bash
# Old (single source)
source "${LIB_SH}"

# New (double source)
source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"
```

**Files to update** (in order of complexity):

#### Simple Scripts (no package operations)
1. `variants/k8s-node/configure_kernel.sh` - only sysctl/modules
2. `variants/k8s-node/configure_networking.sh` - only network config

#### Medium Scripts (package operations)
3. `providers/virtualbox/install_dependencies.sh` - uses lib::install_kernel_build_deps
4. `providers/virtualbox/guest_additions.sh` - uses lib::ensure_packages
5. `variants/k8s-node/prepare.sh` - uses lib::ensure_packages
6. `variants/k8s-node/install_container_runtime.sh` - uses lib::ensure_packages
7. `variants/k8s-node/install_kubernetes.sh` - uses lib::ensure_packages
8. `variants/docker-host/install_docker.sh` - uses lib::ensure_packages
9. `variants/docker-host/configure_docker.sh` - uses lib::ensure_service

**Implementation per file**:
```bash
# Find the line
grep -n 'source.*LIB_SH' <file>

# Replace with two-line pattern
sed -i 's|source "${LIB_SH}"|source "${LIB_CORE_SH}"\nsource "${LIB_OS_SH}"|' <file>
```

**Testing per file**:
```bash
# Verify syntax
bash -n <file>

# Verify library sourcing logic (mock test)
LIB_CORE_SH=_common/lib-core.sh LIB_OS_SH=_common/lib-debian.sh bash -c 'source <file>; echo "Sourcing OK"'
```

**Commit Point**: All 9 provisioning scripts updated

---

### Chunk 6: End-to-End Testing

**Goal**: Verify full Packer build works with new library structure

**Test Plan**:

#### Test 1: Debian 12 Base Build
```bash
# Build base box
make debian-12

# Or manually:
packer build \
  -var-file=os_pkrvars/debian/12-x86_64.pkrvars.hcl \
  packer_templates/virtualbox/debian/

# Expected:
# - Build completes successfully
# - All scripts execute without errors
# - Box created in builds/build_complete/
```

#### Test 2: Debian 12 K8s Variant Build
```bash
# Build k8s variant
make debian-12-k8s

# Or manually:
packer build \
  -var-file=os_pkrvars/debian/12-x86_64.pkrvars.hcl \
  -var='variant=k8s-node' \
  packer_templates/virtualbox/debian/

# Expected:
# - Build completes successfully
# - All variant scripts execute
# - K8s packages installed correctly
```

#### Test 3: Vagrant Box Verification
```bash
# Add box
vagrant box add --name test-debian-12 builds/build_complete/debian-12.12-x86_64.virtualbox.box

# Create test Vagrantfile
cat > /tmp/test-vagrant/Vagrantfile <<EOF
Vagrant.configure("2") do |config|
  config.vm.box = "test-debian-12"
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "1024"
    vb.cpus = 1
  end
end
EOF

# Start VM
cd /tmp/test-vagrant
vagrant up

# SSH and verify
vagrant ssh -c "which apt-get && echo 'Debian OK'"
vagrant ssh -c "systemctl is-active ssh && echo 'SSH OK'"
vagrant ssh -c "[ -f /usr/local/bin/kubectl ] && echo 'K8s OK' || echo 'Base OK'"

# Cleanup
vagrant destroy -f
cd -
vagrant box remove test-debian-12
```

#### Test 4: Library Function Verification
```bash
# SSH into running VM during Packer build (if needed for debug)
# Verify libraries exist and are sourceable

vagrant ssh -c "bash -c 'source /usr/local/lib/k8s/scripts/_common/lib-core.sh; lib::log \"Core OK\"'"
vagrant ssh -c "bash -c 'source /usr/local/lib/k8s/scripts/_common/lib-debian.sh; lib::pkg_installed bash && echo \"Debian OK\"'"
```

**Success Criteria**:
- ✅ All builds complete without errors
- ✅ All provisioning phases execute successfully
- ✅ Vagrant boxes boot and are accessible
- ✅ SSH works with vagrant/vagrant credentials
- ✅ VirtualBox Guest Additions installed and functional
- ✅ Variant-specific software installed correctly (k8s-node)
- ✅ No references to old `LIB_SH` variable
- ✅ Libraries properly removed in final cleanup phase

**Commit Point**: All tests passing, refactoring complete

---

### Chunk 7: Cleanup and Documentation

**Goal**: Remove old lib.sh, update documentation

**Steps**:

1. **Delete old library**:
```bash
rm -f packer_templates/scripts/_common/lib.sh
```

2. **Update AGENTS.md**:
   - Update lib.sh references to lib-core.sh + OS-specific libraries
   - Add section on OS-specific library selection
   - Update script skeleton to show double-source pattern

**File**: `packer_templates/scripts/AGENTS.md`

**Changes**:
```markdown
## Library Usage

- Always source the shared libraries provided by Packer:
  ```bash
  source "${LIB_CORE_SH}"   # OS-agnostic functions
  source "${LIB_OS_SH}"     # OS-specific functions (Debian/RHEL)
  ```

- **LIB_CORE_SH**: Contains 45+ OS-agnostic helpers (logging, files, services, etc.)
- **LIB_OS_SH**: Contains 8 OS-specific helpers (package management)
  - Debian/Ubuntu: `lib-debian.sh` (apt-get, dpkg)
  - AlmaLinux/Rocky: `lib-rhel.sh` (dnf, rpm)

## Script Skeleton

```bash
#!/usr/bin/env bash

set -o pipefail

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

main() {
  lib::header "Doing a thing"
  export DEBIAN_FRONTEND=noninteractive
  lib::ensure_packages curl ca-certificates  # OS-agnostic call!
  # ... your logic here ...
  lib::success "Completed"
}

main "$@"
```
```

3. **Update root AGENTS.md**:

**File**: `ai_working/packer/AGENTS.md`

**Changes**:
```markdown
### lib.sh Library

The `packer_templates/scripts/_common/` directory contains a modular Bash library system:

- **lib-core.sh**: 45+ OS-agnostic helper functions (logging, files, services, verification)
- **lib-debian.sh**: 8 Debian/Ubuntu-specific functions (APT-based package management)
- **lib-rhel.sh**: 8 AlmaLinux/Rocky-specific functions (DNF-based package management)

All provisioner scripts should source both libraries:
```bash
source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"
```

The `LIB_OS_SH` variable is automatically set by Packer based on the `os_name` variable:
- `os_name=debian` or `os_name=ubuntu` → `lib-debian.sh`
- `os_name=almalinux` or `os_name=rocky` → `lib-rhel.sh`
```

4. **Update CHANGELOG.md**:
```markdown
## [Unreleased]

### Changed
- **BREAKING**: Refactored lib.sh into modular architecture (lib-core.sh + lib-debian.sh + lib-rhel.sh)
- Scripts now source two libraries instead of one: `source "${LIB_CORE_SH}"; source "${LIB_OS_SH}"`
- Packer templates updated to pass LIB_CORE_SH and LIB_OS_SH environment variables
- All provisioning scripts updated to use new library structure

### Added
- lib-core.sh: 45+ OS-agnostic helper functions
- lib-debian.sh: 8 Debian/Ubuntu-specific functions (APT-based)
- lib-rhel.sh: 8 AlmaLinux/Rocky-specific functions (DNF-based, preparatory for future OS support)

### Removed
- _common/lib.sh (replaced by modular libraries)
```

**Commit Point**: Documentation updated, old library removed

---

## Testing Strategy

### Unit Testing (Manual Script Verification)

**Per Library File**:
```bash
# Test lib-core.sh
bash -c 'source _common/lib-core.sh; lib::log "Test" && echo "✓ Logging works"'
bash -c 'source _common/lib-core.sh; lib::ensure_directory /tmp/test && echo "✓ File helpers work"'

# Test lib-debian.sh
bash -c 'source _common/lib-core.sh; source _common/lib-debian.sh; lib::pkg_installed bash && echo "✓ Package query works"'

# Test lib-rhel.sh (when AlmaLinux available)
bash -c 'source _common/lib-core.sh; source _common/lib-rhel.sh; lib::pkg_installed bash && echo "✓ Package query works"'
```

### Integration Testing (Packer Builds)

**Test Matrix**:
| OS           | Variant     | Priority | Status |
|--------------|-------------|----------|--------|
| Debian 12    | base        | High     | ✅      |
| Debian 12    | k8s-node    | High     | ✅      |
| Debian 12    | docker-host | Medium   | ✅      |
| Debian 13    | base        | Medium   | ✅      |
| AlmaLinux 8  | base        | Low      | 🔜 Future |

### User Testing (Vagrant Verification)

**Test Cases**:
1. ✅ Box boots and SSH works
2. ✅ VirtualBox Guest Additions functional (shared folders, resolution)
3. ✅ Network connectivity works
4. ✅ Variant software installed and functional (kubectl, docker)
5. ✅ No build artifacts remain (/usr/local/lib/k8s removed)

### Regression Testing

**Critical Paths**:
1. ✅ Existing Debian 12 builds still work
2. ✅ All existing make targets work (make debian-12, make debian-12-k8s, etc.)
3. ✅ Box sizes remain similar (no bloat)
4. ✅ Build times remain similar (no performance regression)

---

## Philosophy Compliance

### Ruthless Simplicity

✅ **Three files vs one**: Justified by clear OS separation
✅ **Explicit sourcing**: Two source statements show dependencies clearly
✅ **No auto-detection magic**: Packer explicitly sets LIB_OS_SH
✅ **Start minimal**: Only Debian + RHEL libraries (Ubuntu reuses Debian)

### Modular Design

✅ **Clear boundaries**: Core (OS-agnostic) vs OS-specific
✅ **Testable components**: Each library independently testable
✅ **Regeneratable**: Each library can be rebuilt from interface contract
✅ **Self-contained**: Scripts only depend on library interfaces

### Anti-Patterns Avoided

❌ **Single lib.sh with case statements**: Too complex at scale
❌ **Plugin system**: Over-engineered for 2-3 OS families
❌ **Inline functions**: Would duplicate 60+ functions across 17 scripts

---

## Agent Orchestration

### Primary Agents

**modular-builder**: Implement the 3 new library files
```
Task modular-builder: "Create lib-core.sh by extracting OS-agnostic functions from lib.sh (lines 1-105, 108-646, 652-869)"
Task modular-builder: "Create lib-debian.sh by extracting Debian-specific functions from lib.sh (lines 125-341)"
Task modular-builder: "Create lib-rhel.sh with DNF/YUM equivalents of Debian functions"
```

**zen-architect**: Review architecture compliance
```
Task zen-architect: "Review refactored library structure for philosophy compliance"
```

**bug-hunter**: Debug any test failures
```
Task bug-hunter: "Debug Packer build failure in Phase 2a (if failures occur)"
```

**test-coverage**: Validate testing approach
```
Task test-coverage: "Suggest additional test cases for library refactoring"
```

### Sequential Execution Plan

```
Chunk 1 (lib-core.sh) →
  Chunk 2 (lib-debian.sh) →
    Chunk 3 (lib-rhel.sh) →
      Chunk 4 (Packer template) →
        Chunk 5 (Update scripts) →
          Chunk 6 (E2E testing) →
            Chunk 7 (Cleanup/docs)
```

**Rationale for Sequential**:
- Each chunk builds on previous (lib-core → lib-debian → lib-rhel → template → scripts)
- Cannot test until all pieces in place
- Clean commit history with atomic changes

---

## Commit Strategy

### Commit 1: Extract lib-core.sh
```
feat(scripts): extract OS-agnostic functions to lib-core.sh

- Create _common/lib-core.sh with 45+ OS-agnostic functions
- Extract from lib.sh: logging, UI, files, services, system config
- Add guard header to prevent double-sourcing
- ~750 lines of OS-agnostic bash helpers

Ref: zen-architect analysis (Option 2)
```

### Commit 2: Extract lib-debian.sh
```
feat(scripts): extract Debian-specific functions to lib-debian.sh

- Create _common/lib-debian.sh with 8 APT-based functions
- Extract from lib.sh: package management, APT cache, keys, sources
- Functions: lib::pkg_installed, lib::ensure_packages, etc.
- ~180 lines of Debian/Ubuntu-specific helpers

Ref: zen-architect analysis (Option 2)
```

### Commit 3: Create lib-rhel.sh
```
feat(scripts): add RHEL-specific library with DNF/YUM functions

- Create _common/lib-rhel.sh with 8 DNF-based functions
- Equivalents for AlmaLinux/Rocky Linux support
- Functions: lib::pkg_installed (rpm), lib::ensure_packages (dnf), etc.
- ~180 lines of RHEL-family helpers

Ref: zen-architect analysis (Option 2)
Preparatory: For future AlmaLinux/Rocky support
```

### Commit 4: Update Packer template
```
feat(packer): update template to use modular library structure

- Add lib_os_sh local variable mapping OS to library
- Update all 7 provisioner blocks with LIB_CORE_SH + LIB_OS_SH
- Remove old LIB_SH environment variable
- Template validated successfully

Breaking: Requires new library structure in place

Ref: builds.pkr.hcl lines 35-138
```

### Commit 5: Update provisioning scripts
```
feat(scripts): update 9 scripts to source modular libraries

- Replace single source "${LIB_SH}" with double source pattern
- Files: providers/virtualbox/*, variants/k8s-node/*, variants/docker-host/*
- Pattern: source "${LIB_CORE_SH}"; source "${LIB_OS_SH}"
- All scripts syntax-validated

Breaking: Requires Packer template changes (Commit 4)
```

### Commit 6: End-to-end testing verification
```
test(scripts): verify refactored library structure with E2E builds

- Debian 12 base build: ✅ Passed
- Debian 12 k8s variant: ✅ Passed
- Vagrant box verification: ✅ Passed
- All library functions tested in real provisioning

Closes: lib.sh refactoring (Option 2 implementation)
```

### Commit 7: Remove old library and update docs
```
docs(scripts): update documentation for modular library structure

- Remove old _common/lib.sh (replaced by lib-core + lib-debian + lib-rhel)
- Update AGENTS.md with new library usage pattern
- Update script skeleton examples
- Update CHANGELOG.md with breaking changes

Breaking: lib.sh no longer exists
```

---

## Risk Assessment

### High Risk Changes

**Risk**: Refactoring core shared library used by all scripts
**Impact**: Build failures if any function broken or missing
**Mitigation**:
- Comprehensive testing after each chunk
- Atomic commits with clear rollback points
- Test on base variant first, then complex variants
- Keep old lib.sh until all tests pass (git stash or branch)

### Medium Risk Changes

**Risk**: Two-source pattern might cause subtle sourcing issues
**Impact**: Functions not available, variable scoping issues
**Mitigation**:
- Clear guard headers in all libraries
- Test double-sourcing explicitly
- Verify no function name collisions between libraries

### Low Risk Changes

**Risk**: Documentation might become outdated
**Impact**: Confusion for future contributors
**Mitigation**:
- Update all docs in same commit as code changes
- Include examples in AGENTS.md
- Update CHANGELOG.md comprehensively

---

## Dependencies to Watch

**External Tools**:
- Packer >= 1.7.0 (required, already enforced)
- VirtualBox >= 7.1.6 (required, already enforced)
- Bash >= 4.0 (available on all target systems)

**OS Compatibility**:
- Debian 11+ (currently supported)
- Ubuntu 20.04+ (future, uses lib-debian.sh)
- AlmaLinux 8+ (future, uses lib-rhel.sh)
- Rocky Linux 8+ (future, uses lib-rhel.sh)

**No Breaking Changes**:
- Existing Debian builds continue to work
- No changes to Vagrant box format or outputs
- No changes to make/rake targets

---

## Success Criteria

### Functional Success

✅ **All Debian builds work**:
- Base boxes build successfully
- K8s variant builds successfully
- Docker variant builds successfully

✅ **Library structure clean**:
- lib-core.sh contains only OS-agnostic functions
- lib-debian.sh contains only APT-based functions
- lib-rhel.sh contains only DNF-based functions
- No function duplication across libraries

✅ **Scripts updated correctly**:
- All 9 scripts use new double-source pattern
- All scripts execute without errors
- No references to old LIB_SH variable

✅ **Packer template updated**:
- All provisioner blocks use new environment variables
- Template validates successfully
- OS-to-library mapping correct

### Quality Success

✅ **Philosophy aligned**:
- Three libraries justified by clear OS separation
- No over-engineering (plugin system, auto-detection)
- Explicit over implicit (two source statements)

✅ **Testable**:
- Each library independently testable
- E2E builds verify integration
- Clear rollback points at each commit

✅ **Documentation complete**:
- AGENTS.md updated with new pattern
- Script skeleton shows double-source
- CHANGELOG.md documents breaking changes

### Future-Proof Success

✅ **Scalable to new OSes**:
- Adding Ubuntu: reuse lib-debian.sh ✅
- Adding AlmaLinux: use lib-rhel.sh (already created) ✅
- Adding Rocky: use lib-rhel.sh (already created) ✅

✅ **Maintainable**:
- Clear boundaries between libraries
- Each library < 200 lines and focused
- Easy to regenerate from specifications

---

## Next Steps

### After This Plan is Approved

1. **Create feature branch**:
```bash
git checkout -b refactor/lib-modular-architecture
```

2. **Execute chunks sequentially** (per commit strategy above)

3. **Test after each chunk** (per testing strategy above)

4. **Create pull request** with comprehensive description

5. **Merge to main** after review and approval

### Future Work (Out of Scope)

**Not included in this refactoring**:
- ❌ Updating legacy scripts (_common/update_packages.sh, debian/cleanup.sh) to use libraries
- ❌ Adding actual AlmaLinux/Rocky OS support to Packer
- ❌ Creating VMware or QEMU provider templates
- ❌ Refactoring build script itself

**Future considerations**:
- Consider updating legacy scripts to use libraries (separate effort)
- Add AlmaLinux when ready (lib-rhel.sh already prepared)
- Test on Rocky Linux (lib-rhel.sh already prepared)

---

## Appendix: Decision Record

### Why Option 2 (lib-core + OS-specific)?

**Alternatives Considered**:
1. ❌ Single lib.sh with case statements - doesn't scale beyond 3-4 OS families
2. ✅ **lib-core + OS-specific** - clean separation, scales well, testable
3. ❌ Plugin system with auto-detection - over-engineered for current needs
4. ❌ Eliminate library entirely - massive code duplication

**Key Decision Factors**:
- Currently 1 OS family (Debian), expanding to 2 (Debian + RHEL)
- Clean separation justifies extra file vs case statements
- Explicit better than implicit (two sources vs auto-detection)
- Preparation for future without over-engineering present

**When to Revisit**:
- If OS count exceeds 4-5 families (BSD, Arch, Alpine, etc.)
- If auto-detection becomes critical (can't rely on Packer setting variable)
- If scripts proliferate beyond 50 files (double-source becomes burden)

**Success Metrics**:
- Time to add new OS: < 1 day (create or reuse OS-specific library)
- Code duplication: 0% (all shared functions in libraries)
- Test coverage: 100% (all libraries tested in real builds)

---

**Plan Version**: 1.0
**Last Updated**: 2025-11-14
**Status**: Ready for Approval → Implementation
