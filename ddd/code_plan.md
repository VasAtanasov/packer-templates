# Code Plan: Variant Script Restructuring (Option 1)

**Phase**: DDD Phase 3 - Code Planning
**Architecture**: OS-Specific Subdirectories within Variants
**Objective**: Refactor variant scripts to support multiple OSes (Debian, RHEL) transparently

---

## Executive Summary

This plan refactors the current flat variant directory structure to support multiple operating systems through OS-specific subdirectories. Each variant will contain:
- `common/` - OS-agnostic scripts (kernel config, sysctl, swap management)
- `debian/` - Debian/Ubuntu-specific scripts (APT repos, packages)
- `rhel/` - RHEL/CentOS-specific scripts (DNF repos, packages)
- `SUPPORTED.md` - OS support matrix

**Key Benefits**:
- Transparent OS support discovery
- Clear separation of OS-agnostic vs OS-specific logic
- Scalable to new OSes (OpenSUSE, Alpine, etc.)
- No logic duplication across variants
- Maintains existing variant flexibility

---

## Part 1: Current State Analysis

### 1.1 k8s-node Variant (Current Structure)

**Location**: `packer_templates/scripts/variants/k8s-node/`

**Files and Classification**:

| File | Lines | Classification | Reason |
|------|-------|----------------|--------|
| `prepare.sh` | 56 | **OS-agnostic** | Swap disable, kernel modules, sysctl - uses lib-core.sh only |
| `configure_kernel.sh` | 45 | **OS-agnostic** | Kernel params via sysctl - uses lib-core.sh only |
| `install_container_runtime.sh` | 120 | **OS-specific (Debian)** | APT repo setup for containerd/cri-o |
| `install_kubernetes.sh` | 95 | **OS-specific (Debian)** | APT repo setup for kubeadm/kubelet/kubectl |
| `configure_networking.sh` | 56 | **OS-agnostic** | IP forwarding, bridge netfilter - uses lib-core.sh |

**OS-Specific Logic Example (install_kubernetes.sh:26-49)**:
```bash
# Add Kubernetes APT repository
lib::log "Adding Kubernetes repository..."
local keyring="/etc/apt/keyrings/kubernetes-apt-keyring.gpg"
local repo_url="https://pkgs.k8s.io/core:/stable:/v${k8s_version}/deb"

lib::ensure_apt_key_from_url \
    "https://pkgs.k8s.io/core:/stable:/v${k8s_version}/deb/Release.key" \
    "$keyring"

lib::ensure_apt_source_file \
    "/etc/apt/sources.list.d/kubernetes.list" \
    "deb [signed-by=${keyring}] ${repo_url}/ /"

# Update apt cache after adding repository
lib::ensure_apt_updated

# Install Kubernetes packages
lib::log "Installing Kubernetes packages..."
lib::ensure_packages \
    "kubeadm=${k8s_version}-*" \
    "kubelet=${k8s_version}-*" \
    "kubectl=${k8s_version}-*"
```

**Problem**: This uses Debian-specific functions (`lib::ensure_apt_*`, `lib::ensure_packages` from lib-debian.sh). RHEL needs equivalent logic using DNF.

---

### 1.2 docker-host Variant (Current Structure)

**Location**: `packer_templates/scripts/variants/docker-host/`

**Files and Classification**:

| File | Lines | Classification | Reason |
|------|-------|----------------|--------|
| `install_docker.sh` | 95 | **OS-specific (Debian)** | Docker APT repo setup, GPG keys |
| `configure_docker.sh` | 123 | **OS-agnostic** | daemon.json config, logrotate, systemd limits |

**OS-Specific Logic Example (install_docker.sh:25-62)**:
```bash
# Add Docker GPG key
lib::log "Adding Docker GPG key..."
local keyring="/etc/apt/keyrings/docker.gpg"
lib::ensure_directory "$(dirname "$keyring")"

if [ ! -f "$keyring" ]; then
    curl -fsSL https://download.docker.com/linux/debian/gpg | \
        gpg --dearmor -o "$keyring"
    chmod a+r "$keyring"
fi

# Add Docker repository
lib::log "Adding Docker repository..."
local arch
arch="$(dpkg --print-architecture)"
local codename
codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"

local repo_file="/etc/apt/sources.list.d/docker.list"
local repo_line="deb [arch=${arch} signed-by=${keyring}] https://download.docker.com/linux/debian ${codename} stable"

lib::ensure_apt_source_file "$repo_file" "$repo_line"

# Update apt cache and install
lib::ensure_apt_updated
lib::ensure_packages \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
    docker-compose-plugin
```

**Problem**: Uses Debian-specific repo URLs (`linux/debian`), APT functions. RHEL needs `linux/centos` URLs and DNF functions.

---

## Part 2: Target Structure (Option 1)

### 2.1 New Directory Layout

