---
title: Packer Vagrant Box Builder (Debian + VirtualBox)
status: Active
version: 1.2.1
scope: Minimal Packer build for Debian/VirtualBox with simple extension path
---

# Packer Vagrant Box Builder (Debian + VirtualBox)

Streamlined Packer setup for building Debian-based Vagrant boxes with VirtualBox.
Grounded in the Bento approach but simplified for reliability on Windows/WSL2
and for use in this Kubernetes course.

## What Changed (Now Even Simpler)

- Focused scope: Debian 12 and 13, VirtualBox only
- Single template: `packer_templates/main.pkr.hcl` (plus `pkr-plugins.pkr.hcl`)
- Minimal variables: only what Debian/VirtualBox needs
- 3 clear phases: prepare → configure → cleanup
- Extension-ready: add more `.pkrvars.hcl` files (new distros) or a new provider source later

## Quick Start

```bash
# 1) Check environment
make check-env

# 2) Initialize Packer plugins
make init

# 3) Build a box
make debian-12        # Debian 12 x86_64 (recommended)
```

## Requirements

- Packer >= 1.7.0
- VirtualBox >= 7.1.6 (arm64 support)
- Vagrant >= 2.4.0 (for testing)
- Make (for using Makefile commands)

## Common Commands

| Command | Description |
|---------|-------------|
| `make debian-12` | Build Debian 12 x86_64 box (recommended) |
| `make debian-13` | Build Debian 13 x86_64 box |
| `make build TEMPLATE=debian/debian-12-x86_64.pkrvars.hcl` | Build specific template |
| `make validate` | Validate all templates |
| `make clean` | Remove build artifacts |
| `make list-templates` | Show available templates |
| `make help` | Show all available commands |

## Build Process (3 Phases)

Provisioner strategy:
- Upload `packer_templates/scripts/` → `/tmp/packer-scripts` (keeps relative
  layout intact for simple cases).
- Install `_common/lib.sh` from the uploaded tree to a stable, root-owned path:
  `/usr/local/lib/k8s/lib.sh`.
- Run shell provisioners via inline commands and provide env vars:
  `LIB_DIR=/usr/local/lib/k8s` and `LIB_SH=/usr/local/lib/k8s/lib.sh` so dependent
  scripts can source the library deterministically.
- Final cleanup removes `/usr/local/lib/k8s/lib.sh` (and the directory if empty)
  so the box doesn’t contain build-only helpers.

### Phase 1: System Preparation
- Update all packages
- Disable automatic updates (required for Kubernetes)

### Phase 2: OS Configuration
- Install Vagrant user and SSH configuration
- Configure networking, sudoers, systemd

### Phase 3: Cleanup & Minimization
- Remove unnecessary packages
- Clear logs and temporary files
- Zero free space for better compression

## Using Built Boxes

After building, the `.box` file is located in `builds/build_complete/`:

```bash
# Add box to Vagrant
vagrant box add --name debian-12 \
  builds/build_complete/debian-12.12-x86_64.virtualbox.box

# Use in a Vagrantfile
vagrant init debian-12
vagrant up
```

## Advanced Usage

### Building from Command Line

```bash
# From packer/ directory
cd os_pkrvars/debian
packer build -var-file=debian-12-x86_64.pkrvars.hcl ../../packer_templates
```

### Customizing a Build

Edit or create a `.pkrvars.hcl` in `os_pkrvars/<os_name>/`:

```hcl
os_name                   = "debian"
os_version                = "12.12"
os_arch                   = "x86_64" # or aarch64
iso_url                   = "https://cdimage.debian.org/..."
iso_checksum              = "file:https://cdimage.debian.org/.../SHA256SUMS"
vbox_guest_os_type        = "Debian12_64"
vbox_guest_additions_mode = "disable"
vbox_guest_additions_path = "VBoxGuestAdditions_{{ .Version }}.iso" # default
boot_command              = [
  "<wait><esc><wait>auto preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/debian/preseed.cfg netcfg/get_hostname={{ .Name }}<enter>"
]

# Optional: Custom VBoxManage commands (safe for WSL2)
vboxmanage = [
  ["modifyvm", "{{.Name}}", "--chipset", "ich9"],
  ["modifyvm", "{{.Name}}", "--audio-enabled", "off"],
  ["modifyvm", "{{.Name}}", "--cableconnected1", "on"]
]
```

## Troubleshooting

### Windows/WSL2 Networking Issues

If builds fail with network connectivity issues on WSL2, avoid
`--nat-localhostreachable1`. Included templates already omit it.

### Guest Additions

Guest Additions installation is disabled by default for reliability. If you
need it, set `vbox_guest_additions_mode` to `attach` or `upload` and add an
install step in a provisioner (or adapt `scripts/_common/guest_tools_virtualbox.sh`).
You can override the ISO path via `vbox_guest_additions_path`.

### Build Hangs at Boot

Remove `headless = true` in your `.pkrvars.hcl` to view the VirtualBox GUI.

## Simplified Architecture

Files kept:
```
packer_templates/
  main.pkr.hcl         → variables + source (VirtualBox) + build
  pkr-plugins.pkr.hcl  → required plugins (virtualbox, vagrant)
  http/debian/preseed.cfg
  scripts/_common/* and scripts/debian/*
```

Removed legacy split files (`pkr-variables.pkr.hcl`, `pkr-sources.pkr.hcl`,
`pkr-builder.pkr.hcl`) to avoid confusion.

## Extending Later

- New distro: add `.pkrvars.hcl` under `os_pkrvars/<distro>/` and reuse the
  same template (plus `scripts/<distro>` if needed).
- New provider: add another `source` block and a `sources = [...]` entry in
  `build {}` with a new make target. Keep this file minimal per-provider.

## Contributing

When making changes:
1. Keep scripts simple and focused
2. Use `lib.sh` helpers consistently
3. Make scripts idempotent (safe to re-run)
4. Test on both x86_64 and aarch64 when possible
5. Update this README

## Resources

- Packer: https://www.packer.io/docs

## Doc Changelog

| Version | Date       | Author     | Changes                                                |
|---------|------------|------------|--------------------------------------------------------|
| 1.2.1   | 2025-11-12 | repo-maint | Remove lib.sh from final box via cleanup provisioner    |
| 1.2.0   | 2025-11-12 | repo-maint | Add file+install for lib.sh and pass LIB_DIR/LIB_SH     |
| 1.1.2   | 2025-11-12 | repo-maint | Ensure lib.sh availability via file+inline provisioners |
| 1.1.1   | 2025-11-12 | repo-maint | Restore vbox_guest_additions_path variable              |
| 1.1.0   | 2025-11-12 | repo-maint | Focused on Debian+VirtualBox; pruned legacy HCL files   |
