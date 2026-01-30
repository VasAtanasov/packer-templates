---
title: Packer Vagrant Box Builder (Multi-Provider)
status: Active
version: 3.1.0
scope: Consolidated template structure for building Vagrant boxes
---

# Packer Vagrant Box Builder (Multi-Provider)

Packer setup for building Debian-based Vagrant boxes with support for multiple providers (VirtualBox, with VMware and
QEMU planned). Uses a **consolidated template structure** with all Packer configuration in a single directory. Provider
and OS selection happens via variables passed at build time. Currently focused on Debian 12/13 with VirtualBox.
Host-agnostic (works on Windows, Linux, macOS).

## Highlights

- **Consolidated templates**: All `.pkr.hcl` files in `packer_templates/` root directory
- **Single source of truth**: Provider/OS selection via variables, not directory structure
- **Simplified variables**: `12-x86_64.pkrvars.hcl` instead of verbose naming
- **Variant support**: Build base, k8s-node, or docker-host boxes via `-var` flags
- **3-phase provisioning**: System prep → OS config → cleanup/minimize
- **Cross-platform**: Windows (Rake), Linux/macOS (Make) with full parity

## Quick Start

```bash
# 1) Check environment
make check-env          # or: rake check_env (Windows)

# 2) Initialize Packer plugins
make init               # or: rake init (Windows)

# 3) Build a box
make debian-12          # Base box (recommended)
make debian-12-k8s      # Kubernetes node variant
make debian-12-docker   # Docker host variant
```

## Requirements

- Packer >= 1.7.0
- VirtualBox >= 7.1.6
- Vagrant >= 2.4.0 (for testing)
- Make (Linux/macOS) or Rake (Windows) for convenience commands

## Common Commands

| Command                                                             | Description                                    |
|---------------------------------------------------------------------|------------------------------------------------|
| `make debian-12`                                                    | Build Debian 12 x86_64 base box (recommended)  |
| `make debian-12-k8s`                                                | Build Debian 12 x86_64 Kubernetes node         |
| `make debian-12-docker`                                             | Build Debian 12 x86_64 Docker host             |
| `make debian-13`                                                    | Build Debian 13 x86_64 base box                |
| `make almalinux-9`                                                  | Build AlmaLinux 9 x86_64 base box              |
| `make debian-12-ovf`                                                | Build Debian 12 x86_64 base box from OVF       |
| `make almalinux-9-ovf`                                              | Build AlmaLinux 9 x86_64 base box from OVF     |
| `make build TEMPLATE=debian/12-x86_64.pkrvars.hcl`                  | Build specific template (base variant)         |
| `make build TEMPLATE=debian/12-x86_64.pkrvars.hcl VARIANT=k8s-node` | Build with variant                             |
| `make validate`                                                     | Validate all templates                         |
| `make clean`                                                        | Remove build artifacts                         |
| `make list-templates`                                               | Show available templates                       |
| `make debug`                                                        | Show configuration (PROVIDER, TARGET_OS, etc.) |
| `make build TEMPLATE=... DEBUG=1`                                   | Build with verbose logging to builds/packer-debug.log |
| `make debian-12 DEBUG=1`                                            | Any convenience target supports DEBUG=1        |
| `make help`                                                         | Show all available commands                    |

**Windows users:** Replace `make` with `rake` and use underscores (e.g., `rake debian_12_k8s`)

## Build Process (3 Phases)

Provisioner strategy:

- Upload entire `packer_templates/scripts/` tree to `/tmp/packer-scripts` (once, ephemeral)
- Copy entire tree to `/usr/local/lib/scripts/` (persistent, survives reboots and cleanups)
- All provisioners reference scripts from `/usr/local/lib/scripts/`
- Scripts source modular libraries via env vars:
    - `LIB_CORE_SH=/usr/local/lib/scripts/_common/lib-core.sh`
    - `LIB_OS_SH=/usr/local/lib/scripts/_common/lib-debian.sh` (or `lib-rhel.sh`)
- Final cleanup removes entire `/usr/local/lib/scripts/` directory (no build helpers in final box)

**Key benefit:** Scripts uploaded once and survive system reboots (Phase 1) and `/tmp` cleanup (Phase 3a)

### Phase 1: System Preparation

- Update all packages
- Disable automatic updates (for reproducible builds)

### Phase 2: OS Configuration

- Phase 2a: Provider dependencies (VirtualBox kernel headers, build tools)
- Phase 2b: Provider integration (VirtualBox Guest Additions - installed by default)
- Phase 2c: Base config (Vagrant user, SSH, networking, sudoers, systemd)
- Phase 2d: Variant provisioning (only for non-base variants)
    - **k8s-node**: Kernel config, container runtime (containerd/CRI-O), Kubernetes binaries
    - **docker-host**: Docker engine and Docker Compose

