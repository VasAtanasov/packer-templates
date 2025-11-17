---
title: AGENTS (Root Guidance)
version: 3.2.1
status: Active
scope: repo-wide
---

# AGENTS.md

Guidance for any coding agent working in this repository. `CLAUDE.md` is a symlink to this file. This root document
applies repository‑wide unless overridden by a more deeply nested `AGENTS.md`.

## Scope and Precedence

- This file governs the entire repo unless a subdirectory contains its own `AGENTS.md`.
- Deeper `AGENTS.md` files take precedence for their subtree.
- Current scoped guides:
    - `packer_templates/scripts/AGENTS.md` – provisioning scripts rules and skeletons.
    - `os_pkrvars/AGENTS.md` – authoring `.pkrvars.hcl` files.

## Minimum Tool Versions

- Packer: >= 1.7.0 (enforced via `packer_templates/plugins.pkr.hcl`).
- VirtualBox: >= 7.1.6 (for reliable aarch64 support).
- `make check-env` or `rake check_env` should be used before builds and fails early if requirements are unmet.

## Project Overview

This is a Packer repository for building Debian-based Vagrant boxes supporting multiple providers (VirtualBox, with
VMware and QEMU planned). The project uses a **consolidated template structure** with all Packer configuration files
in a single `packer_templates/` directory. Provider and OS selection happens via variables passed at build time.
Currently focused on Debian 12/13 with VirtualBox, using a clear 3-phase provisioning approach. The project is
host‑agnostic; no WSL2‑specific accommodations are required.

## Build Commands

### Quick Build Commands

```bash
# Base boxes (minimal)
make debian-12          # Build Debian 12 x86_64 base box (recommended)
make debian-13          # Build Debian 13 x86_64 base box
make debian-12-arm      # Build Debian 12 aarch64 base box
make debian-13-arm      # Build Debian 13 aarch64 base box

# Kubernetes node variant
make debian-12-k8s      # Build Debian 12 x86_64 Kubernetes node
make debian-12-arm-k8s  # Build Debian 12 aarch64 Kubernetes node

# Docker host variant
make debian-12-docker       # Build Debian 12 x86_64 Docker host
make debian-12-arm-docker   # Build Debian 12 aarch64 Docker host
```

### Core Commands

```bash
make check-env          # Verify environment and dependencies
make init               # Initialize Packer plugins (required before first build)
make build TEMPLATE=debian/12-x86_64.pkrvars.hcl  # Build specific base box
make build TEMPLATE=debian/12-x86_64.pkrvars.hcl VARIANT=k8s-node  # Build with variant
make validate           # Validate all templates for current PROVIDER/TARGET_OS
make validate-one TEMPLATE=debian/12-x86_64.pkrvars.hcl  # Validate single template
make clean              # Remove build artifacts
make list-templates     # Show available templates
make list-builds        # Show built boxes
make debug              # Show configuration (PROVIDER, TARGET_OS, template dir, etc.)

# Environment Variables
PROVIDER=virtualbox     # Provider to use (default: virtualbox)
TARGET_OS=debian        # Operating system to build (default: debian; NOTE: uses TARGET_OS not OS to avoid Windows conflict)
VARIANT=k8s-node        # Variant to build (base, k8s-node, docker-host)
K8S_VERSION=1.33        # Kubernetes version for k8s-node variant
```

### Manual Build (from command line)

```bash
# Base box
packer build -var-file=os_pkrvars/debian/12-x86_64.pkrvars.hcl packer_templates/

# With variant
packer build \
  -var-file=os_pkrvars/debian/12-x86_64.pkrvars.hcl \
  -var='variant=k8s-node' \
  -var='kubernetes_version=1.33' \
  -var='cpus=2' -var='memory=4096' -var='disk_size=61440' \
  packer_templates/
```

## Architecture

