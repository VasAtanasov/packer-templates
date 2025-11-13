---
title: AGENTS (Root Guidance)
version: 1.2.0
status: Active
scope: repo-wide
---

# AGENTS.md

Guidance for any coding agent working in this repository. `CLAUDE.md` is a symlink to this file. This root document applies repository‑wide unless overridden by a more deeply nested `AGENTS.md`.

## Scope and Precedence
- This file governs the entire repo unless a subdirectory contains its own `AGENTS.md`.
- Deeper `AGENTS.md` files take precedence for their subtree.
- Current scoped guides:
  - `packer_templates/scripts/AGENTS.md` – provisioning scripts rules and skeletons.
  - `os_pkrvars/AGENTS.md` – authoring `.pkrvars.hcl` files.

## Minimum Tool Versions
- Packer: >= 1.7.0 (enforced via `packer_templates/pkr-plugins.pkr.hcl`).
- VirtualBox: >= 7.1.6 (for reliable aarch64 support).
- `make check-env` should be used before builds and fails early if requirements are unmet.

## Project Overview

This is a Packer repository for building Debian-based Vagrant boxes for VirtualBox. The project is streamlined and focused on Debian 12/13 with a clear 3-phase provisioning approach. The project is host‑agnostic; no WSL2‑specific accommodations are required.

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

HCL style conventions:
- Use snake_case for variable names and filenames.
- Required in `.pkrvars.hcl`: `os_name`, `os_version`, `os_arch`, `iso_url`, `iso_checksum`, `vbox_guest_os_type`, `boot_command`.
- Always provide checksums using Debian’s published SHA256 lists via `file:` URLs (example in `os_pkrvars/debian`).

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
 - Install VirtualBox Guest Additions (policy: always install). See `scripts/_common/guest_tools_virtualbox.sh` and ensure `vbox_guest_additions_mode` is set appropriately.

**Phase 3: Cleanup & Minimization** (split into 3a and 3b)
- Phase 3a: Remove unnecessary packages (`debian/cleanup_debian.sh`)
- Phase 3b: Clear logs, temporary files, zero free space (`_common/minimize.sh`)
- Final step: Remove build-only library (`lib.sh`)

**Persistent Scripts Provisioning Pattern (Optimized):**

1. Upload entire `scripts/` tree to `/tmp/packer-scripts` (once, ephemeral)
2. Copy entire tree to `/usr/local/lib/k8s/scripts/` (persistent, root-owned, survives reboots and cleanups)
3. Run all phases referencing scripts from `/usr/local/lib/k8s/scripts/`
   - Phase 1: `update_packages.sh` (may reboot - scripts survive)
   - Phase 2: `sshd.sh`, `vagrant.sh`, `systemd_debian.sh`, etc.
   - Phase 3a: `cleanup_debian.sh` (clears `/tmp` - scripts survive)
   - Phase 3b: `minimize.sh`
4. Final cleanup removes entire `/usr/local/lib/k8s/` directory

**Environment variables for all provisioners:**
- `LIB_DIR=/usr/local/lib/k8s`
- `LIB_SH=/usr/local/lib/k8s/scripts/_common/lib.sh`

**Key Benefits:**
- Scripts uploaded only **once** (vs. 3 times in previous approach)
- Survives system reboots (Phase 1)
- Survives `/tmp` cleanup (Phase 3a)
- Consistent with persistent library approach
- Cleaner, more efficient provisioning flow

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

**Note:** The library is located at `/usr/local/lib/k8s/scripts/_common/lib.sh` during the build and is automatically available through the `LIB_SH` environment variable passed to all provisioners.