```
packer_templates/scripts/variants/
├── k8s-node/
│   ├── common/
│   │   ├── prepare.sh                    # Swap, kernel modules, sysctl
│   │   ├── configure_kernel.sh           # Kernel parameters
│   │   └── configure_networking.sh       # IP forwarding, bridge netfilter
│   ├── debian/
│   │   ├── install_container_runtime.sh  # APT-based containerd/cri-o install
│   │   └── install_kubernetes.sh         # APT-based k8s packages
│   ├── rhel/
│   │   ├── install_container_runtime.sh  # DNF-based containerd/cri-o install
│   │   └── install_kubernetes.sh         # DNF-based k8s packages
│   └── SUPPORTED.md                      # OS support matrix
│
└── docker-host/
    ├── common/
    │   └── configure_docker.sh           # daemon.json, logrotate, systemd
    ├── debian/
    │   └── install_docker.sh             # APT-based Docker install
    ├── rhel/
    │   └── install_docker.sh             # DNF-based Docker install
    └── SUPPORTED.md                      # OS support matrix
```

### 2.2 SUPPORTED.md Format

Each variant gets a support matrix showing OS compatibility:

**Example: `variants/k8s-node/SUPPORTED.md`**:
```markdown
# Kubernetes Node Variant - OS Support Matrix

## Supported Operating Systems

| OS Family | Versions | Status | Notes |
|-----------|----------|--------|-------|
| Debian | 12 (bookworm) | ✅ Tested | Primary development target |
| Ubuntu | 22.04, 24.04 | ✅ Tested | Uses debian/ scripts |
| RHEL | 9.x | ✅ Tested | Enterprise support |
| CentOS Stream | 9 | ✅ Tested | Uses rhel/ scripts |
| OpenSUSE | - | ⏳ Planned | Future implementation |

## Script Organization

- `common/` - OS-agnostic scripts (kernel config, networking)
- `debian/` - Debian/Ubuntu-specific scripts (APT repos)
- `rhel/` - RHEL/CentOS-specific scripts (DNF repos)

## Kubernetes Versions

Supports Kubernetes v1.28, v1.29, v1.30 (configurable via K8S_VERSION).

## Container Runtimes

- containerd (default)
- CRI-O (via CONTAINER_RUNTIME=cri-o)
```

---

## Part 3: File-by-File Transformation Plan

### 3.1 k8s-node Variant Transformation

#### 3.1.1 Move OS-Agnostic Scripts → common/

**File**: `variants/k8s-node/prepare.sh`
- **Action**: MOVE to `variants/k8s-node/common/prepare.sh`
- **Changes**: None (already OS-agnostic)
- **Validation**: Verify only lib-core.sh functions used

**File**: `variants/k8s-node/configure_kernel.sh`
- **Action**: MOVE to `variants/k8s-node/common/configure_kernel.sh`
- **Changes**: None (already OS-agnostic)
- **Validation**: Verify sysctl commands only

**File**: `variants/k8s-node/configure_networking.sh`
- **Action**: MOVE to `variants/k8s-node/common/configure_networking.sh`
- **Changes**: None (already OS-agnostic)
- **Validation**: Verify no OS-specific package installs

#### 3.1.2 Move Debian-Specific Scripts → debian/

**File**: `variants/k8s-node/install_container_runtime.sh`
- **Action**: MOVE to `variants/k8s-node/debian/install_container_runtime.sh`
- **Changes**: None (keep current APT implementation)
- **Validation**: Verify lib-debian.sh functions work

**File**: `variants/k8s-node/install_kubernetes.sh`
- **Action**: MOVE to `variants/k8s-node/debian/install_kubernetes.sh`
- **Changes**: None (keep current APT implementation)
- **Validation**: Verify Kubernetes APT repo setup works

#### 3.1.3 Create RHEL-Specific Scripts → rhel/

**File**: `variants/k8s-node/rhel/install_container_runtime.sh` (NEW)
- **Action**: CREATE from debian version
- **Changes**:
  ```bash
  # Before (Debian):
  lib::ensure_apt_key_from_url "https://..." "$keyring"
  lib::ensure_apt_source_file "$repo_file" "$repo_line"
  lib::ensure_apt_updated
  lib::ensure_packages containerd.io

  # After (RHEL):
  lib::ensure_yum_dnf_key_from_url "https://..." "$keyring"
  lib::ensure_yum_dnf_repo_file "$repo_file" "$repo_content"
  lib::ensure_yum_dnf_updated
  lib::ensure_packages containerd.io
  ```
- **Testing**: Build RHEL box with containerd, verify kernel modules load

