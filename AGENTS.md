# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Packer repository for building Debian-based Vagrant boxes for VirtualBox. The project is streamlined and focused on Debian 12/13 with a clear 3-phase provisioning approach. It's designed to work reliably on Windows/WSL2 environments.

## Build Commands

### Quick Build Commands
```bash
make debian-12          # Build Debian 12 x86_64 (recommended)
make debian-13          # Build Debian 13 x86_64
make debian-12-arm      # Build Debian 12 aarch64
make debian-13-arm      # Build Debian 13 aarch64
```

### Core Commands
```bash
make check-env          # Verify environment and dependencies
make init               # Initialize Packer plugins (required before first build)
make build TEMPLATE=debian/debian-12-x86_64.pkrvars.hcl  # Build specific template
make validate           # Validate all templates
make validate-one TEMPLATE=debian/debian-12-x86_64.pkrvars.hcl  # Validate single template
make clean              # Remove build artifacts
make list-templates     # Show available templates
make list-builds        # Show built boxes
```

### Manual Build (from command line)
```bash
cd os_pkrvars/debian
packer build -var-file=debian-12-x86_64.pkrvars.hcl ../../packer_templates
```

## Architecture

### Directory Structure
```
packer_templates/
  main.pkr.hcl              # Single unified template (variables + source + build)
  pkr-plugins.pkr.hcl       # Required plugins (virtualbox, vagrant)
  http/debian/preseed.cfg   # Debian installer preseed configuration
  scripts/
    _common/                # Cross-distro scripts (vagrant, sshd, minimize, etc.)
      lib.sh                # Shared Bash library with 60+ helper functions
    debian/                 # Debian-specific scripts

os_pkrvars/
  debian/                   # Debian variable files
    debian-12-x86_64.pkrvars.hcl
    debian-12-aarch64.pkrvars.hcl
    debian-13-x86_64.pkrvars.hcl
    debian-13-aarch64.pkrvars.hcl

builds/
  iso/                      # Downloaded ISOs
  build_files/              # Intermediate build files
  build_complete/           # Final .box files
```

### Template Architecture

The project uses a **single unified template** (`main.pkr.hcl`) that combines variables, source definitions, and build logic. This replaces the legacy split-file approach for simplicity.

**Key variables:**
- `os_name`, `os_version`, `os_arch` - OS identification
- `iso_url`, `iso_checksum` - ISO source and verification
- `vbox_guest_os_type` - VirtualBox guest OS type
- `boot_command` - Installer boot command sequence
- `vboxmanage` - Custom VBoxManage commands (auto-configured per architecture)

**Architecture-specific defaults:**
- x86_64: ich9 chipset, SATA storage
- aarch64: armv8virtual chipset, virtio storage, EFI firmware, USB peripherals

### 3-Phase Provisioning Strategy

**Phase 1: System Preparation**
- Update all packages via `_common/update_packages.sh`
- Disable automatic updates (required for Kubernetes)
- May trigger reboot

**Phase 2: OS Configuration**
- Configure SSH (`_common/sshd.sh`)
- Set up Vagrant user (`_common/vagrant.sh`)
- Configure systemd, sudoers, networking (debian-specific scripts)

**Phase 3: Cleanup & Minimization**
- Remove unnecessary packages (`debian/cleanup_debian.sh`)
- Clear logs, temporary files, zero free space (`_common/minimize.sh`)
- Remove build-only library (`lib.sh`)

**Library provisioning pattern:**
1. Upload entire `scripts/` tree to `/tmp/packer-scripts`
2. Install `_common/lib.sh` to `/usr/local/lib/k8s/lib.sh` (stable, root-owned)
3. Run Phase 1 (may trigger reboot, which clears `/tmp`)
4. Re-upload `scripts/` tree to `/tmp/packer-scripts` (handles reboot case)
5. Run Phases 2 & 3 with `LIB_DIR=/usr/local/lib/k8s` and `LIB_SH=/usr/local/lib/k8s/lib.sh` environment variables
6. Final cleanup removes `/usr/local/lib/k8s/lib.sh` from box