Script rules in brief (see `packer_templates/scripts/AGENTS.md` for details):
- Bash only; strict mode and error traps via `lib::strict` and `lib::setup_traps`.
- Must run as root (`lib::require_root`).
- Idempotent and re‑runnable.
- Use helpers for APT, files, services; avoid direct `apt-get update` or raw `systemctl` where helpers exist.

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
make validate              # All templates
make validate-one TEMPLATE=debian/debian-12-x86_64.pkrvars.hcl  # Single template
```

## Debugging Builds

1. Run `make check-env` to verify dependencies
2. Use `make debug` to show configuration
3. Remove `headless = true` from `.pkrvars.hcl` to view VirtualBox GUI
4. Check `packer build` output for detailed logs
5. SSH into VM during build: `ssh vagrant@<ip>` (password: vagrant)

## Reproducibility

- ISO caching: when `iso_target_path = "build_dir_iso"` and `iso_url` is set, the ISO is stored as `builds/iso/<os>-<version>-<arch>-<sha8>.iso`, where `sha8` is `sha256(iso_url)[0:8]`.
- Determinism: pin ISOs by version, use `file:` SHA256 lists for checksums, and avoid implicit upgrades outside Phase 1.

## HCL Conventions

- Variable and filename style: snake_case.
- Required fields in `.pkrvars.hcl`: `os_name`, `os_version`, `os_arch`, `iso_url`, `iso_checksum`, `vbox_guest_os_type`, `boot_command`.
- Example override of `vboxmanage` in `.pkrvars.hcl`:
  - `vboxmanage = [["modifyvm", "{{.Name}}", "--cableconnected1", "on"], ["modifyvm", "{{.Name}}", "--audio-enabled", "off"]]`

## Definition of Done (DoD)

- New template `.pkrvars.hcl` validates (`make validate-one`).
- Full build succeeds on both arches (where applicable).
- Box name matches `<os_name>-<os_version>-<os_arch>.virtualbox.box`.
- `vagrant up` works; SSH with `vagrant/vagrant` succeeds.
- Guest Additions installed and functional.
- Size is reasonable for the distro/version; cleanup phase applied.

## Fast Dev Loop

- Validate: `make validate-one TEMPLATE=debian/debian-12-x86_64.pkrvars.hcl`
- Build: `make build TEMPLATE=debian/debian-12-x86_64.pkrvars.hcl`
- Test: add the built box with `vagrant box add --name debian-12 builds/build_complete/debian-12.12-x86_64.virtualbox.box` and run a minimal Vagrantfile.
- Debug: set `headless = false` temporarily in the `.pkrvars.hcl` under test.

## Security and Integrity

- Checksums are mandatory for ISOs. Prefer Debian’s published `SHA256SUMS` via `file:` URLs.
- Do not store secrets in the repo. Use environment variables and Packer sensitive variables for any future secret inputs.
- Avoid unattended upgrades outside Phase 1 and avoid implicit reboots.

## Build Files Parity

- When updating any of the Rakefile or Makefile the both files must be identical in functionality. I use Makefile under Linux because it executes command with linux commands and rake file is for windows

## Documentation Standard

- Applies to all Markdown guidance in this repo: `README.md`, `AGENTS.md` (root and scoped), files in `doc/`, and any other `.md` documents.
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
  - Every documentation change must also update the repo-level `CHANGELOG.md` under Unreleased (see Changelog Updates).
  - Commit message pattern: `docs: <path> v<version> - <one-line summary>`.

- Status lifecycle:
  - Draft: not yet normative; do not rely on for enforcement.
  - Active: normative and enforced by agents within scope.
  - Deprecated: superseded; keep file with pointer to replacement until next major repo release.

- Scope
  -  1–2 line statement of the document’s scope and applicability.

- Linking and references:
  - Use relative links within the repo; prefer stable section anchors.
  - Cross-reference scoped `AGENTS.md` where rules differ by subtree.

- Document update workflow:
  1) Bump `version:` in frontmatter according to SemVer.
  2) Append a new row to `## Doc Changelog` with date, and a concise change note. The row must be appended in desc order by version (latest at top).
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
- For any user-visible change (templates, scripts, Makefile, Rakefile, `os_pkrvars`, docs), update the Unreleased section.
- Use categories: Added, Changed, Fixed, Deprecated, Removed, Security.
- Note Makefile/Rakefile edits under Changed and confirm parity in the entry.
- Keep entries concise; reference files/targets when helpful (e.g., `Makefile: check-env`).
- When cutting a release, rename Unreleased to the version with date and start a fresh Unreleased section.

## Doc Changelog

| Version | Date       | Changes                                                                                  |
|---------|------------|------------------------------------------------------------------------------------------|
| 1.2.0   | 2025-11-13 | Added frontmatter; expanded documentation standard; parity note; fast dev loop added.   |
| 1.1.0   | 2025-11-13 | Host-agnostic stance, Guest Additions policy, HCL conventions, reproducibility, DoD.     |
| 1.0.0   | 2025-11-12 | Initial repository-wide guidance and commands overview.                                   |