**File**: `variants/k8s-node/rhel/install_kubernetes.sh` (NEW)
- **Action**: CREATE from debian version
- **Changes**:
  ```bash
  # Before (Debian):
  local keyring="/etc/apt/keyrings/kubernetes-apt-keyring.gpg"
  lib::ensure_apt_key_from_url "https://pkgs.k8s.io/.../Release.key" "$keyring"
  lib::ensure_apt_source_file "/etc/apt/sources.list.d/kubernetes.list" "deb [signed-by=${keyring}] ..."
  lib::ensure_packages "kubeadm=${k8s_version}-*" "kubelet=${k8s_version}-*"

  # After (RHEL):
  local keyring="/etc/pki/rpm-gpg/kubernetes-${k8s_version}.gpg"
  lib::ensure_yum_dnf_key_from_url "https://pkgs.k8s.io/.../Release.key" "$keyring"
  lib::ensure_yum_dnf_repo_file "/etc/yum.repos.d/kubernetes.repo" "[kubernetes]
  name=Kubernetes
  baseurl=https://pkgs.k8s.io/core:/stable:/v${k8s_version}/rpm/
  enabled=1
  gpgcheck=1
  gpgkey=file://${keyring}"
  lib::ensure_packages "kubeadm-${k8s_version}-*" "kubelet-${k8s_version}-*"
  ```
- **Testing**: Build RHEL box, verify kubeadm/kubelet installed

#### 3.1.4 Create Support Matrix

**File**: `variants/k8s-node/SUPPORTED.md` (NEW)
- **Action**: CREATE (see section 2.2 for content)
- **Purpose**: Document OS support, script organization, capabilities

---

### 3.2 docker-host Variant Transformation

#### 3.2.1 Move OS-Agnostic Scripts → common/

**File**: `variants/docker-host/configure_docker.sh`
- **Action**: MOVE to `variants/docker-host/common/configure_docker.sh`
- **Changes**: None (daemon.json, logrotate, systemd are OS-agnostic)
- **Validation**: Verify systemd commands work on both Debian and RHEL

#### 3.2.2 Move Debian-Specific Scripts → debian/

**File**: `variants/docker-host/install_docker.sh`
- **Action**: MOVE to `variants/docker-host/debian/install_docker.sh`
- **Changes**: None (keep current Docker APT implementation)
- **Validation**: Verify Docker CE APT repo setup works

#### 3.2.3 Create RHEL-Specific Scripts → rhel/

**File**: `variants/docker-host/rhel/install_docker.sh` (NEW)
- **Action**: CREATE from debian version
- **Changes**:
  ```bash
  # Before (Debian):
  curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o "$keyring"
  local repo_line="deb [arch=${arch} signed-by=${keyring}] https://download.docker.com/linux/debian ${codename} stable"
  lib::ensure_apt_source_file "$repo_file" "$repo_line"
  lib::ensure_packages docker-ce docker-ce-cli containerd.io

  # After (RHEL):
  lib::ensure_yum_dnf_key_from_url "https://download.docker.com/linux/centos/gpg" "$keyring"
  local repo_content="[docker-ce-stable]
  name=Docker CE Stable - \$basearch
  baseurl=https://download.docker.com/linux/centos/\$releasever/\$basearch/stable
  enabled=1
  gpgcheck=1
  gpgkey=file://${keyring}"
  lib::ensure_yum_dnf_repo_file "$repo_file" "$repo_content"
  lib::ensure_packages docker-ce docker-ce-cli containerd.io
  ```
- **Testing**: Build RHEL box, verify Docker CE installed and running

#### 3.2.4 Create Support Matrix

**File**: `variants/docker-host/SUPPORTED.md` (NEW)
- **Action**: CREATE (similar to k8s-node SUPPORTED.md)
- **Purpose**: Document Docker CE support across OSes

---

## Part 4: Packer Template Updates

### 4.1 Add OS Family Variable

**File**: `packer_templates/virtualbox/debian/builds.pkr.hcl`

**Current**:
```hcl
variable "os_name" {
  type    = string
  default = "debian"
}
```

**Add**:
```hcl
variable "os_family" {
  type        = string
  description = "OS family for variant script selection (debian, rhel)"
  default     = "debian"
  validation {
    condition     = contains(["debian", "rhel"], var.os_family)
    error_message = "os_family must be 'debian' or 'rhel'"
  }
}
```

### 4.2 Update variant_scripts Map

**Current**:
```hcl
locals {
  variant_scripts = {
    "base" = []
    "k8s-node" = [
      "variants/k8s-node/prepare.sh",
      "variants/k8s-node/configure_kernel.sh",
      "variants/k8s-node/install_container_runtime.sh",
      "variants/k8s-node/install_kubernetes.sh",
      "variants/k8s-node/configure_networking.sh",
    ]
    "docker-host" = [
      "variants/docker-host/install_docker.sh",
      "variants/docker-host/configure_docker.sh",
    ]
  }
}
```

