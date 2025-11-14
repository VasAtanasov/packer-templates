---
title: Packer Vagrant Box Builder (Multi-Provider)
status: Active
version: 2.1.0
scope: Provider × OS matrix organization for building Vagrant boxes
---

# Packer Vagrant Box Builder (Multi-Provider)

Packer setup for building Debian-based Vagrant boxes with support for multiple providers (VirtualBox, with VMware and
QEMU planned). Uses **Provider × OS matrix** organization to support future expansion to Ubuntu and AlmaLinux without
refactoring. Currently focused on Debian 12/13 with VirtualBox. Host-agnostic (works on Windows, Linux, macOS).

## Highlights

- **Provider × OS matrix**: Templates organized as `packer_templates/<provider>/<os>/`
- **Future-proof**: Add Ubuntu/AlmaLinux by creating new provider/OS directories
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
- VirtualBox >= 7.1.6 (arm64 support)
- Vagrant >= 2.4.0 (for testing)
- Make (Linux/macOS) or Rake (Windows) for convenience commands

## Common Commands

| Command                                                             | Description                                    |
|---------------------------------------------------------------------|------------------------------------------------|
| `make debian-12`                                                    | Build Debian 12 x86_64 base box (recommended)  |
| `make debian-12-k8s`                                                | Build Debian 12 x86_64 Kubernetes node         |
| `make debian-12-docker`                                             | Build Debian 12 x86_64 Docker host             |
| `make debian-13`                                                    | Build Debian 13 x86_64 base box                |
| `make build TEMPLATE=debian/12-x86_64.pkrvars.hcl`                  | Build specific template (base variant)         |
| `make build TEMPLATE=debian/12-x86_64.pkrvars.hcl VARIANT=k8s-node` | Build with variant                             |
| `make validate`                                                     | Validate all templates                         |
| `make clean`                                                        | Remove build artifacts                         |
| `make list-templates`                                               | Show available templates                       |
| `make debug`                                                        | Show configuration (PROVIDER, TARGET_OS, etc.) |
| `make help`                                                         | Show all available commands                    |

**Windows users:** Replace `make` with `rake` and use underscores (e.g., `rake debian_12_k8s`)

## Build Process (3 Phases)

Provisioner strategy:

- Upload entire `packer_templates/scripts/` tree to `/tmp/packer-scripts` (once, ephemeral)
- Copy entire tree to `/usr/local/lib/k8s/scripts/` (persistent, survives reboots and cleanups)
- All provisioners reference scripts from `/usr/local/lib/k8s/scripts/`
- Scripts source modular libraries via env vars:
    - `LIB_CORE_SH=/usr/local/lib/k8s/scripts/_common/lib-core.sh`
    - `LIB_OS_SH=/usr/local/lib/k8s/scripts/_common/lib-debian.sh` (or `lib-rhel.sh`)
- Final cleanup removes entire `/usr/local/lib/k8s/` directory (no build helpers in final box)

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
- Final: Remove build-only helpers (`/usr/local/lib/k8s/`)

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
  packer_templates/virtualbox/debian/

# With variant
packer build \
  -var-file=os_pkrvars/debian/12-x86_64.pkrvars.hcl \
  -var=variant=k8s-node \
  -var=kubernetes_version=1.33 \
  -var=cpus=2 -var=memory=4096 -var=disk_size=61440 \
  packer_templates/virtualbox/debian/
```

### Customizing a Build

Edit or create a `.pkrvars.hcl` in `os_pkrvars/<os_name>/`:

```hcl
// os_pkrvars/debian/12-x86_64.pkrvars.hcl
os_name    = "debian"
os_version = "12.12"
os_arch = "x86_64"  # or aarch64

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
# Change provider or OS (Linux/macOS)
make build TEMPLATE=debian/12-x86_64.pkrvars.hcl PROVIDER=virtualbox TARGET_OS=debian

# Change provider or OS (Windows)
rake build TEMPLATE=debian/12-x86_64.pkrvars.hcl PROVIDER=virtualbox TARGET_OS=debian