### Phase 3: Cleanup & Minimization

- Phase 3a: Remove unnecessary packages (build tools, docs, etc.)
- Phase 3b: Clear logs, temporary files, zero free space for better compression
- Final: Remove build-only helpers (`/usr/local/lib/scripts/`)

## Versioning Strategy

This project uses **independent Semantic Versioning (X.Y.Z)** for all boxes.

- **Base OS Boxes** (`vaatech/debian-12`):
  - Minor: OS point releases (12.12 → 12.13)
  - Patch: Bug fixes
- **Purpose-Built Boxes** (`vaatech/kubernetes-1.33`):
  - Minor: Software patch updates (k8s 1.33.3 → 1.33.7)
  - Major: Breaking configuration changes
  - **New Box:** Created for each software minor version (k8s 1.34 = `vaatech/kubernetes-1.34`)
- **Additive Variants** (`vaatech/debian-12-docker-host`):
  - Minor: OS point releases or software minor updates
  - Patch: Bug fixes
  - **New Box:** Created for OS major versions (`debian-13-docker-host`)

See [docs/VERSIONING.md](docs/VERSIONING.md) for full details.

## Using Built Boxes

After building, the `.box` file is located in `builds/build_complete/`:

```bash
# Add box to Vagrant (naming: <os>-<version>-<arch>.virtualbox.box)
vagrant box add --name debian-12 \
  builds/build_complete/debian-12.12-x86_64.virtualbox.box

# Use in a Vagrantfile
vagrant init debian-12
vagrant up
```

## Advanced Usage

### Building from Command Line

```bash
# Base box
packer build \
  -var-file=os_pkrvars/debian/12-x86_64.pkrvars.hcl \
  packer_templates/

# With variant (latest patch from 1.33 release)
packer build \
  -var-file=os_pkrvars/debian/12-x86_64.pkrvars.hcl \
  -var=variant=k8s-node \
  -var=kubernetes_version=1.33 \
  -var=cpus=2 -var=memory=4096 -var=disk_size=61440 \
  packer_templates/

# With variant (specific patch version)
packer build \
  -var-file=os_pkrvars/debian/12-x86_64.pkrvars.hcl \
  -var=variant=k8s-node \
  -var=kubernetes_version=1.33.1 \
  -var=cpus=2 -var=memory=4096 -var=disk_size=61440 \
  packer_templates/
```

### Customizing a Build

Edit or create a `.pkrvars.hcl` in `os_pkrvars/<os_name>/`:

```hcl
// os_pkrvars/debian/12-x86_64.pkrvars.hcl
os_name    = "debian"
os_version = "12.12"
os_arch = "x86_64"

iso_url      = "https://cdimage.debian.org/..."
iso_checksum = "file:https://cdimage.debian.org/.../SHA256SUMS"

vbox_guest_os_type = "Debian12_64"
boot_command = [
  "<wait><esc><wait>auto preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg netcfg/get_hostname={{ .Name }}<enter>"
]

// Default resources (override via -var flags for variants)
cpus   = 2
memory = 2048
disk_size = 40960

// Default to base variant (override via -var='variant=k8s-node')
variant = "base"

// Optional: Custom VBoxManage commands
vboxmanage = [
  ["modifyvm", "{{.Name}}", "--chipset", "ich9"],
  ["modifyvm", "{{.Name}}", "--audio-enabled", "off"]
]
```

### Environment Variables

```bash
# Build with specific OS template files (Linux/macOS)
make build TEMPLATE=debian/12-x86_64.pkrvars.hcl TARGET_OS=debian

# Build with specific OS template files (Windows)
rake build TEMPLATE=debian/12-x86_64.pkrvars.hcl TARGET_OS=debian

# Note: TARGET_OS controls which os_pkrvars/<os>/ directory to use
# Note: PROVIDER is informational - provider selection happens via variables in .pkrvars.hcl
```

## Troubleshooting

### Debugging and Logging

**Enable verbose logging to see which scripts are executed:**

```bash
# Linux/macOS - All convenience targets support DEBUG=1
make debian-12 DEBUG=1
make debian-12-k8s DEBUG=1
make build TEMPLATE=debian/12-x86_64.pkrvars.hcl DEBUG=1

# Windows
rake debian_12 DEBUG=1
rake debian_12_k8s DEBUG=1
rake build TEMPLATE=debian/12-x86_64.pkrvars.hcl DEBUG=1
```

**What you'll see with DEBUG=1:**
- Detailed logs written to `builds/packer-debug.log`
- Every script path being executed by Packer
- Full output from each provisioner
- Environment variables passed to scripts (LIB_CORE_SH, LIB_OS_SH, etc.)
- Plugin messages prefixed by provider (e.g., `virtualbox-iso: Running script...`)