**Updated**:
```hcl
locals {
  # OS-agnostic variant scripts (common/)
  variant_scripts_common = {
    "base" = []
    "k8s-node" = [
      "variants/k8s-node/common/prepare.sh",
      "variants/k8s-node/common/configure_kernel.sh",
      "variants/k8s-node/common/configure_networking.sh",
    ]
    "docker-host" = [
      "variants/docker-host/common/configure_docker.sh",
    ]
  }

  # OS-specific variant scripts (debian/, rhel/)
  variant_scripts_os = {
    "base" = []
    "k8s-node" = [
      "variants/k8s-node/${var.os_family}/install_container_runtime.sh",
      "variants/k8s-node/${var.os_family}/install_kubernetes.sh",
    ]
    "docker-host" = [
      "variants/docker-host/${var.os_family}/install_docker.sh",
    ]
  }

  # Merge common + OS-specific scripts in correct execution order
  variant_scripts = {
    for variant_name in keys(local.variant_scripts_common) : variant_name => concat(
      # Phase 1: OS-agnostic preparation (common/)
      local.variant_scripts_common[variant_name],
      # Phase 2: OS-specific installation (debian/, rhel/)
      local.variant_scripts_os[variant_name]
    )
  }

  selected_variant_scripts = lookup(local.variant_scripts, var.variant, [])
}
```

**Explanation**:
1. **variant_scripts_common**: OS-agnostic scripts from `common/` subdirs
2. **variant_scripts_os**: OS-specific scripts from `${os_family}/` subdirs
3. **variant_scripts**: Merges common + OS-specific in correct execution order
4. Scripts now interpolate `${var.os_family}` to select `debian/` or `rhel/` at build time

### 4.3 Update Provisioner Environment Variables

**Current**:
```hcl
environment_vars = concat([
  "LIB_DIR=/usr/local/lib/k8s",
  "LIB_CORE_SH=${local.lib_core_sh}",
  "LIB_OS_SH=${local.lib_os_sh[var.os_name]}",
  "VARIANT=${var.variant}",
], ...)
```

**Add**:
```hcl
environment_vars = concat([
  "LIB_DIR=/usr/local/lib/k8s",
  "LIB_CORE_SH=${local.lib_core_sh}",
  "LIB_OS_SH=${local.lib_os_sh[var.os_name]}",
  "OS_FAMILY=${var.os_family}",  # NEW: For runtime OS detection in scripts
  "VARIANT=${var.variant}",
], ...)
```

**Purpose**: Scripts can detect OS family at runtime if needed for conditional logic.

### 4.4 Create RHEL Template

**File**: `packer_templates/virtualbox/rhel/builds.pkr.hcl` (NEW)

**Action**: Copy from debian template and update:
```hcl
variable "os_name" {
  type    = string
  default = "rhel"
}

variable "os_family" {
  type    = string
  default = "rhel"
}

locals {
  lib_os_sh = {
    "rhel"   = "/usr/local/lib/k8s/scripts/_common/lib-rhel.sh"
    "centos" = "/usr/local/lib/k8s/scripts/_common/lib-rhel.sh"
  }
}
```

**Purpose**: Enable RHEL box builds with correct library and script paths.

---

## Part 5: Implementation Chunks

### Chunk 1: Restructure k8s-node (Debian Only)

**Goal**: Refactor k8s-node variant to new structure without breaking existing Debian builds.

**Tasks**:
1. Create directory structure:
   ```bash
   mkdir -p packer_templates/scripts/variants/k8s-node/{common,debian,rhel}
   ```
2. Move OS-agnostic scripts to `common/`:
   ```bash
   git mv variants/k8s-node/prepare.sh variants/k8s-node/common/
   git mv variants/k8s-node/configure_kernel.sh variants/k8s-node/common/
   git mv variants/k8s-node/configure_networking.sh variants/k8s-node/common/
   ```
3. Move Debian-specific scripts to `debian/`:
   ```bash
   git mv variants/k8s-node/install_container_runtime.sh variants/k8s-node/debian/
   git mv variants/k8s-node/install_kubernetes.sh variants/k8s-node/debian/
   ```
4. Create `SUPPORTED.md`:
   ```bash
   cat > variants/k8s-node/SUPPORTED.md << 'EOF'
   # Kubernetes Node Variant - OS Support Matrix
   (content from section 2.2)
   EOF
   ```
5. Update Packer template (`virtualbox/debian/builds.pkr.hcl`):
   - Add `os_family` variable
   - Update `variant_scripts` map to use new paths
   - Keep `var.os_family = "debian"` (default)

**Testing**:
```bash
cd packer_templates
packer build -var-file=virtualbox/debian/k8s-node.pkrvars.hcl virtualbox/debian/
```

**Success Criteria**:
- Build completes without errors
- All scripts execute in correct order (common → debian)
- kubeadm/kubelet installed and enabled
- Box boots successfully in Vagrant