# Note: TARGET_OS (not OS) to avoid Windows OS=Windows_NT environment variable conflict
```

## Troubleshooting

### Guest Additions

Boxes expect Guest Additions to be installed during provisioning. Ensure
`vbox_guest_additions_mode` is set to `attach` or `upload` and that
`scripts/_common/guest_tools_virtualbox.sh` is included in Phase 2. Override the
ISO path via `vbox_guest_additions_path` if needed.

### Build Hangs at Boot

Set `headless = false` in your `.pkrvars.hcl` to view the VirtualBox GUI.

## Provider × OS Matrix Architecture

Current structure:

```
packer_templates/
  virtualbox/              # VirtualBox provider
    debian/                # Debian OS
      sources.pkr.hcl      # Variables, locals, source definition
      builds.pkr.hcl       # Build block, provisioners, post-processors
      pkr-plugins.pkr.hcl  # Required plugins (virtualbox, vagrant)
      http/                # HTTP server files for installer
        preseed.cfg        # Debian preseed configuration
  vmware/                  # VMware provider (planned)
    debian/                # Debian for VMware (planned)
  scripts/                 # Shared across all providers/OS
    _common/               # Cross-distro scripts + modular libraries
      lib-core.sh          # OS-agnostic helpers
      lib-debian.sh        # Debian/Ubuntu APT helpers
      lib-rhel.sh          # AlmaLinux/Rocky DNF helpers
    debian/                # Debian-specific scripts
    providers/             # Provider-specific scripts
      virtualbox/          # VirtualBox Guest Additions
    variants/              # Variant-specific scripts
      k8s-node/            # Kubernetes node provisioning
      docker-host/         # Docker host provisioning

os_pkrvars/
  debian/                  # Debian variable files
    12-x86_64.pkrvars.hcl  # Debian 12 x86_64 (base + all variants)
    12-aarch64.pkrvars.hcl # Debian 12 aarch64
    13-x86_64.pkrvars.hcl  # Debian 13 x86_64
    13-aarch64.pkrvars.hcl # Debian 13 aarch64
```

**Why this structure:**

- **Provider isolation**: Each provider has its own directory with provider-specific config
- **OS flexibility**: Easy to add Ubuntu, AlmaLinux by creating `<provider>/ubuntu/`, etc.
- **No refactoring**: Future expansion happens by adding directories, not restructuring
- **Packer auto-aggregation**: All `.pkr.hcl` files in a directory are automatically combined

## Extending Later

### Add a New OS (e.g., Ubuntu)

1. Create `packer_templates/virtualbox/ubuntu/` directory
2. Copy `virtualbox/debian/{sources,builds,pkr-plugins}.pkr.hcl` as templates
3. Create `virtualbox/ubuntu/http/` with Ubuntu autoinstall files
4. Create `os_pkrvars/ubuntu/` with variable files (e.g., `22.04-x86_64.pkrvars.hcl`)
5. Update source name and configs in `sources.pkr.hcl`
6. Add make/rake targets (e.g., `ubuntu-22-04`)

### Add a New Provider (e.g., VMware)

1. Create `packer_templates/vmware/debian/` directory
2. Create `sources.pkr.hcl` with `source "vmware-iso" "debian"` block
3. Create `builds.pkr.hcl` (copy from VirtualBox, adjust paths)
4. Create `pkr-plugins.pkr.hcl` with VMware plugin
5. Create `vmware/debian/http/` and copy preseed files
6. Add VMware Tools provisioning to Phase 2
7. Repeat for each OS (ubuntu, almalinux)

### Add a New Variant

1. Create `packer_templates/scripts/variants/<name>/` directory
2. Write provisioning scripts (e.g., `install.sh`, `configure.sh`)
3. Add variant to `variant_scripts` map in `builds.pkr.hcl`
4. Update `variant` variable validation in `sources.pkr.hcl`
5. Add convenience make/rake targets

## Contributing

When making changes:

1. Keep scripts simple and focused
2. Use library helpers consistently (`lib-core.sh` + OS library)
3. Make scripts idempotent (safe to re-run)
4. Test on both x86_64 and aarch64 when possible
5. Update this README and CHANGELOG; add Doc Changelog entry to modified docs

## Resources

- Packer: https://www.packer.io/docs

## Doc Changelog

| Version | Date       | Changes                                                                                                                                                                                                                                   |
|---------|------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 2.1.0   | 2025-11-14 | Changed: Switch to modular libraries (`lib-core.sh`, `lib-debian.sh`, `lib-rhel.sh`); updated provisioning notes and directory structure.                                                                                                 |
| 2.0.0   | 2025-11-13 | Provider × OS matrix restructure; simplified variable files (12-x86_64.pkrvars.hcl); variant-via-flags approach; updated all command examples and architecture documentation; added Windows compatibility notes (TARGET_OS, quote fixes). |
| 1.3.0   | 2025-11-13 | Align with current repo state; host-agnostic; GA policy; docs parity                                                                                                                                                                      |
| 1.2.1   | 2025-11-12 | Remove lib.sh from final box via cleanup provisioner                                                                                                                                                                                      |
| 1.2.0   | 2025-11-12 | Add file+install for lib.sh and pass LIB_DIR/LIB_SH                                                                                                                                                                                       |
| 1.1.2   | 2025-11-12 | Ensure lib.sh availability via file+inline provisioners                                                                                                                                                                                   |
| 1.1.1   | 2025-11-12 | Restore vbox_guest_additions_path variable                                                                                                                                                                                                |
| 1.1.0   | 2025-11-12 | Focused on Debian+VirtualBox; pruned legacy HCL files                                                                                                                                                                                     |