### Directory Structure

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
    _common/                # Cross-distro scripts (vagrant, sshd, minimize, etc.)
      lib-core.sh           # OS-agnostic Bash helpers (logging, files, services, etc.)
      lib-debian.sh         # Debian/Ubuntu APT helpers (pkg install, keys, sources)
      lib-rhel.sh           # AlmaLinux/Rocky DNF helpers (pkg install, repos)
    debian/                 # Debian-specific scripts
    providers/              # Provider-specific integration scripts
      virtualbox/           # VirtualBox integration (per-OS subdirs)
        common/             # Shared across OS families
        debian/             # Debian/Ubuntu wrappers or overrides
        rhel/               # RHEL-family wrappers or overrides
        opensuse/           # OpenSUSE wrappers or overrides
      hyperv/               # Hyper-V Integration Services (planned)
    variants/               # Variant-specific provisioning scripts (per-OS subdirs)
      k8s-node/
        common/             # OS-agnostic steps (prepare, kernel, networking)
        debian/             # Debian/Ubuntu steps (runtime + Kubernetes install)
        rhel/               # RHEL family steps (planned)
      docker-host/
        debian/             # Debian/Ubuntu steps (install + configure)
        rhel/               # RHEL family steps (planned)

os_pkrvars/
  debian/                   # Debian variable files
    12-x86_64.pkrvars.hcl   # Debian 12 x86_64 (base + all variants via -var flags)
    12-aarch64.pkrvars.hcl  # Debian 12 aarch64 (base + all variants via -var flags)
    13-x86_64.pkrvars.hcl   # Debian 13 x86_64 (base + all variants via -var flags)
    13-aarch64.pkrvars.hcl  # Debian 13 aarch64 (base + all variants via -var flags)

builds/
  iso/                      # Downloaded ISOs (cached by URL hash)
  build_files/              # Intermediate build files
  build_complete/           # Final .box files
```

### Template Architecture

The project uses a **consolidated template structure** with all Packer configuration in a single directory:

- **`variables.pkr.hcl`**: All Packer variable definitions
- **`locals.pkr.hcl`**: Computed locals (OS family detection, variant script selection, etc.)
- **`sources.pkr.hcl`**: Source definitions (virtualbox-iso, vmware-iso, qemu, etc.)
- **`build.pkr.hcl`**: Build block with provisioning logic and post-processors
- **`plugins.pkr.hcl`**: Required plugin declarations

**Why this structure:**

- **Packer auto-aggregation**: All `.pkr.hcl` files in a directory are automatically combined
- **No import blocks**: Packer doesn't support import statements (unlike Terraform)
- **Single source of truth**: All templates in one place, provider/OS selected via variables
- **Variant via flags**: Variants passed via `-var='variant=k8s-node'` instead of separate files
- **Simplified maintenance**: Changes to provisioning logic happen in one place

**Key variables:**

- `os_name`, `os_version`, `os_arch` - OS identification
- `iso_url`, `iso_checksum` - ISO source and verification
- `vbox_guest_os_type` - VirtualBox guest OS type (provider-specific)
- `boot_command` - Installer boot command sequence
- `vboxmanage` - Custom VBoxManage commands (auto-configured per architecture)
- `variant` - Box variant: "base" (minimal), "k8s-node", "docker-host"
- `kubernetes_version`, `container_runtime`, `crio_version` - K8s-specific (when variant="k8s-node")

HCL style conventions:

- Use snake_case for variable names and filenames.
- Required in `.pkrvars.hcl`: `os_name`, `os_version`, `os_arch`, `iso_url`, `iso_checksum`, `vbox_guest_os_type`,
  `boot_command`.
- Always provide checksums using Debian's published SHA256 lists via `file:` URLs (example in `os_pkrvars/debian`).
- Variable files simplified: `12-x86_64.pkrvars.hcl` instead of `debian-12-x86_64-k8s-node.pkrvars.hcl`

**Architecture-specific defaults:**

- x86_64: ich9 chipset, SATA storage
- aarch64: armv8virtual chipset, virtio storage, EFI firmware, USB peripherals

### Variant Script Selection (Dynamic)

Variant scripts are selected dynamically per OS family using locals inside `locals.pkr.hcl`:

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

  selected_variant_scripts = var.variant == "base" ? [] : lookup(local.variant_scripts, var.variant, [])
}
```

### 3-Phase Provisioning Strategy

**Note:** Phase numbers are used for documentation purposes only. The actual Packer configuration uses semantic names
for clarity and maintainability.

**Phase 1: System Updates and Preparation**