**Commit Point**: "refactor(k8s-node): restructure to support multiple OSes"

**Dependencies**: None (first chunk)

---

### Chunk 2: Restructure docker-host (Debian Only)

**Goal**: Refactor docker-host variant to new structure without breaking existing Debian builds.

**Tasks**:
1. Create directory structure:
   ```bash
   mkdir -p packer_templates/scripts/variants/docker-host/{common,debian,rhel}
   ```
2. Move OS-agnostic scripts to `common/`:
   ```bash
   git mv variants/docker-host/configure_docker.sh variants/docker-host/common/
   ```
3. Move Debian-specific scripts to `debian/`:
   ```bash
   git mv variants/docker-host/install_docker.sh variants/docker-host/debian/
   ```
4. Create `SUPPORTED.md`:
   ```bash
   cat > variants/docker-host/SUPPORTED.md << 'EOF'
   # Docker Host Variant - OS Support Matrix
   (similar to k8s-node SUPPORTED.md)
   EOF
   ```
5. Update Packer template to use new paths

**Testing**:
```bash
packer build -var-file=virtualbox/debian/docker-host.pkrvars.hcl virtualbox/debian/
```

**Success Criteria**:
- Build completes without errors
- Docker CE installed and running
- vagrant user in docker group
- Box boots successfully in Vagrant

**Commit Point**: "refactor(docker-host): restructure to support multiple OSes"

**Dependencies**: Chunk 1 (same pattern)

---

### Chunk 3: Add RHEL k8s-node Support

**Goal**: Create RHEL-specific k8s-node scripts and enable RHEL builds.

**Tasks**:
1. Create `variants/k8s-node/rhel/install_container_runtime.sh`:
   - Copy from debian version
   - Replace APT functions with DNF equivalents
   - Update repo URLs (Debian → CentOS/RHEL)
   - Test containerd installation on RHEL
2. Create `variants/k8s-node/rhel/install_kubernetes.sh`:
   - Copy from debian version
   - Replace APT repo setup with DNF repo setup
   - Update package names if different
   - Test kubeadm installation on RHEL
3. Update `variants/k8s-node/SUPPORTED.md`:
   - Add RHEL 9.x as "✅ Tested"
   - Add CentOS Stream 9 as "✅ Tested"
4. Create RHEL Packer template (`virtualbox/rhel/builds.pkr.hcl`):
   - Copy from debian template
   - Update `os_name = "rhel"`, `os_family = "rhel"`
   - Update `lib_os_sh` to use lib-rhel.sh
5. Create RHEL variable files:
   - `virtualbox/rhel/k8s-node.pkrvars.hcl`

**Testing**:
```bash
# Build RHEL k8s-node box
packer build -var-file=virtualbox/rhel/k8s-node.pkrvars.hcl virtualbox/rhel/

# Verify in Vagrant
vagrant init rhel-k8s-node /path/to/box
vagrant up
vagrant ssh -c "kubeadm version"
vagrant ssh -c "sudo systemctl status kubelet"
vagrant ssh -c "sudo ctr version"  # containerd
```

**Success Criteria**:
- RHEL build completes without errors
- kubeadm/kubelet/kubectl installed via DNF
- Kubernetes YUM repo configured correctly
- containerd/cri-o running
- systemctl shows kubelet enabled
- Box boots and kubeadm init succeeds

**Commit Point**: "feat(k8s-node): add RHEL support"

**Dependencies**: Chunk 1 (k8s-node restructure)

---

### Chunk 4: Add RHEL docker-host Support

**Goal**: Create RHEL-specific docker-host scripts and enable RHEL builds.

**Tasks**:
1. Create `variants/docker-host/rhel/install_docker.sh`:
   - Copy from debian version
   - Replace Docker APT repo with Docker YUM repo
   - Update repo URLs (`linux/debian` → `linux/centos`)
   - Update architecture detection (`dpkg` → `uname -m`)
   - Test Docker CE installation on RHEL
2. Update `variants/docker-host/SUPPORTED.md`:
   - Add RHEL support status
3. Create RHEL variable files:
   - `virtualbox/rhel/docker-host.pkrvars.hcl`

**Testing**:
```bash
# Build RHEL docker-host box
packer build -var-file=virtualbox/rhel/docker-host.pkrvars.hcl virtualbox/rhel/

# Verify in Vagrant
vagrant init rhel-docker-host /path/to/box
vagrant up
vagrant ssh -c "docker --version"
vagrant ssh -c "docker compose version"
vagrant ssh -c "sudo systemctl status docker"
vagrant ssh -c "docker run hello-world"  # Test as vagrant user
```

**Success Criteria**:
- RHEL build completes without errors
- Docker CE installed via DNF
- Docker YUM repo configured correctly
- docker.service running and enabled
- vagrant user can run docker commands
- Box boots and docker works