**Manual Packer logging (without Make/Rake):**

```bash
# Linux/macOS
export PACKER_LOG=1
export PACKER_LOG_PATH="builds/packer-debug.log"
packer build -var-file=os_pkrvars/debian/12-x86_64.pkrvars.hcl packer_templates/

# Windows PowerShell
$env:PACKER_LOG=1
$env:PACKER_LOG_PATH="builds/packer-debug.log"
packer build -var-file=os_pkrvars/debian/12-x86_64.pkrvars.hcl packer_templates/
```

**Interactive debugging (step-by-step execution):**

```bash
# Pauses between each provisioner - press Enter to continue
packer build -debug -var-file=os_pkrvars/debian/12-x86_64.pkrvars.hcl packer_templates/

# On failure, ask what to do (cleanup, abort, or retry)
packer build -on-error=ask -var-file=os_pkrvars/debian/12-x86_64.pkrvars.hcl packer_templates/
```

### Guest Additions

Boxes expect Guest Additions to be installed during provisioning. Ensure
`vbox_guest_additions_mode` is set to `attach` or `upload` and that
`scripts/providers/virtualbox/guest_additions.sh` is included in Phase 2. Override the
ISO path via `vbox_guest_additions_path` if needed.

### Build Hangs at Boot

Set `headless = false` in your `.pkrvars.hcl` to view the VirtualBox GUI.

## Template Architecture

Current structure:

```
packer_templates/
  variables.pkr.hcl         # All Packer variables
  locals.pkr.hcl            # Computed locals and logic
  sources.pkr.hcl           # Source definitions (virtualbox-iso, vmware-iso, etc.)
  build.pkr.hcl             # Build block with provisioners and post-processors
  plugins.pkr.hcl           # Required plugins
  http/                     # HTTP server files for installer
    debian/                 # Debian preseed files
      preseed.cfg
    rhel/                   # RHEL/AlmaLinux kickstart files (planned)
  scripts/                  # Shared provisioning scripts
    _common/                # Cross-distro scripts + modular libraries
      lib-core.sh           # OS-agnostic helpers
      lib-debian.sh         # Debian/Ubuntu APT helpers
      lib-rhel.sh           # AlmaLinux/Rocky DNF helpers
    debian/                 # Debian-specific scripts
    providers/              # Provider-specific scripts
      virtualbox/           # VirtualBox integration (per-OS subdirs)
        common/             # Shared across OS families
        debian/             # Debian/Ubuntu wrappers or overrides
        rhel/               # RHEL-family wrappers or overrides
    variants/               # Variant-specific scripts (per-OS subdirectories)
      k8s-node/
        common/             # OS-agnostic steps (prepare/kernel/networking)
        debian/             # Debian/Ubuntu steps (runtime + Kubernetes)
        rhel/               # RHEL family steps (planned)
      docker-host/
        debian/             # Debian/Ubuntu steps (install + configure)
        rhel/               # RHEL family steps (planned)

os_pkrvars/
  debian/                   # Debian variable files
    12-x86_64.pkrvars.hcl   # Debian 12 x86_64 (base + all variants)
    13-x86_64.pkrvars.hcl   # Debian 13 x86_64
```

**Why this structure:**

- **Single source of truth**: All templates in one place, easier to maintain
- **Provider flexibility**: Add providers by extending `sources.pkr.hcl` and `build.pkr.hcl`
- **OS flexibility**: Add OSes via new http subdirs and os_pkrvars entries
- **No refactoring**: Future expansion happens via configuration, not restructuring
- **Packer auto-aggregation**: All `.pkr.hcl` files in a directory are automatically combined

### Variant Script Selection (Dynamic)

Variants select scripts per OS family at build time. The `locals.pkr.hcl` file computes `local.os_family` from
`var.os_name` and uses it to choose the correct per‑OS script paths:

```hcl
locals {
  os_family = contains(["debian", "ubuntu"], var.os_name) ? "debian" : (
    contains(["almalinux", "rocky", "rhel"], var.os_name) ? "rhel" : var.os_name
  )

  variant_scripts = {
    "k8s-node" = concat(
      [
        "variants/k8s-node/common/prepare.sh",
        "variants/k8s-node/common/configure_kernel.sh",
      ],
      [
        "variants/k8s-node/${local.os_family}/install_container_runtime.sh",
        "variants/k8s-node/${local.os_family}/install_kubernetes.sh",
      ],
      [
        "variants/k8s-node/common/configure_networking.sh",
      ],
    )
    "docker-host" = [
      "variants/docker-host/${local.os_family}/install_docker.sh",
      "variants/docker-host/${local.os_family}/configure_docker.sh",
    ]
  }
}
```

## Extending Later

### Add a New OS (e.g., Ubuntu)