Provisioner: `"System Updates and Preparation"` (semantic name in `build.pkr.hcl`)

- Update all packages via `_common/update_packages.sh`
- Disable automatic updates
- May trigger reboot

**Phase 2: Base Configuration and Provider Integration**

Provider-specific provisioners execute independently based on enabled sources:

- **VirtualBox**: Provisioner `"VirtualBox: Base configuration and guest tools"`
    - Common scripts: `vagrant.sh`, `sshd.sh`
    - Guest tools: `providers/virtualbox/guest_tools_virtualbox.sh` (if not disabled)

- **VMware**: Provisioner `"VMware: Base configuration and guest tools"` (planned)
    - Common scripts: `vagrant.sh`, `sshd.sh`
    - Guest tools: `providers/vmware/guest_tools_vmware.sh` (if not disabled)

- **QEMU**: Provisioner `"QEMU: Base configuration and guest tools"` (planned)
    - Common scripts: `vagrant.sh`, `sshd.sh`
    - Guest tools: `providers/qemu/guest_tools_qemu.sh`

**Phase 3: OS Configuration, Variants, and Cleanup**

Single provider-agnostic provisioner: `"OS Configuration, Variants, and Cleanup"`

Script execution order (consolidated in `local.os_and_variant_scripts`):
1. **OS-specific configuration**: `debian/systemd.sh`, `debian/sudoers.sh`, `debian/networking.sh`
2. **Variant provisioning** (only for non-base variants):
    - K8s variant: `common/prepare.sh` → `common/configure_kernel.sh` → `${os_family}/install_container_runtime.sh` →
      `${os_family}/install_kubernetes.sh` → `common/configure_networking.sh` → `${os_family}/cleanup_k8s.sh`
    - Docker variant: `${os_family}/install_docker.sh` → `${os_family}/configure_docker.sh` →
      `${os_family}/cleanup_docker.sh`
3. **Custom scripts** (user extensibility): Scripts from `scripts/custom/${os_family}/` (sorted alphabetically)
4. **Base cleanup**: `debian/cleanup.sh` or `rhel/cleanup.sh` (removes unnecessary packages, cleans caches)

**Phase 4: Final Minimization**

Provisioner: `"Final Minimization"` (semantic name in `build.pkr.hcl`)

- Clear logs, temporary files, zero free space via `_common/minimize.sh`
- Final step: Remove build-only libraries directory (`/usr/local/lib/scripts/`)

**Persistent Scripts Provisioning Pattern (Optimized):**

1. Upload entire `scripts/` tree to `/tmp/packer-scripts` (once, ephemeral)
2. Copy entire tree to `/usr/local/lib/scripts/` (persistent, root-owned, survives reboots and cleanups)
3. Run all phases referencing scripts from `/usr/local/lib/scripts/`
    - Phase 1: `update_packages.sh` (may reboot - scripts survive)
    - Phase 2: Provider-specific common scripts and guest tools
    - Phase 3: OS config, variant installation and cleanup, custom scripts, base cleanup
    - Phase 4: `minimize.sh` (clears `/tmp` - scripts survive until final step)
4. Final cleanup removes entire `/usr/local/lib/scripts/` directory

**Environment variables for all provisioners:**

- `LIB_DIR=/usr/local/lib/scripts`
- `LIB_CORE_SH=/usr/local/lib/scripts/_common/lib-core.sh`
- `LIB_OS_SH=/usr/local/lib/scripts/_common/lib-debian.sh` (or `lib-rhel.sh` per OS)

**Key Benefits:**

- Scripts uploaded only **once** (vs. 3 times in previous approach)
- Survives system reboots (Phase 1)
- Survives `/tmp` cleanup (Phase 3a)
- Consistent with persistent library approach
- Cleaner, more efficient provisioning flow

### Modular Library System

The `packer_templates/scripts/_common/` directory provides a modular Bash library:

- `lib-core.sh` (OS-agnostic; 45+ helpers)
- `lib-debian.sh` (APT-based; Debian/Ubuntu)
- `lib-rhel.sh` (DNF-based; AlmaLinux/Rocky)

Key function families:

- **Logging**: `lib::log`, `lib::success`, `lib::warn`, `lib::error`, `lib::debug`
- **UI**: `lib::header`, `lib::subheader`, `lib::hr`, `lib::kv`, `lib::cmd`
- **Packages**: `lib::ensure_apt_updated`, `lib::ensure_package`, `lib::ensure_packages`
- **Files**: `lib::ensure_directory`, `lib::ensure_file`, `lib::ensure_symlink`
- **Services**: `lib::ensure_service`, `lib::ensure_service_enabled`, `lib::ensure_service_running`
- **System**: `lib::ensure_swap_disabled`, `lib::ensure_kernel_module`, `lib::ensure_sysctl`
- **Verification**: `lib::verify_commands`, `lib::verify_files`, `lib::verify_services`

All provisioner scripts must source both libraries:
`source "${LIB_CORE_SH}"` and `source "${LIB_OS_SH}"`

**Note:** Libraries are installed under `/usr/local/lib/scripts/_common/` during the build. Packer passes both
`LIB_CORE_SH` and an OS‑specific `LIB_OS_SH` to each provisioner.

Script rules in brief (see `packer_templates/scripts/AGENTS.md` for details):

- Bash only; strict mode and error traps via `lib::strict` and `lib::setup_traps`.
- Must run as root (`lib::require_root`).
- Idempotent and re‑runnable.
- Use helpers for APT, files, services; avoid direct `apt-get update` or raw `systemctl` where helpers exist.

### Custom Scripts Extensibility

The project provides an extension mechanism for adding custom provisioning scripts without modifying core template files.

**Location**:
- Primary: `packer_templates/scripts/custom/${os_family}/`
- Optional scoped directories (higher precedence):
  - Variant: `packer_templates/scripts/custom/${os_family}/${variant}`
  - Provider: `packer_templates/scripts/custom/${os_family}/${provider}` (e.g., `virtualbox`, `vmware`, `qemu`)
  - Precedence order: variant → provider → OS family

**Execution Order**: Custom scripts run in Phase 3, after variant provisioning and before base OS cleanup:
1. OS-specific configuration
2. Variant provisioning (if applicable)
3. **→ Custom scripts (YOUR EXTENSIONS) ←**
4. Base OS cleanup

**Script Requirements**:
- Place scripts in OS-specific subdirectory (`debian/` or `rhel/`) or in optional variant/provider subdirectories
- Only files matching `??-*.sh` are executed (two-digit prefix + hyphen). Use zero-padded numeric prefixes to set order
- Scripts are sorted alphabetically and executed in order
- Must source both libraries: `source "${LIB_CORE_SH}"` and `source "${LIB_OS_SH}"`
- Use library functions for idempotent operations
- Follow same conventions as core provisioner scripts

**Environment Variables Available**:
- All standard variables: `LIB_DIR`, `LIB_CORE_SH`, `LIB_OS_SH`
- `VARIANT` - Current variant (base, k8s-node, docker-host)
- Provider: `PACKER_BUILDER_TYPE` (e.g., `virtualbox-iso`, `vmware-iso`)
- K8s-specific (if variant=k8s-node): `K8S_VERSION`, `CONTAINER_RUNTIME`, `CRIO_VERSION`

**Git Configuration**: Custom scripts are ignored by default (`.gitignore`) so they can remain private or per-environment.
Remove the gitignore entry to commit custom scripts to version control if desired.

**Example**: See `packer_templates/scripts/custom/README.md` for detailed examples and guidelines.

## Adding New Content

### Adding a New Distro (e.g., Ubuntu)

1. Create `packer_templates/http/ubuntu/` with Ubuntu autoinstall files
2. Create `os_pkrvars/ubuntu/` directory with `.pkrvars.hcl` files:
    - `22.04-x86_64.pkrvars.hcl`
    - `22.04-aarch64.pkrvars.hcl`
    - `24.04-x86_64.pkrvars.hcl`
    - `24.04-aarch64.pkrvars.hcl`
3. Update `locals.pkr.hcl` to include "ubuntu" in `os_family` detection if needed
4. Create `packer_templates/scripts/ubuntu/` if distro-specific scripts needed
5. Create `packer_templates/scripts/providers/virtualbox/ubuntu/` for Ubuntu-specific Guest Additions handling
6. Add make/rake targets: `ubuntu-22-04`, `ubuntu-24-04`, etc.
7. Test: `make build TEMPLATE=ubuntu/22.04-x86_64.pkrvars.hcl`

