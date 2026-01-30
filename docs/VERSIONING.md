---
title: Vagrant Box Versioning and Naming Strategy
version: 1.0.0
date: 2026-01-29
status: Active
scope: All Vagrant boxes published to HashiCorp Vagrant Cloud
---

# Vagrant Box Versioning and Naming Strategy

This document defines the comprehensive versioning and naming strategy for publishing Vagrant boxes to HashiCorp Vagrant Cloud.

## Table of Contents

- [Executive Summary](#executive-summary)
- [Core Principles](#core-principles)
- [Box Categories](#box-categories)
- [Naming Conventions](#naming-conventions)
- [Versioning Strategy](#versioning-strategy)
- [Complete Box Matrix](#complete-box-matrix)
- [Version Progression Examples](#version-progression-examples)
- [CHANGELOG Format](#changelog-format)
- [Metadata Strategy](#metadata-strategy)
- [Upgrade Workflows](#upgrade-workflows)
- [Implementation Plan](#implementation-plan)
- [References](#references)

---

## Executive Summary

**Adopted Strategy:** Hybrid approach combining **alvistack-style separate boxes** with **SemVer versioning** (`X.Y.Z`).

**Key Decisions:**
1. ✅ **Separate boxes per variant** (alvistack-style for clarity)
2. ✅ **Distro identifier in box names** (e.g., `debian-12-docker-host`)
3. ✅ **SemVer for versioning** (`1.0.0`, not date-based)
4. ✅ **CHANGELOG.md** for detailed change tracking
5. ✅ **No automated rebuilds** (manual version control)
6. ✅ **Purpose-Built vs Additive distinction** (critical architectural insight)

**Influenced By:** 
- alvistack's versioning approach (CalVer `YYYYMMDD.Y.Z` with separate boxes per software version)
- HashiCorp's Vagrant Cloud constraints (strict `X.Y.Z` format)
- Oracle's architectural recommendations (SemVer + metadata)

---

## Core Principles

### 1. **Purpose-Built vs Additive Variants**

This is the **critical architectural distinction** that drives all naming and versioning decisions:

| Type | Identity | Primary Focus | Example |
|------|----------|---------------|---------|
| **Purpose-Built** | Software version | Entire system configured FOR specific software | `kubernetes-1.33` |
| **Additive Variant** | OS version | Base OS WITH additional software installed | `debian-12-docker-host` |

**Purpose-Built Boxes:**
- Software version is the PRIMARY identity
- OS is implementation detail (can change transparently)
- Entire system tuned for the software (kernel, networking, services)
- Users care about software version, not OS version
- Example: Kubernetes node (kernel tuned, networking configured, services optimized)

**Additive Variant Boxes:**
- OS version is the PRIMARY identity
- Software is addon/enhancement
- OS remains fundamentally itself
- Users care about OS version AND software version
- Example: Debian with Docker (just Docker installed on standard Debian)

### 2. **Semantic Versioning (SemVer)**

All boxes use **independent SemVer**: `MAJOR.MINOR.PATCH`

- **Major (X):** Breaking changes (OS major upgrade, API removals, fundamental config changes)
- **Minor (Y):** Backwards-compatible changes (OS point releases, software minor updates, new features)
- **Patch (Z):** Bug fixes only (script fixes, no software version changes, security patches)

### 3. **Separate Boxes per Major Concern**

- **OS major versions** → Separate boxes (`debian-12` vs `debian-13`)
- **Software major.minor versions** → Separate boxes (`kubernetes-1.33` vs `kubernetes-1.34`)
- **Different variants** → Separate boxes (`debian-12-base` vs `debian-12-docker-host`)

### 4. **Multi-Provider Support**

- Single box supports multiple providers (VirtualBox, VMware, QEMU)
- Same version across all providers
- Provider-specific artifacts uploaded separately

---

## Box Categories

### Category 1: Base OS Boxes

**Purpose:** Minimal operating system installation with Vagrant essentials only.

**Naming Pattern:** `{os_name}-{os_major}`

**Examples:**
```
myusername/debian-12          # Debian 12.x (any point release)
myusername/debian-13          # Debian 13.x
myusername/almalinux-9        # AlmaLinux 9.x
myusername/ubuntu-24          # Ubuntu 24.04.x
myusername/opensuse-leap-15   # openSUSE Leap 15.x
```

**Characteristics:**
- Vagrant user with passwordless sudo
- SSH configured and hardened
- Guest Additions installed (VirtualBox, VMware Tools, etc.)
- Minimal package set
- No additional software

**Use Case:** Starting point for custom provisioning, minimal footprint

---

### Category 2: Purpose-Built Software Boxes

**Purpose:** Entire system configured and optimized for specific software.

**Naming Pattern:** `{software_name}-{software_major}.{software_minor}`

**Examples:**
```
myusername/kubernetes-1.33    # Kubernetes 1.33.x node
myusername/kubernetes-1.34    # Kubernetes 1.34.x node
myusername/kubernetes-1.35    # Kubernetes 1.35.x node
```

**Characteristics:**
- Software version in box name (PRIMARY identity)
- OS is implementation detail (noted in description, can change)
- Entire system configured FOR this software:
  - Kernel tuning (sysctl parameters, swap disabled, etc.)
  - Networking optimized (IPv4 forwarding, CNI-ready, etc.)
  - System services configured (kubelet, container runtime, etc.)
  - Pre-pulled dependencies (CNI plugins, images, etc.)
- Users care about **software version**, not OS version

**When Software Updates:**
- **Patch updates** (1.33.3 → 1.33.7): Minor version bump in same box
- **Minor updates** (1.33 → 1.34): **NEW BOX** created
- **Major updates** (1.x → 2.x): **NEW BOX** created

**Version Description Format:**
```
"{Base OS} {OS Version} | {Software} {Software Version} | {Runtime} {Runtime Version} | Built {Date}"

Example:
"Ubuntu 24.04 | Kubernetes 1.33.3 | containerd 1.7 | Built 2026-01-29"
```

---

### Category 3: Additive Software Variants

**Purpose:** Base OS with additional software installed as enhancement.

**Naming Pattern:** `{os_name}-{os_major}-{variant}`

**Examples:**
```
myusername/debian-12-docker-host      # Debian 12 + Docker Engine
myusername/debian-13-docker-host      # Debian 13 + Docker Engine
myusername/almalinux-9-docker-host    # AlmaLinux 9 + Docker Engine
myusername/debian-12-ansible          # Debian 12 + Ansible + tools
myusername/debian-12-devtools         # Debian 12 + dev tools
```

**Characteristics:**
- OS version in box name (PRIMARY identity)
- Software is addon/variant (in suffix)
- Box is fundamentally still that OS
- No special kernel tuning or system-wide configuration
- Software can be removed/changed without changing box identity
- Users care about **OS version** AND software version

**When OS Updates:**
- **Point releases** (12.12 → 12.13): Minor version bump in same box
- **Major releases** (Debian 12 → 13): **NEW BOX** created

**Version Description Format:**
```
"{OS} {OS Version} | {Software} {Software Version} | {Additional} | Built {Date}"

Example:
"Debian 12.13 | Docker Engine 27.5.0 | Docker Compose v2.33 | Built 2026-04-20"
```

---

## Naming Conventions

### Decision Tree: Which Naming Pattern?

```
Is the box fundamentally DIFFERENT from base OS?
│
├─ YES → Purpose-Built Software Box
│   │
│   ├─ Kernel tuning required? → YES
│   ├─ Custom networking setup? → YES  
│   ├─ System services configured? → YES
│   ├─ OS is just infrastructure? → YES
│   │
│   └─ Name: {software}-{major}.{minor}
│       Examples: kubernetes-1.33, rancher-2.8, openshift-4.14
│
└─ NO → Additive Software Variant
    │
    ├─ Just software installed? → YES
    ├─ OS identity still primary? → YES
    ├─ Software removable easily? → YES
    ├─ Box is "OS + software"? → YES
    │
    └─ Name: {os}-{major}-{variant}
        Examples: debian-12-docker-host, debian-12-ansible
```

### Naming Rules

**All box names:**
- Use **lowercase** letters only
- Use **hyphens** (-) as separators (NOT underscores)
- Include **major version** only (not minor or patch)
- Be **concise** but **descriptive**
- Follow pattern based on category

**Examples - CORRECT:**
```
✅ debian-12
✅ kubernetes-1.33
✅ debian-12-docker-host
✅ almalinux-9
```

**Examples - INCORRECT:**
```
❌ Debian-12                    (uppercase)
❌ debian_12                    (underscore)
❌ debian-12.12                 (includes minor version)
❌ debian-12-base               (redundant suffix for base box)
❌ debian-12.12-docker-host     (OS minor version in name)
```

---

## Versioning Strategy

### SemVer Format: `MAJOR.MINOR.PATCH`

All boxes start at `1.0.0` and increment according to semantic versioning rules.

### Semantic Rules by Box Category

#### Base OS Boxes (`debian-12`, `almalinux-9`)

| Change | Version Bump | Example | Rationale |
|--------|--------------|---------|-----------|
| OS point release (12.12 → 12.13) | Minor | `1.0.0 → 1.1.0` | Security updates, kernel updates (significant) |
| Guest Additions update | Minor | `1.0.0 → 1.1.0` | Provider integration changes |
| Script bug fix | Patch | `1.1.0 → 1.1.1` | No software changes |
| Removed default package | Major | `1.5.0 → 2.0.0` | Breaking change for users |
| OS major upgrade | **NEW BOX** | `debian-13` v1.0.0 | Different OS major = different box |

---

#### Purpose-Built Software Boxes (`kubernetes-1.33`)

| Change | Version Bump | Example | Rationale |
|--------|--------------|---------|-----------|
| Software patch (k8s 1.33.3 → 1.33.7) | Minor | `1.0.0 → 1.1.0` | Software version changed |
| OS point release (Ubuntu 24.04 → 24.04.1) | Patch or Minor | `1.0.0 → 1.0.1` | OS is infrastructure, k8s unchanged |
| Base OS change (Ubuntu → Debian) | Minor | `1.1.0 → 1.2.0` | Implementation detail, k8s unchanged |
| Container runtime change (CRI-O → containerd) | Major | `1.5.0 → 2.0.0` | Breaking configuration change |
| Software minor (k8s 1.33 → 1.34) | **NEW BOX** | `kubernetes-1.34` v1.0.0 | Software minor = new box |
| Software major (k8s 1.x → 2.x) | **NEW BOX** | `kubernetes-2.0` v1.0.0 | Software major = new box |

**Key Insight:** OS changes are **minor** (software is primary), software changes create **new boxes**.

---

#### Additive Variant Boxes (`debian-12-docker-host`)

| Change | Version Bump | Example | Rationale |
|--------|--------------|---------|-----------|
| OS point release (12.12 → 12.13) | Minor | `1.0.0 → 1.1.0` | OS change is significant |
| Software patch (Docker 27.4.1 → 27.4.2) | Patch | `1.1.0 → 1.1.1` | Software patch only |
| Software minor (Docker 27.4 → 27.5) | Minor | `1.1.0 → 1.2.0` | Software minor update |
| Software major (Docker 27.x → 28.x) | Major | `1.5.0 → 2.0.0` | Software major (breaking) |
| OS major (Debian 12 → 13) | **NEW BOX** | `debian-13-docker-host` v1.0.0 | OS major = new box |

**Key Insight:** OS changes drive versioning (OS is primary), OS major upgrade = new box.

---

## Complete Box Matrix

### Planned Repository Structure:

```
BASE OS BOXES:
  myusername/debian-12              (v1.x.x)
  myusername/debian-13              (v1.x.x)
  myusername/almalinux-9            (v1.x.x)
  myusername/ubuntu-24              (v1.x.x)
  myusername/opensuse-leap-15       (v1.x.x)

PURPOSE-BUILT SOFTWARE BOXES:
  myusername/kubernetes-1.33        (v1.x.x - k8s 1.33.x on Ubuntu/Debian)
  myusername/kubernetes-1.34        (v1.x.x - k8s 1.34.x on Ubuntu/Debian)
  myusername/kubernetes-1.35        (v1.x.x - k8s 1.35.x on Ubuntu/Debian)

ADDITIVE SOFTWARE VARIANTS:
  myusername/debian-12-docker-host  (v1.x.x - Debian 12 + Docker)
  myusername/debian-13-docker-host  (v1.x.x - Debian 13 + Docker)
  myusername/almalinux-9-docker-host (v1.x.x - AlmaLinux 9 + Docker)
  myusername/debian-12-ansible      (v1.x.x - Debian 12 + Ansible)
  myusername/debian-12-devtools     (v1.x.x - Debian 12 + dev tools)
```

**Total Boxes:** ~15-20 (scales cleanly as new OS/software versions are added)

---

## Version Progression Examples

### Example 1: Base Box (debian-12)

```
Box: myusername/debian-12

1.0.0 (2026-01-29)
  Description: "Debian 12.12 base | VirtualBox Guest Additions 7.1.6 | Built 2026-01-29"
  Changes:
    - Initial release
    - Debian 12.12
    - VirtualBox 7.1.6 support
    - Vagrant user configured

1.1.0 (2026-03-15)
  Description: "Debian 12.13 base | VirtualBox Guest Additions 7.1.8 | Built 2026-03-15"
  Changes:
    - Updated Debian 12.12 → 12.13 (security updates, kernel bump)
    - Updated VirtualBox Guest Additions 7.1.6 → 7.1.8
    - Minor version bump (OS point release)

1.1.1 (2026-03-20)
  Description: "Debian 12.13 base | VirtualBox Guest Additions 7.1.8 | Built 2026-03-20"
  Changes:
    - Fixed SSH hardening script bug
    - No OS or software version changes
    - Patch version bump (script fix only)

1.2.0 (2026-06-10)
  Description: "Debian 12.14 base | VirtualBox Guest Additions 7.2.0 | Built 2026-06-10"
  Changes:
    - Updated Debian 12.13 → 12.14
    - Updated VirtualBox Guest Additions 7.1.8 → 7.2.0
    - Added support for VMware provider
    - Minor version bump (OS update + new provider)

2.0.0 (2027-06-15)
  Description: "Debian 13.0 base | VirtualBox Guest Additions 8.0.0 | Built 2027-06-15"
  Changes:
    - BREAKING: Debian 12 → 13 major OS upgrade
    - NOTE: Create NEW BOX debian-13 instead of major bump
    - This is listed here for reference only
```

**Correction:** OS major upgrade should create **NEW BOX** (`debian-13`), not major version bump.

---

### Example 2: Purpose-Built Box (kubernetes-1.33)

```
Box: myusername/kubernetes-1.33

1.0.0 (2026-01-29)
  Description: "Ubuntu 24.04 | Kubernetes 1.33.3 | containerd 1.7.13 | Built 2026-01-29"
  Changes:
    - Initial release on Ubuntu 24.04
    - Kubernetes 1.33.3 (kubeadm, kubectl, kubelet)
    - containerd 1.7.13 runtime
    - Calico 3.27.3, Flannel 0.25.1 CNI pre-pulled

1.0.1 (2026-02-10)
  Description: "Ubuntu 24.04 | Kubernetes 1.33.3 | containerd 1.7.13 | Built 2026-02-10"
  Changes:
    - Fixed CNI pre-pull script error
    - Same k8s version (1.33.3)
    - Patch version bump (script fix)

1.1.0 (2026-03-15)
  Description: "Ubuntu 24.04.1 | Kubernetes 1.33.7 | containerd 1.7.14 | Built 2026-03-15"
  Changes:
    - Kubernetes 1.33.3 → 1.33.7 (patch release with security fixes)
    - containerd 1.7.13 → 1.7.14
    - Ubuntu 24.04 → 24.04.1 (minor OS update, transparent to users)
    - Minor version bump (k8s patch is significant)

1.2.0 (2026-06-10)
  Description: "Debian 12.14 | Kubernetes 1.33.7 | containerd 1.7.15 | Built 2026-06-10"
  Changes:
    - CHANGED BASE OS: Ubuntu 24.04 → Debian 12.14
    - Kubernetes unchanged (still 1.33.7)
    - Reason: Better compatibility with enterprise environments
    - Note: Users don't care (k8s functionality identical)
    - Minor version bump (implementation change, not breaking)

2.0.0 (2026-08-01)
  Description: "Debian 12.15 | Kubernetes 1.33.7 | CRI-O 1.33 | Built 2026-08-01"
  Changes:
    - BREAKING: Changed container runtime containerd → CRI-O
    - Kubernetes unchanged (still 1.33.7)
    - Users must update configurations (different socket path)
    - Major version bump (breaking configuration change)
```

**Note on Kubernetes 1.34 release:**
When Kubernetes 1.34 is released, create **NEW BOX**: `myusername/kubernetes-1.34` starting at `v1.0.0`.

---

### Example 3: Additive Variant Box (debian-12-docker-host)

```
Box: myusername/debian-12-docker-host

1.0.0 (2026-01-29)
  Description: "Debian 12.12 | Docker Engine 27.4.1 | Docker Compose v2.32.4 | Built 2026-01-29"
  Changes:
    - Initial release
    - Debian 12.12 base
    - Docker Engine 27.4.1
    - Docker Compose v2.32.4 (plugin)
    - Vagrant user in docker group

1.1.0 (2026-03-15)
  Description: "Debian 12.13 | Docker Engine 27.4.1 | Docker Compose v2.32.4 | Built 2026-03-15"
  Changes:
    - Debian 12.12 → 12.13 (OS update is significant)
    - Docker unchanged (27.4.1)
    - Security patches: CVE-2026-1234, CVE-2026-5678
    - Minor version bump (OS update)

1.1.1 (2026-03-20)
  Description: "Debian 12.13 | Docker Engine 27.4.2 | Docker Compose v2.32.4 | Built 2026-03-20"
  Changes:
    - Docker Engine 27.4.1 → 27.4.2 (patch release, bug fixes only)
    - Debian unchanged (12.13)
    - Patch version bump (Docker patch)

1.2.0 (2026-06-10)
  Description: "Debian 12.13 | Docker Engine 27.5.0 | Docker Compose v2.33.0 | Built 2026-06-10"
  Changes:
    - Docker Engine 27.4.2 → 27.5.0 (minor update, new features)
    - Docker Compose v2.32.4 → v2.33.0
    - Minor version bump (Docker minor update)

2.0.0 (2026-12-01)
  Description: "Debian 12.15 | Docker Engine 28.0.0 | Docker Compose v2.40.0 | Built 2026-12-01"
  Changes:
    - BREAKING: Docker Engine 27.x → 28.0.0 (major update, breaking changes)
    - Docker Compose v2.33.0 → v2.40.0
    - New Docker CLI syntax (breaking)
    - Major version bump (Docker major is breaking)
```

**Note on Debian 13 release:**
When Debian 13 is released, create **NEW BOX**: `myusername/debian-13-docker-host` starting at `v1.0.0`.
Maintain `debian-12-docker-host` until Debian 12 EOL.

---

## CHANGELOG Format

Use **[Keep a Changelog](https://keepachangelog.com/)** format.

### Template:

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- (Future features planned)

### Changed
- (Future changes planned)

## [1.2.0] - 2026-04-20

### Added
- Kubernetes 1.34.0 support (upgraded from 1.33.3)
- CRI-O 1.34 container runtime
- Calico 3.28.0 CNI plugin (pre-pulled)
- Flannel 0.26.0 support

### Changed
- Updated Debian 12.13 → 12.13 (no change, rebuild with k8s 1.34)
- Kernel tuning: added new sysctl parameters for k8s 1.34

### Fixed
- None

### Security
- None

### Deprecated
- None

### Removed
- None

## [1.1.0] - 2026-03-15

### Changed
- Updated Debian 12.12 → 12.13
- Security patches: CVE-2026-1234, CVE-2026-5678
- Kernel: 6.1.0-17 → 6.1.0-18

### Fixed
- SSH hardening: fixed PermitRootLogin config
- Networking: fixed IPv6 disable script

## [1.0.0] - 2026-01-29

### Added
- Initial release
- Debian 12.12 base system
- Kubernetes 1.33.3 (kubeadm, kubectl, kubelet)
- CRI-O 1.33 container runtime
- Pre-pulled CNI plugins: Calico 3.27.3, Flannel 0.25.1
- VirtualBox Guest Additions 7.1.6
- Vagrant user with passwordless sudo

[Unreleased]: https://github.com/username/repo/compare/v1.2.0...HEAD
[1.2.0]: https://github.com/username/repo/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/username/repo/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/username/repo/releases/tag/v1.0.0
```

### Categories (Keep a Changelog):

- **Added:** New features
- **Changed:** Changes in existing functionality
- **Deprecated:** Soon-to-be removed features
- **Removed:** Removed features
- **Fixed:** Bug fixes
- **Security:** Security fixes (highlight CVEs)

---

## Metadata Strategy

### Version Description Template

**Purpose-Built Boxes:**
```
"{Base OS} {OS Version} | {Software} {Software Version} | {Runtime} {Runtime Version} | Built {Date}"

Example:
"Ubuntu 24.04 | Kubernetes 1.33.3 | containerd 1.7 | Built 2026-01-29"
```

**Additive Variant Boxes:**
```
"{OS} {OS Version} | {Software} {Software Version} | {Additional} | Built {Date}"

Example:
"Debian 12.13 | Docker Engine 27.5.0 | Docker Compose v2.33 | Built 2026-04-20"
```

**Base OS Boxes:**
```
"{OS} {OS Version} base | {Provider} Guest Additions {Version} | Built {Date}"

Example:
"Debian 12.13 base | VirtualBox Guest Additions 7.1.8 | Built 2026-03-15"
```

### Box Description (Vagrant Cloud Page)

#### Purpose-Built Box Example:

```markdown
# Kubernetes 1.33 Node

Production-ready Kubernetes 1.33 node for building clusters.

## What's Included

- **Kubernetes:** 1.33.x (kubeadm, kubectl, kubelet)
- **Container Runtime:** containerd 1.7 (OCI-compliant)
- **CNI Plugins:** Pre-pulled (Calico, Flannel, Cilium)
- **Base OS:** Ubuntu 24.04 LTS (as of v1.0.0+)
- **Kernel:** Optimized for Kubernetes (swap disabled, networking tuned)
- **Ready for:** kubeadm init/join

## Version Guide

| Box Version | Kubernetes | Container Runtime | Base OS |
|-------------|------------|-------------------|---------|
| 1.2.x       | 1.33.7     | containerd 1.7.15 | Debian 12.14 |
| 1.1.x       | 1.33.7     | containerd 1.7.14 | Ubuntu 24.04.1 |
| 1.0.x       | 1.33.3     | containerd 1.7.13 | Ubuntu 24.04 |

**Note:** Base OS may change between versions. Kubernetes functionality remains identical.

## Supported Kubernetes Versions

This box supports **Kubernetes 1.33.x** only.

For other versions:
- Kubernetes 1.34 → Use `myusername/kubernetes-1.34`
- Kubernetes 1.32 → Use `myusername/kubernetes-1.32`

## Quick Start

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "myusername/kubernetes-1.33"
  config.vm.box_version = "~> 1.0"
  
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "4096"
    vb.cpus = 2
  end
end
```

## Initialize Cluster

```bash
vagrant ssh
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
```

## Resources

- [GitHub Repository](https://github.com/username/repo)
- [Full Changelog](https://github.com/username/repo/blob/main/CHANGELOG.md)
- [Report Issues](https://github.com/username/repo/issues)

## License

Apache-2.0
```

#### Additive Variant Box Example:

```markdown
# Debian 12 Docker Host

Debian 12 with Docker Engine and Docker Compose pre-installed.

## What's Included

- **OS:** Debian 12 (latest point release)
- **Docker Engine:** 27.x (latest stable)
- **Docker Compose:** v2.x (plugin)
- **Docker user:** Vagrant user in docker group
- **Systemd:** Docker service enabled

## Version Guide

| Box Version | Debian | Docker Engine | Docker Compose |
|-------------|--------|---------------|----------------|
| 1.2.x       | 12.13  | 27.5.0        | v2.33.0        |
| 1.1.x       | 12.13  | 27.4.1        | v2.32.4        |
| 1.0.x       | 12.12  | 27.4.1        | v2.32.4        |

## Supported Debian Versions

This box is based on **Debian 12 (Bookworm)**.

For other versions:
- Debian 13 → Use `myusername/debian-13-docker-host` (when available)
- Debian 11 → Use `myusername/debian-11-docker-host` (EOL 2026)

## Quick Start

```ruby
Vagrant.configure("2") do |config|
  config.vm.box = "myusername/debian-12-docker-host"
  config.vm.box_version = "~> 1.0"
  
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
    vb.cpus = 2
  end
end
```

## Run Docker

```bash
vagrant ssh
docker run hello-world
docker compose version
```

## Resources

- [GitHub Repository](https://github.com/username/repo)
- [Full Changelog](https://github.com/username/repo/blob/main/CHANGELOG.md)

## License

Apache-2.0
```

---

## Upgrade Workflows

### Scenario 1: OS Security Update (Additive Variant)

**Box:** `debian-12-docker-host`

**Your Action:**
1. Update base box: Debian 12.12 → 12.13
2. Rebuild `debian-12-docker-host` with same Docker version
3. Bump version: `1.0.0 → 1.1.0` (minor: OS changed)
4. Update CHANGELOG:
   ```markdown
   ## [1.1.0] - 2026-03-15
   
   ### Changed
   - Updated Debian 12.12 → 12.13
   - Security patches: CVE-2026-1234, CVE-2026-5678
   
   ### Fixed
   - None
   ```
5. Publish to Vagrant Cloud

**User Experience:**
```bash
# User has 1.0.0 (Debian 12.12, Docker 27.4.1)
vagrant box outdated
# Newer version available: 1.1.0

vagrant box update  # Downloads 1.1.0
vagrant destroy && vagrant up  # Rebuilt with Debian 12.13
```

---

### Scenario 2: Software Update (Purpose-Built)

**Box:** `kubernetes-1.33`

**Your Action:**
1. Update k8s: 1.33.3 → 1.33.7 (patch release)
2. Update containerd: 1.7.13 → 1.7.14
3. Rebuild box
4. Bump version: `1.0.0 → 1.1.0` (minor: k8s changed)
5. Update CHANGELOG clearly stating k8s upgrade

**User Experience:**
```ruby
# Vagrantfile
config.vm.box = "myusername/kubernetes-1.33"
config.vm.box_version = "~> 1.0"  # Pessimistic constraint

# After your publish of 1.1.0:
vagrant box outdated
# Newer version available: 1.1.0 (compatible with ~> 1.0)

vagrant box update  # Downloads 1.1.0
vagrant destroy && vagrant up  # Rebuilt with k8s 1.33.7
```

---

### Scenario 3: Critical Security Fix

**Box:** `debian-12-base`

**Your Action:**
1. Fix vulnerability in provisioning script
2. No software version changes
3. Rebuild box
4. Bump version: `1.1.0 → 1.1.1` (patch: script fix only)
5. Update CHANGELOG with CVE details:
   ```markdown
   ## [1.1.1] - 2026-03-20
   
   ### Security
   - Fixed CVE-2026-9999 in SSH configuration
   - RECOMMENDED: Destroy and recreate VMs
   
   ### Fixed
   - SSH: PermitRootLogin now correctly set to 'no'
   ```

**User Experience:**
```bash
vagrant box outdated
# Security update available: 1.1.1

# CHANGELOG shows critical CVE fix
vagrant box update
vagrant destroy && vagrant up  # Apply security fix
```

---

### Scenario 4: Software Minor Version (Create New Box)

**Current Box:** `kubernetes-1.33` (latest: v1.5.0)

**Kubernetes 1.34 Released:**

**Your Action:**
1. **Create NEW BOX:** `kubernetes-1.34`
2. Version: `1.0.0` (fresh start)
3. Update base repository:
   - Add `os_pkrvars/kubernetes-1.34.pkrvars.hcl`
   - Add Makefile target: `kubernetes-1-34`
4. Build and publish
5. Announce in `kubernetes-1.33` description:
   ```markdown
   ## Version Notice
   
   Kubernetes 1.34 is now available in a separate box:
   → Use `myusername/kubernetes-1.34` for k8s 1.34.x
   
   This box (kubernetes-1.33) will receive maintenance updates until k8s 1.33 EOL.
   ```

**User Migration:**
```ruby
# Old Vagrantfile (k8s 1.33)
config.vm.box = "myusername/kubernetes-1.33"
config.vm.box_version = "~> 1.0"

# New Vagrantfile (k8s 1.34) - manual change required
config.vm.box = "myusername/kubernetes-1.34"
config.vm.box_version = "~> 1.0"
```

---

### Scenario 5: OS Major Upgrade (Create New Box)

**Current Box:** `debian-12-docker-host` (latest: v1.5.0)

**Debian 13 Released:**

**Your Action:**
1. **Create NEW BOX:** `debian-13-docker-host`
2. Version: `1.0.0` (fresh start)
3. Update base repository:
   - Add `os_pkrvars/debian/13-x86_64.pkrvars.hcl`
   - Add Makefile target: `debian-13-docker-host`
4. Build and publish
5. Update `debian-12-docker-host` description:
   ```markdown
   ## Debian 13 Available
   
   Debian 13 is now available in a separate box:
   → Use `myusername/debian-13-docker-host` for Debian 13
   
   This box (debian-12-docker-host) will be maintained until Debian 12 EOL (2028).
   ```

**User Migration:**
```ruby
# Debian 12 + Docker (current)
config.vm.box = "myusername/debian-12-docker-host"
config.vm.box_version = "~> 1.0"

# Debian 13 + Docker (manual migration when ready)
config.vm.box = "myusername/debian-13-docker-host"
config.vm.box_version = "~> 1.0"
```

---

## Implementation Plan

### Phase 1: Foundation (Week 1)

**Repository Setup:**
1. Create `VERSION` file in repo root: `1.0.0`
2. Create `CHANGELOG.md` following Keep a Changelog format
3. Create `builds/metadata/` directory structure
4. Add box metadata JSON templates

**Documentation:**
5. Update `README.md` with versioning strategy summary
6. Create `docs/VERSIONING.md` (this document)
7. Update `AGENTS.md` with versioning references

---

### Phase 2: Base Boxes (Week 2)

**Initial Boxes:**
1. Build and publish: `myusername/debian-12` v1.0.0
2. Build and publish: `myusername/almalinux-9` v1.0.0
3. Test Vagrant Cloud publishing workflow
4. Verify version descriptions and metadata

---

### Phase 3: Purpose-Built Software (Week 3-4)

**Kubernetes Box:**
1. Decide on base OS (Ubuntu 24.04 or Debian 12)
2. Build and publish: `myusername/kubernetes-1.33` v1.0.0
3. Document base OS choice in box description
4. Test kubeadm cluster creation

---

### Phase 4: Additive Variants (Week 5)

**Docker Boxes:**
1. Build and publish: `myusername/debian-12-docker-host` v1.0.0
2. Optional: `myusername/debian-12-ansible` v1.0.0
3. Test Docker functionality

---

### Phase 5: Automation (Week 6)

**Build Automation:**
1. Update Makefile/Rakefile with version management:
   - Read version from `VERSION` file
   - Generate metadata JSON
   - Automate Vagrant Cloud upload
2. Create `scripts/vagrant-cloud-publish.sh`
3. Add pre-publish validation checks

---

## References

### Inspiration Sources

**alvistack:**
- GitHub: https://github.com/alvistack/vagrant-debian
- GitHub: https://github.com/alvistack/vagrant-kubernetes
- Versioning: `YYYYMMDD.Y.Z` (CalVer with rolling `.0.0` releases)
- Strategy: Separate boxes per software major.minor version
- Example: `kubernetes-1.33`, `kubernetes-1.34` (separate boxes)

**HashiCorp Vagrant Cloud:**
- Documentation: https://developer.hashicorp.com/vagrant/vagrant-cloud
- Constraints: Strict `X.Y.Z` format (no pre-release, no build metadata)
- Provider support: Multiple providers per box/version
- Versioning: https://developer.hashicorp.com/vagrant/docs/boxes/versioning

**Keep a Changelog:**
- Website: https://keepachangelog.com/
- Format: Structured changelog categories
- Versioning: Links to comparison views

**Semantic Versioning:**
- Website: https://semver.org/
- Format: `MAJOR.MINOR.PATCH`
- Meaning: Breaking.Feature.Fix

---

### Related Documentation

**In This Repository:**
- `README.md` - Project overview and quick start
- `AGENTS.md` - AI coding agent guidance (includes versioning references)
- `CHANGELOG.md` - Actual changelog for this repository
- `packer_templates/variables.pkr.hcl` - Variant variable definitions
- `os_pkrvars/AGENTS.md` - Variable file creation guidance

**External:**
- Vagrant Cloud API: https://developer.hashicorp.com/vagrant/vagrant-cloud/api
- Packer Vagrant Post-Processor: https://developer.hashicorp.com/packer/plugins/post-processors/vagrant/vagrant-cloud

---

## Appendix: Decision Log

### Key Decisions Made

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-01-29 | Use SemVer instead of CalVer | Build date not critical; semantic meaning preferred; no automated rebuilds planned |
| 2026-01-29 | Separate boxes per variant | Following alvistack approach; clearer separation; independent versioning |
| 2026-01-29 | Include distro identifier in variant names | User preference; makes box name self-documenting |
| 2026-01-29 | **Purpose-Built vs Additive distinction** | **CRITICAL:** Kubernetes is purpose-built (software-centric), Docker is additive (OS-centric) |
| 2026-01-29 | Purpose-built boxes use `{software}-{version}` naming | Software version is primary identity; OS is implementation detail |
| 2026-01-29 | Additive variants use `{os}-{version}-{variant}` naming | OS version is primary identity; software is enhancement |
| 2026-01-29 | OS changes in purpose-built = minor bump | OS is infrastructure; software version unchanged |
| 2026-01-29 | OS major in additive variants = new box | OS identity changed; requires new box |
| 2026-01-29 | Software minor in purpose-built = new box | Following alvistack; `kubernetes-1.33` vs `kubernetes-1.34` |

### Future Considerations

**Under Review:**
- Rolling release support (`.0.0` suffix like alvistack) - Currently: NO
- Automated weekly rebuilds - Currently: NO
- Multi-architecture support (ARM) - Currently: NO (removed in v3.3.0)
- Additional purpose-built boxes (Rancher, OpenShift) - TBD
- Additional additive variants (GitLab Runner, Jenkins) - TBD

**When to Reconsider:**
- Rolling releases: If CI/CD pipeline established for weekly builds
- Multi-arch: If ARM demand increases or Apple Silicon usage grows
- New boxes: Based on user demand and project scope

---

## Document Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-01-29 | Initial versioning strategy document created based on comprehensive analysis of alvistack approach, HashiCorp constraints, and Oracle recommendations. Includes critical Purpose-Built vs Additive distinction. |

---

**END OF DOCUMENT**