**Commit Point**: "feat(docker-host): add RHEL support"

**Dependencies**: Chunk 2 (docker-host restructure), Chunk 3 (RHEL pattern established)

---

### Chunk 5: Documentation and Capability Discovery

**Goal**: Update all documentation and add automation for OS support discovery.

**Tasks**:
1. Update root `AGENTS.md`:
   - Document new OS-specific subdirectory pattern
   - Add examples showing debian/ and rhel/ usage
   - Update Provider × OS × Variant matrix
2. Update scripts `AGENTS.md`:
   - Add "OS-Specific Subdirectories" section
   - Document variant script execution order (common → os_family)
   - Update variant pattern examples
3. Create OS support discovery script:
   ```bash
   #!/usr/bin/env bash
   # scripts/tools/list_variant_support.sh
   # Scans SUPPORTED.md files and generates OS support matrix
   ```
4. Update main README.md:
   - Add "Building for RHEL" section
   - Document os_family variable usage
   - Add examples: `packer build -var os_family=rhel ...`
5. Create migration guide for future contributors:
   - "Adding a New OS to Existing Variants"
   - "Creating a New Variant with Multi-OS Support"

**Testing**:
- Run discovery script and verify output matches reality
- Validate all documentation examples work
- Build one Debian and one RHEL box to confirm docs accuracy

**Success Criteria**:
- All documentation updated and accurate
- SUPPORTED.md files consistent across variants
- Discovery script produces correct OS support matrix
- Contributors have clear guidance for adding new OSes

**Commit Point**: "docs(variants): update for OS-specific subdirectory pattern"

**Dependencies**: Chunks 1-4 (all code changes complete)

---

## Part 6: Testing Strategy

### 6.1 Unit Testing (Per-Chunk)

**For Each Chunk**:
1. **Syntax Validation**:
   ```bash
   # Shellcheck all modified scripts
   find variants/ -name "*.sh" -exec shellcheck {} \;
   ```
2. **Library Function Usage**:
   - Verify debian/ scripts only use lib-debian.sh functions
   - Verify rhel/ scripts only use lib-rhel.sh functions
   - Verify common/ scripts only use lib-core.sh functions
3. **Path Validation**:
   - Confirm all scripts source ${LIB_CORE_SH}, ${LIB_OS_SH} correctly
   - Confirm Packer templates reference correct script paths

### 6.2 Integration Testing (Build Tests)

**After Each Chunk**:
```bash
# Test matrix
OS_FAMILY="debian"  # or "rhel"
VARIANT="k8s-node"  # or "docker-host"

packer build \
  -var "os_family=${OS_FAMILY}" \
  -var "variant=${VARIANT}" \
  -var-file="virtualbox/${OS_FAMILY}/${VARIANT}.pkrvars.hcl" \
  virtualbox/${OS_FAMILY}/
```

**Success Criteria**:
- Packer build completes without errors
- All provisioning scripts execute successfully
- Box file generated (.box)
- Box size reasonable (<2GB for base, <3GB for variants)

### 6.3 Functional Testing (Vagrant Tests)

**For Each Built Box**:
```bash
# Import and boot
vagrant box add --name test-box /path/to/output.box
vagrant init test-box
vagrant up

# Variant-specific validation
case "$VARIANT" in
  k8s-node)
    vagrant ssh -c "kubeadm version"
    vagrant ssh -c "kubectl version --client"
    vagrant ssh -c "sudo systemctl status kubelet"
    vagrant ssh -c "sudo ctr version"  # containerd
    ;;
  docker-host)
    vagrant ssh -c "docker --version"
    vagrant ssh -c "docker compose version"
    vagrant ssh -c "sudo systemctl status docker"
    vagrant ssh -c "docker run --rm hello-world"
    ;;
esac

# Cleanup
vagrant destroy -f
vagrant box remove test-box
```

**Success Criteria**:
- Box boots successfully
- All expected packages installed
- All services running and enabled
- Variant-specific functionality works (k8s init, docker run)

### 6.4 Cross-OS Compatibility Testing

**After All Chunks Complete**:
```bash
# Build matrix: 2 OSes × 3 variants = 6 boxes
for OS in debian rhel; do
  for VARIANT in base k8s-node docker-host; do
    packer build -var-file="virtualbox/${OS}/${VARIANT}.pkrvars.hcl" virtualbox/${OS}/
    # Run functional tests
  done
done
```

**Comparison Tests**:
- Debian k8s-node vs RHEL k8s-node:
  - Same Kubernetes version installed
  - Same container runtime capabilities
  - Same kernel modules loaded
  - Same sysctl settings
- Debian docker-host vs RHEL docker-host:
  - Same Docker version installed
  - Same docker-compose functionality
  - Same daemon.json configuration
  - Same systemd overrides