### Adding a New Provider (e.g., VMware)

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
6. Test with each OS: `make build TEMPLATE=debian/12-x86_64.pkrvars.hcl PROVIDER=vmware`

### Adding a New Variant

1. Create `packer_templates/scripts/variants/{name}/` directory with OS subdirs (common/, debian/, rhel/)
2. Write ordered scripts for the variant:
   - Installation scripts (e.g., `debian/install.sh`, `debian/configure.sh`)
   - **Cleanup script** (e.g., `debian/cleanup_{name}.sh`) - removes build artifacts, verifies installation
3. Add variant to `variant_scripts` map in `packer_templates/locals.pkr.hcl`:
   ```hcl
   variant_scripts = {
     "k8s-node" = [...],
     "new-variant" = [
       "variants/new-variant/${local.os_family}/install.sh",
       "variants/new-variant/${local.os_family}/configure.sh",
       "variants/new-variant/${local.os_family}/cleanup_new_variant.sh",  # ← cleanup last
     ],
   }
   ```
4. Update `variant` variable validation in `variables.pkr.hcl` to include new variant
5. Add convenience make/rake targets:
   ```makefile
   debian-12-new-variant:
     @$(MAKE) build TEMPLATE=debian/12-x86_64.pkrvars.hcl VARIANT=new-variant
   ```
6. Test variant: `make build TEMPLATE=debian/12-x86_64.pkrvars.hcl VARIANT=new-variant`
7. Test on both x86_64 and aarch64 where applicable

**Important**: Variants clean themselves before base cleanup runs. Variant cleanup scripts should:
- Remove build dependencies specific to the variant
- Clean temporary files created during variant installation
- Verify that variant functionality is still intact (use `lib::verify_commands`, `lib::verify_services`)
- NOT remove the variant's core functionality (e.g., don't remove kubectl in k8s-node cleanup)

### Writing Provisioner Scripts

- Source libraries: `source "${LIB_CORE_SH}"` and `source "${LIB_OS_SH}"`
- Use logging functions: `lib::log`, `lib::error`, etc.
- Make scripts idempotent (safe to re-run)
- Use helper functions: `lib::ensure_package`, `lib::ensure_service`, etc.
- Test on both x86_64 and aarch64 when possible
- For variant scripts, see `packer_templates/scripts/AGENTS.md` for detailed guidelines

## Host Environment

- The project is host‑agnostic. No WSL2‑specific workarounds are required.
- Headless mode is enabled by default; set `headless = false` in `.pkrvars.hcl` to debug boot issues.

## Guest Additions

Policy: Always install VirtualBox Guest Additions.

1. Ensure `vbox_guest_additions_mode = "attach"` (or `"upload"`) in `.pkrvars.hcl`.
2. Include `scripts/_common/guest_tools_virtualbox.sh` in provisioning (Phase 2).
3. Optionally override ISO path via `vbox_guest_additions_path`.

## Output Location

Built boxes are placed in: `builds/build_complete/<box_name>.virtualbox.box`

Add to Vagrant:

```bash
vagrant box add --name debian-12 builds/build_complete/debian-12.12-x86_64.virtualbox.box
```

## Validation Workflow

Always validate templates before building:

```bash
make validate              # All templates for current PROVIDER/TARGET_OS
make validate-one TEMPLATE=debian/12-x86_64.pkrvars.hcl  # Single template

# Or with Rake (Windows)
rake validate
rake validate_one TEMPLATE=debian/12-x86_64.pkrvars.hcl

# Change provider/OS
make validate PROVIDER=vmware TARGET_OS=ubuntu  # Future: validate VMware Ubuntu templates
```

## Debugging Builds

1. Run `make check-env` to verify dependencies
2. Use `make debug` to show configuration
3. Remove `headless = true` from `.pkrvars.hcl` to view VirtualBox GUI
4. Check `packer build` output for detailed logs
5. SSH into VM during build: `ssh vagrant@<ip>` (password: vagrant)

## Reproducibility