**Critical**: Scripts are re-uploaded after Phase 1 because system updates may trigger a reboot that clears `/tmp`. The `lib.sh` library persists in `/usr/local/lib/k8s/` across reboots.

### lib.sh Library

The `packer_templates/scripts/_common/lib.sh` file is a comprehensive Bash library with 60+ helper functions used across all scripts. Key function families:

- **Logging**: `lib::log`, `lib::success`, `lib::warn`, `lib::error`, `lib::debug`
- **UI**: `lib::header`, `lib::subheader`, `lib::hr`, `lib::kv`, `lib::cmd`
- **Packages**: `lib::ensure_package`, `lib::ensure_packages`, `lib::apt_update_once`
- **Files**: `lib::ensure_directory`, `lib::ensure_file`, `lib::ensure_symlink`
- **Services**: `lib::ensure_service`, `lib::ensure_service_enabled`, `lib::ensure_service_running`
- **System**: `lib::ensure_swap_disabled`, `lib::ensure_kernel_module`, `lib::ensure_sysctl`
- **Verification**: `lib::verify_commands`, `lib::verify_files`, `lib::verify_services`

All provisioner scripts should source this library via: `source "${LIB_SH}"`

## Adding New Content

### Adding a New Distro
1. Create `os_pkrvars/<distro>/` directory
2. Add `.pkrvars.hcl` files with distro-specific variables
3. Create `packer_templates/scripts/<distro>/` if distro-specific scripts needed
4. Add corresponding `http/<distro>/` preseed/kickstart files
5. Add make targets in `Makefile` for convenience

### Adding a New Provider
1. Add new `source` block in `packer_templates/main.pkr.hcl`
2. Add to `sources` list in `build {}` block
3. Update `pkr-plugins.pkr.hcl` with required plugin
4. Create make targets with `PROVIDERS=<provider-name>`

### Writing Provisioner Scripts
- Source lib.sh: `source "${LIB_SH}"`
- Use logging functions: `lib::log`, `lib::error`, etc.
- Make scripts idempotent (safe to re-run)
- Use helper functions: `lib::ensure_package`, `lib::ensure_service`, etc.
- Test on both x86_64 and aarch64 when possible

## Windows/WSL2 Considerations

- **Avoid `--nat-localhostreachable1`** in custom vboxmanage commands on WSL2 (causes network issues)
- VirtualBox 7.1.6+ supports aarch64 VMs
- Headless mode is enabled by default; remove `headless = true` in `.pkrvars.hcl` to debug boot issues

## Guest Additions

Guest Additions are disabled by default (`vbox_guest_additions_mode = "upload"`) for reliability on WSL2. To enable:
1. Set `vbox_guest_additions_mode = "attach"` or `"upload"` in `.pkrvars.hcl`
2. Add installation step in provisioner (see `scripts/_common/guest_tools_virtualbox.sh`)
3. Override ISO path via `vbox_guest_additions_path` if needed

## Output Location

Built boxes are placed in: `builds/build_complete/<box_name>.virtualbox.box`

Add to Vagrant:
```bash
vagrant box add --name debian-12 builds/build_complete/debian-12.12-x86_64.virtualbox.box
```

## Validation Workflow

Always validate templates before building:
```bash
make validate              # All templates
make validate-one TEMPLATE=debian/debian-12-x86_64.pkrvars.hcl  # Single template
```

## Debugging Builds

1. Run `make check-env` to verify dependencies
2. Use `make debug` to show configuration
3. Remove `headless = true` from `.pkrvars.hcl` to view VirtualBox GUI
4. Check `packer build` output for detailed logs
5. SSH into VM during build: `ssh vagrant@<ip>` (password: vagrant)