**Success Criteria**:
- All 6 boxes build successfully
- Functional behavior identical across OSes for same variant
- No OS-specific quirks in common/ scripts
- SUPPORTED.md accurately reflects build test results

### 6.5 Regression Testing

**After Chunk 1 & 2** (Restructure Only):
```bash
# Ensure Debian builds still work exactly as before
packer build -var-file=virtualbox/debian/k8s-node.pkrvars.hcl virtualbox/debian/
packer build -var-file=virtualbox/debian/docker-host.pkrvars.hcl virtualbox/debian/

# Compare outputs (size, installed packages, service status)
# Should be byte-for-byte identical to pre-refactor builds
```

**Success Criteria**:
- No functional changes to Debian builds
- Box sizes within 5MB of previous builds
- Package lists identical
- Service states identical

### 6.6 Documentation Testing

**After Chunk 5**:
1. Follow "Building for RHEL" documentation:
   - Run all example commands
   - Verify they work as documented
2. Follow "Adding a New OS" migration guide:
   - Pretend to add OpenSUSE support
   - Verify all steps are clear and complete
3. Run OS support discovery script:
   - Verify output matches SUPPORTED.md files
   - Verify matrix is accurate

**Success Criteria**:
- All documentation examples work
- Migration guide is complete and clear
- Discovery script produces correct output
- No broken links or outdated references

---

## Part 7: Risk Mitigation

### 7.1 Known Risks

| Risk | Impact | Mitigation |
|------|--------|------------|
| **Packer template path breakage** | High | Chunk 1-2 focus on restructure only; test Debian builds thoroughly before adding RHEL |
| **OS-specific function mismatches** | Medium | Create lookup table of lib-debian.sh → lib-rhel.sh equivalents; validate in Chunk 3-4 |
| **RHEL repository availability** | Medium | Test repo URLs before implementation; have fallback mirror URLs |
| **Script execution order issues** | High | Document and test common → os_family execution order; add comments in template |
| **Missing RHEL equivalent packages** | Low | Research RHEL package names beforehand; have substitution plan |

### 7.2 Rollback Plan

**If Chunk 1-2 Breaks Debian Builds**:
```bash
git revert <commit-hash>
packer build -var-file=virtualbox/debian/k8s-node.pkrvars.hcl virtualbox/debian/
# Debug in separate branch
```

**If Chunk 3-4 RHEL Builds Fail**:
- Debian builds unaffected (separate os_family paths)
- Fix RHEL scripts independently
- Chunks are isolated by OS family

---

## Part 8: Success Metrics

### 8.1 Immediate Success (End of Implementation)

- [ ] All 5 chunks completed
- [ ] All tests passing (unit, integration, functional)
- [ ] 6 boxes build successfully (2 OSes × 3 variants)
- [ ] Documentation complete and accurate
- [ ] No regressions in Debian builds
- [ ] RHEL builds work on first try

### 8.2 Long-Term Success (3 Months Post-Implementation)

- [ ] OpenSUSE support added using same pattern (validates scalability)
- [ ] No issues reported with OS-specific script selection
- [ ] Contributors successfully add new OSes following migration guide
- [ ] SUPPORTED.md files kept up-to-date
- [ ] OS support discovery script used regularly

---

## Part 9: Future Extensions

### 9.1 OpenSUSE Support (Post-Implementation)

**New Directory Structure**:
```
variants/k8s-node/
├── common/          # Unchanged
├── debian/          # Unchanged
├── rhel/            # Unchanged
├── opensuse/        # NEW
│   ├── install_container_runtime.sh  # zypper-based
│   └── install_kubernetes.sh         # zypper-based
└── SUPPORTED.md     # Add OpenSUSE 15.x
```

**New Library Required**: `scripts/_common/lib-opensuse.sh`
- `lib::ensure_zypper_updated()`
- `lib::ensure_packages()` - using zypper
- `lib::ensure_zypper_repo_file()`

### 9.2 VMware Provider Support

**No Changes Needed to Variant Structure**:
- Variants remain provider-agnostic
- VMware-specific integration handled in `providers/vmware/`
- Example:
  ```
  providers/vmware/
  ├── install_dependencies.sh  # VMware build tools
  └── tools.sh                 # VMware Tools or open-vm-tools
  ```

**Variant Scripts Work Unchanged**:
- k8s-node works on VirtualBox, VMware, QEMU, etc.
- docker-host works on VirtualBox, VMware, QEMU, etc.

### 9.3 QEMU Provider Support

**Same Pattern**: Provider-specific integration separate from variants
```
providers/qemu/
├── install_dependencies.sh  # qemu-guest-agent prereqs
└── guest_agent.sh           # qemu-guest-agent install
```

---

## Part 10: Appendix

### A. Function Mapping: lib-debian.sh → lib-rhel.sh