- ISO caching: when `iso_target_path = "build_dir_iso"` and `iso_url` is set, the ISO is stored as
  `builds/iso/<os>-<version>-<arch>-<sha8>.iso`, where `sha8` is `sha256(iso_url)[0:8]`.
- Determinism: pin ISOs by version, use `file:` SHA256 lists for checksums, and avoid implicit upgrades outside Phase 1.

## HCL Conventions

- Variable and filename style: snake_case.
- Required fields in `.pkrvars.hcl`: `os_name`, `os_version`, `os_arch`, `iso_url`, `iso_checksum`,
  `vbox_guest_os_type`, `boot_command`.
- Example override of `vboxmanage` in `.pkrvars.hcl`:
    -
    `vboxmanage = [["modifyvm", "{{.Name}}", "--cableconnected1", "on"], ["modifyvm", "{{.Name}}", "--audio-enabled", "off"]]`

## Definition of Done (DoD)

- New template `.pkrvars.hcl` validates (`make validate-one`).
- Full build succeeds on both arches (where applicable).
- Box name matches:
    - Base: `<os_name>-<os_version>-<os_arch>.virtualbox.box`
    - Variant: `<os_name>-<os_version>-<os_arch>-<variant>.virtualbox.box`
- `vagrant up` works; SSH with `vagrant/vagrant` succeeds.
- Guest Additions installed and functional.
- For variants: variant-specific software is installed and functional.
- Size is reasonable for the distro/version/variant; cleanup phase applied.

## Fast Dev Loop

- Validate: `make validate-one TEMPLATE=debian/12-x86_64.pkrvars.hcl`
- Build base: `make build TEMPLATE=debian/12-x86_64.pkrvars.hcl`
- Build variant: `make build TEMPLATE=debian/12-x86_64.pkrvars.hcl VARIANT=k8s-node`
- Or use convenience: `make debian-12` (base) or `make debian-12-k8s` (variant)
- Test: add the built box with
  `vagrant box add --name debian-12 builds/build_complete/debian-12.12-x86_64.virtualbox.box` and run a minimal
  Vagrantfile.
- Debug: set `headless = false` temporarily in the `.pkrvars.hcl` under test.
- Quick check: `make debug` to see current PROVIDER/TARGET_OS/template directory configuration

## Security and Integrity

- Checksums are mandatory for ISOs. Prefer Debian’s published `SHA256SUMS` via `file:` URLs.
- Do not store secrets in the repo. Use environment variables and Packer sensitive variables for any future secret
  inputs.
- Avoid unattended upgrades outside Phase 1 and avoid implicit reboots.

## Build Files Parity

- When updating any of the Rakefile or Makefile the both files must be identical in functionality. I use Makefile under
  Linux because it executes command with linux commands and rake file is for windows

## Documentation Standard

- Applies to all Markdown guidance in this repo: `README.md`, `AGENTS.md` (root and scoped), files in `doc/`, and any
  other `.md` documents.
- Goals: consistent structure, explicit ownership, semantic versioning, and auditable history.

- Required header metadata at the top of every document:
  ```
  title: <Document Title>
  version: <x.y.z>
  status: Draft | Active | Deprecated
  scope: Bash standards for bootstrap/install scripts across modules
  ```

- Document versioning (SemVer):
    - Major: breaking or policy/scope change that invalidates prior guidance.
    - Minor: new guidance or sections that are backward-compatible.
    - Patch: clarifications, formatting, typo fixes, non-normative edits.

- History and traceability:
    - Each document must include a "Doc Changelog" section at the end with a table: Version | Date | Changes
    - Every documentation change must also update the repo-level `CHANGELOG.md` under Unreleased (see Changelog
      Updates).
    - Commit message pattern: `docs: <path> v<version> - <one-line summary>`.

- Status lifecycle:
    - Draft: not yet normative; do not rely on for enforcement.
    - Active: normative and enforced by agents within scope.
    - Deprecated: superseded; keep file with pointer to replacement until next major repo release.

- Scope
    - 1–2 line statement of the document’s scope and applicability.

- Linking and references:
    - Use relative links within the repo; prefer stable section anchors.
    - Cross-reference scoped `AGENTS.md` where rules differ by subtree.

