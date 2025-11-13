---
title: Packer Vagrant Box Builder (Debian + VirtualBox)
status: Active
version: 1.3.0
scope: Minimal Packer build for Debian/VirtualBox with simple extension path
---

# Packer Vagrant Box Builder (Debian + VirtualBox)

Streamlined Packer setup for building Debian-based Vagrant boxes with VirtualBox.
Focused on Debian 12/13 with a single, unified template and a clear 3‑phase
provisioning approach. Host‑agnostic (no WSL2‑specific behavior required).

## Highlights

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
- Make (Linux/macOS) or Rake (Windows) for convenience commands

## Common Commands

| Command                                                   | Description                              |
|-----------------------------------------------------------|------------------------------------------|
| `make debian-12`                                          | Build Debian 12 x86_64 box (recommended) |
| `make debian-13`                                          | Build Debian 13 x86_64 box               |
| `make build TEMPLATE=debian/debian-12-x86_64.pkrvars.hcl` | Build specific template                  |
| `make validate`                                           | Validate all templates                   |
| `make clean`                                              | Remove build artifacts                   |
| `make list-templates`                                     | Show available templates                 |
| `make help`                                               | Show all available commands              |

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
- Disable automatic updates (for reproducible builds)

### Phase 2: OS Configuration

- Install Vagrant user and SSH configuration
- Configure networking, sudoers, systemd
- Install VirtualBox Guest Additions (policy: install by default)

### Phase 3: Cleanup & Minimization

- Remove unnecessary packages
- Clear logs and temporary files
- Zero free space for better compression

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
# From packer/ directory
cd os_pkrvars/debian
packer build -var-file=debian-12-x86_64.pkrvars.hcl ../../packer_templates
```

### Customizing a Build

Edit or create a `.pkrvars.hcl` in `os_pkrvars/<os_name>/`:

```hcl
os_name            = "debian"
os_version         = "12.12"
os_arch = "x86_64" # or aarch64
iso_url            = "https://cdimage.debian.org/..."
iso_checksum       = "file:https://cdimage.debian.org/.../SHA256SUMS"
vbox_guest_os_type = "Debian12_64"
vbox_guest_additions_mode = "attach" # or "upload"; ensure the install script runs
vbox_guest_additions_path = "VBoxGuestAdditions_{{ .Version }}.iso" # default
boot_command = [
  "<wait><esc><wait>auto preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/debian/preseed.cfg netcfg/get_hostname={{ .Name }}<enter>"
]

# Optional: Custom VBoxManage commands
vboxmanage = [
  ["modifyvm", "{{.Name}}", "--chipset", "ich9"],
  ["modifyvm", "{{.Name}}", "--audio-enabled", "off"],
  ["modifyvm", "{{.Name}}", "--cableconnected1", "on"]
]
```

## Troubleshooting

### Guest Additions

Boxes expect Guest Additions to be installed during provisioning. Ensure
`vbox_guest_additions_mode` is set to `attach` or `upload` and that
`scripts/_common/guest_tools_virtualbox.sh` is included in Phase 2. Override the
ISO path via `vbox_guest_additions_path` if needed.

### Build Hangs at Boot

Set `headless = false` in your `.pkrvars.hcl` to view the VirtualBox GUI.

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
5. Update this README and CHANGELOG; add Doc Changelog entry to modified docs

## Resources

- Packer: https://www.packer.io/docs

## Doc Changelog

| Version | Date       | Changes                                                              |
|---------|------------|----------------------------------------------------------------------|
| 1.3.0   | 2025-11-13 | Align with current repo state; host-agnostic; GA policy; docs parity |
| 1.2.1   | 2025-11-12 | Remove lib.sh from final box via cleanup provisioner                 |
| 1.2.0   | 2025-11-12 | Add file+install for lib.sh and pass LIB_DIR/LIB_SH                  |
| 1.1.2   | 2025-11-12 | Ensure lib.sh availability via file+inline provisioners              |
| 1.1.1   | 2025-11-12 | Restore vbox_guest_additions_path variable                           |
| 1.1.0   | 2025-11-12 | Focused on Debian+VirtualBox; pruned legacy HCL files                |