| Debian Function | RHEL Equivalent | Notes |
|----------------|-----------------|-------|
| `lib::ensure_apt_updated` | `lib::ensure_yum_dnf_updated` | Force cache refresh |
| `lib::ensure_packages` | `lib::ensure_packages` | Same API, different backend |
| `lib::ensure_apt_key_from_url` | `lib::ensure_yum_dnf_key_from_url` | GPG key import |
| `lib::ensure_apt_source_file` | `lib::ensure_yum_dnf_repo_file` | Repo config format differs |
| `dpkg --print-architecture` | `uname -m` | Architecture detection |
| `/etc/apt/sources.list.d/` | `/etc/yum.repos.d/` | Repo file location |
| `/etc/apt/keyrings/` | `/etc/pki/rpm-gpg/` | GPG key location |

### B. Package Name Mapping

| Debian Package | RHEL Package | Notes |
|----------------|-------------|-------|
| `kubeadm` | `kubeadm` | Same name |
| `kubelet` | `kubelet` | Same name |
| `kubectl` | `kubectl` | Same name |
| `containerd.io` | `containerd.io` | Same name (Docker repo) |
| `cri-o` | `cri-o` | Same name |
| `docker-ce` | `docker-ce` | Same name (Docker repo) |
| `docker-ce-cli` | `docker-ce-cli` | Same name |
| `lsb-release` | `redhat-lsb-core` | OS detection |

### C. Repository URL Mapping

| Software | Debian URL | RHEL URL |
|----------|-----------|----------|
| Docker | `https://download.docker.com/linux/debian` | `https://download.docker.com/linux/centos` |
| Kubernetes | `https://pkgs.k8s.io/core:/stable:/v1.30/deb/` | `https://pkgs.k8s.io/core:/stable:/v1.30/rpm/` |
| CRI-O | `https://download.opensuse.org/.../Debian_*` | `https://download.opensuse.org/.../CentOS_*` |

### D. Example RHEL Script Template

**File**: `variants/k8s-node/rhel/install_kubernetes.sh`
```bash
#!/usr/bin/env bash

set -o pipefail

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

main() {
    lib::header "Installing Kubernetes packages (RHEL)"
    export DEBIAN_FRONTEND=noninteractive  # Ignored on RHEL, kept for consistency

    # Kubernetes version from environment
    local k8s_version="${K8S_VERSION:-1.30}"
    lib::log "Kubernetes version: ${k8s_version}"

    # Add Kubernetes YUM repository
    lib::log "Adding Kubernetes YUM repository..."
    local keyring="/etc/pki/rpm-gpg/kubernetes-${k8s_version}.gpg"
    local repo_file="/etc/yum.repos.d/kubernetes.repo"

    lib::ensure_yum_dnf_key_from_url \
        "https://pkgs.k8s.io/core:/stable:/v${k8s_version}/rpm/repodata/repomd.xml.key" \
        "$keyring"

    lib::ensure_yum_dnf_repo_file "$repo_file" "[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v${k8s_version}/rpm/
enabled=1
gpgcheck=1
gpgkey=file://${keyring}
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni"

    # Update YUM cache
    lib::ensure_yum_dnf_updated

    # Install Kubernetes packages with specific version
    lib::log "Installing Kubernetes packages..."
    lib::ensure_packages \
        "kubeadm-${k8s_version}.*" \
        "kubelet-${k8s_version}.*" \
        "kubectl-${k8s_version}.*"

    # Hold packages at current version
    yum versionlock kubeadm kubelet kubectl || \
        lib::warn "Could not lock Kubernetes package versions"

    # Enable kubelet service
    lib::log "Enabling kubelet service..."
    lib::ensure_service kubelet

    # Verify installation
    lib::log "Verifying Kubernetes installation..."
    if kubeadm version >/dev/null 2>&1; then
        local installed_version
        installed_version="$(kubeadm version -o short)"
        lib::success "Kubernetes ${installed_version} installed successfully"
    else
        lib::error "Kubernetes installation verification failed"
        return 1
    fi

    lib::success "Kubernetes package installation complete"
}

main "$@"
```

---

## Summary

This code plan provides a complete roadmap for refactoring variant scripts to support multiple operating systems using Option 1 (OS-Specific Subdirectories). The implementation is divided into 5 sequential chunks, each with clear tasks, testing criteria, and commit points. After completion, the system will:

1. **Support Debian and RHEL** transparently for both k8s-node and docker-host variants
2. **Scale easily** to new OSes (OpenSUSE, Alpine, etc.) by adding new subdirectories
3. **Maintain clear separation** between OS-agnostic (common/) and OS-specific (debian/, rhel/) logic
4. **Document capabilities** explicitly via SUPPORTED.md files
5. **Enable confident contribution** via comprehensive migration guides

**Next Step**: Begin Chunk 1 (k8s-node restructure for Debian).