- Document update workflow:
    1) Bump `version:` in frontmatter according to SemVer.
    2) Append a new row to `## Doc Changelog` with date, and a concise change note. The row must be appended in desc
       order by version (latest at top).
    3) Update cross-references in the repo if titles/paths changed.

- Header templates (copy/paste):
    - Document header
      ```
      title: AGENTS (Root Guidance)
      version: 1.0.0
      status: Active
      scope: repo-wide
      ```
    - Doc Changelog block
      ```
      ## Doc Changelog
  
      | Version | Date         | Changes                                                    |
      |---------|--------------|------------------------------------------------------------|
      | 1.2.0   | <YYYY-MM-DD> | Added/Changed/Fixed: <concise summary> (commit <shortsha>) |
      | 1.1.1   | <YYYY-MM-DD> | Added/Changed/Fixed: <concise summary> (commit <shortsha>) |
      | 1.1.0   | <YYYY-MM-DD> | Added/Changed/Fixed: <concise summary> (commit <shortsha>) |
      ```

## Changelog Updates

- Maintain `CHANGELOG.md` following Keep a Changelog.
- For any user-visible change (templates, scripts, Makefile, Rakefile, `os_pkrvars`, docs), update the Unreleased
  section.
- Use categories: Added, Changed, Fixed, Deprecated, Removed, Security.
- Note Makefile/Rakefile edits under Changed and confirm parity in the entry.
- Keep entries concise; reference files/targets when helpful (e.g., `Makefile: check-env`).
- When cutting a release, rename Unreleased to the version with date and start a fresh Unreleased section.

## Doc Changelog

| Version | Date       | Changes                                                                                                                                                                                                 |
|---------|------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 3.2.1   | 2025-11-17 | Adjusted: Provider gating relies on PACKER_BUILDER_TYPE for multi-source builds; clarified custom scripts scoping across providers.                                           |
| 3.2.0   | 2025-11-17 | Added: Custom scripts scoping (variant/provider precedence), strict file gating (??-*.sh), CRLF→LF normalization during staging; updated docs accordingly.                      |
| 3.1.0   | 2025-11-17 | Added: Semantic naming clarification, per-provider provisioners documentation, custom scripts extensibility section, split cleanup strategy documentation, variant cleanup requirements.               |
| 3.0.0   | 2025-11-17 | **BREAKING**: Consolidated template structure; all `.pkr.hcl` files now in `packer_templates/` root; updated all paths and build commands; simplified provider/OS workflow.                            |
| 2.2.0   | 2025-11-14 | Changed: Variants now use per-OS subdirectories; providers/virtualbox prepared for multi‑OS (common + per‑OS wrappers); added dynamic selection examples; updated directory structure and Phase 2 notes. |
| 2.1.0   | 2025-11-14 | Changed: Adopted modular libraries (`lib-core.sh`, `lib-debian.sh`, `lib-rhel.sh`); updated examples to use `LIB_CORE_SH` + `LIB_OS_SH`; updated directory structure and cleanup notes.                 |
| 2.0.2   | 2025-11-13 | Changed: Replaced references to lib::apt_update_once with lib::ensure_apt_updated.                                                                                                                      |
| 2.0.1   | 2025-11-13 | Fixed: Renamed OS→TARGET_OS in Makefile/Rakefile to avoid Windows `OS=Windows_NT` environment variable conflict; updated all documentation references.                                                  |
| 2.0.0   | 2025-11-13 | **BREAKING**: Provider × OS matrix restructure; split templates (sources/builds); simplified variable files (12-x86_64.pkrvars.hcl); variant-via-flags approach; updated all build/validation commands. |
| 1.3.0   | 2025-11-13 | Added variant system; directory structure; Phase 2d; K8s build targets; DoD updated.                                                                                                                    |
| 1.2.0   | 2025-11-13 | Added frontmatter; expanded documentation standard; parity note; fast dev loop added.                                                                                                                   |
| 1.1.0   | 2025-11-13 | Host-agnostic stance, Guest Additions policy, HCL conventions, reproducibility, DoD.                                                                                                                    |
| 1.0.0   | 2025-11-12 | Initial repository-wide guidance and commands overview.                                                                                                                                                 |