1. Create `packer_templates/http/ubuntu/` with Ubuntu autoinstall files
2. Create `os_pkrvars/ubuntu/` with variable files (e.g., `22.04-x86_64.pkrvars.hcl`)
3. Update `packer_templates/locals.pkr.hcl` to include "ubuntu" in `os_family` detection if needed
4. Create `packer_templates/scripts/ubuntu/` if distro-specific scripts needed
5. Create `packer_templates/scripts/providers/virtualbox/ubuntu/` for Ubuntu-specific Guest Additions handling
6. Add make/rake targets (e.g., `ubuntu-22-04`)

### Add a New Provider (e.g., VMware)

1. Add VMware source block to `packer_templates/sources.pkr.hcl`:
   ```hcl
   source "vmware-iso" "vm" {
     // VMware-specific configuration
   }
   ```
2. Add VMware plugin to `packer_templates/plugins.pkr.hcl`
3. Update `packer_templates/build.pkr.hcl` to include VMware source in builds
4. Create `packer_templates/scripts/providers/vmware/` for VMware Tools integration
5. Update provisioning logic in `build.pkr.hcl` to conditionally use provider-specific scripts

### Add a New Variant

1. Create `packer_templates/scripts/variants/<name>/` directory with OS subdirs (common/, debian/, rhel/)
2. Write ordered scripts per OS (e.g., `debian/install.sh`, `debian/configure.sh`)
3. Add the variant to the `variant_scripts` map in `packer_templates/locals.pkr.hcl`:
   ```hcl
   variant_scripts = {
     "k8s-node" = [...],
     "<name>" = [
       "variants/<name>/${local.os_family}/install.sh",
       "variants/<name>/${local.os_family}/configure.sh",
     ]
   }
   ```
4. Update `variant` variable validation in `packer_templates/variables.pkr.hcl` to include the new variant
5. Add convenience make/rake targets

## Contributing

When making changes:

1. Keep scripts simple and focused
2. Use library helpers consistently (`lib-core.sh` + OS library)
3. Make scripts idempotent (safe to re-run)
4. Update this README and CHANGELOG; add Doc Changelog entry to modified docs

## Related projects

A huge thank you to these related projects from which we've taken inspiration and often used as a source for workarounds
in complex world of base box building.

- <https://github.com/chef/bento>
- <https://github.com/boxcutter>
- <https://github.com/lavabit/robox>
- <https://github.com/mcandre/packer-templates>

## Resources

- Packer: https://www.packer.io/docs

## Doc Changelog

| Version | Date       | Changes                                                                                                                                                                                                                                   |
|---------|------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 3.1.1   | 2026-01-27 | Added: DEBUG flag support in Makefile/Rakefile for verbose logging; added Debugging and Logging section to Troubleshooting.                                                                                                              |
| 3.1.0   | 2025-11-20 | Changed: Removed ARM support and unsupported AlmaLinux versions from documentation. Added OVF build commands.                                                                                                                             |
| 3.0.1   | 2025-11-18 | Related projects section added; minor formatting fixes.                                                                                                                                                                                   |
| 3.0.0   | 2025-11-17 | Consolidated template structure; all `.pkr.hcl` files now in `packer_templates/` root; updated all paths, build commands, and architecture sections; simplified provider/OS workflow.                                                     |
| 2.2.0   | 2025-11-14 | Changed: Variants now use per-OS subdirectories; providers/virtualbox prepared for multi‑OS (common + per‑OS wrappers); updated directory structure and dynamic examples.                                                                 |
| 2.1.0   | 2025-11-14 | Changed: Switch to modular libraries (`lib-core.sh`, `lib-debian.sh`, `lib-rhel.sh`); updated provisioning notes and directory structure.                                                                                                 |
| 2.0.0   | 2025-11-13 | Provider × OS matrix restructure; simplified variable files (12-x86_64.pkrvars.hcl); variant-via-flags approach; updated all command examples and architecture documentation; added Windows compatibility notes (TARGET_OS, quote fixes). |
| 1.3.0   | 2025-11-13 | Align with current repo state; host-agnostic; GA policy; docs parity                                                                                                                                                                      |
| 1.2.1   | 2025-11-12 | Remove lib.sh from final box via cleanup provisioner                                                                                                                                                                                      |
| 1.2.0   | 2025-11-12 | Add file+install for lib.sh and pass LIB_DIR/LIB_SH                                                                                                                                                                                       |
| 1.1.2   | 2025-11-12 | Ensure lib.sh availability via file+inline provisioners                                                                                                                                                                                   |
| 1.1.1   | 2025-11-12 | Restore vbox_guest_additions_path variable                                                                                                                                                                                                |
| 1.1.0   | 2025-11-12 | Focused on Debian+VirtualBox; pruned legacy HCL files                                                                                                                                                                                     |
