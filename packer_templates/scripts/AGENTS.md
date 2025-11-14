---
title: AGENTS (Scripts Guidance)
version: 1.7.0
status: Active
scope: packer_templates/scripts
---

# AGENTS.md (Scripts)

Guidance for agents editing anything under `packer_templates/scripts/`.
This file’s scope applies to this directory and all descendants and takes
precedence over the root `AGENTS.md` for script-related changes.

## Goals

- Keep provisioning scripts deterministic, idempotent, and fast.
- Centralize common behavior via modular libraries (`_common/lib-core.sh` + OS library).
- Support both x86_64 and aarch64 builds without duplication.

## Baseline Requirements

- Shell: Bash only. Start scripts with `#!/usr/bin/env bash`.
- Strict mode: Call `lib::strict` and `lib::setup_traps` after sourcing.
- Root: Enforce with `lib::require_root` early in `main`.
- Logging: Use `lib::log|success|warn|error|debug` instead of `echo`.
- Idempotency: Scripts must be safe to re-run.
- No sudo calls inside scripts; Packer runs provisioners as root.
- Non-interactive: set `DEBIAN_FRONTEND=noninteractive` for any apt operations.

## Style & Naming

- Filenames: kebab-case (e.g., `update-packages.sh`).
- Functions: snake_case; use `local` for function scope variables.
- Constants: `readonly UPPER_SNAKE`.
- Indentation: 4 spaces; no tabs. Quote all variable expansions.
- Build complex command arguments with arrays instead of strings.

## Library Usage

- Always source the shared libraries provided by Packer:
    - `source "${LIB_CORE_SH}"`   # OS-agnostic helpers
    - `source "${LIB_OS_SH}"`     # OS-specific helpers (Debian/RHEL)
- Respect env flags if present: `VERBOSE=1`, `ASSUME_YES=1`, `LOG_NO_TS=1`.
- Use helpers instead of ad‑hoc commands:
    - Packages: `lib::ensure_apt_updated`, `lib::ensure_package(s)`
    - Files: `lib::ensure_directory`, `lib::ensure_file`, `lib::ensure_symlink`
    - Services: `lib::ensure_service_enabled`, `lib::ensure_service_running`, `lib::ensure_service`
    - System: `lib::ensure_swap_disabled`, `lib::ensure_kernel_module`, `lib::ensure_sysctl`
    - Downloads: `lib::ensure_downloaded <url> <dest> [sha256]`
    - Verification: `lib::verify_commands`, `lib::verify_files`, `lib::verify_services`

## Error Handling

- Enable strict mode (`lib::strict`) and traps (`lib::setup_traps`) in every script.
- The error trap logs exit code, line number, and the failing command.
- Return non-zero from functions on errors; exit non-zero for unrecoverable failures.

## APT and System Changes

- Do not run `apt-get update` directly; call `lib::ensure_apt_updated`.
- Prefer `lib::ensure_package(s)` over raw `apt-get install`.
- Avoid dist-upgrade or kernel upgrades outside the dedicated update script.
- Never reboot implicitly. If absolutely required, fail with a clear message and rationale.
- Disable unattended upgrades only via the designated script(s).
- Export `DEBIAN_FRONTEND=noninteractive` in scripts that invoke apt.

## File and Service Management

- Create directories/files via helpers to ensure idempotency and correct perms.
- Manage services using the service helpers; avoid raw `systemctl` unless there’s
  no helper for the specific action.
- When editing config lines, use `lib::ensure_line_in_file` or an explicit
  file replacement via `lib::ensure_file`.
- For coarse-grained one-time tasks, consider `lib::ensure_lock_dir` and `lib::lock_path` for success markers.

## Architecture Awareness

- Keep logic architecture-neutral by default; branch only when required.
- Detect architecture using `dpkg --print-architecture` or `${PACKER_ARCH}` if provided.
- For VirtualBox specifics, leave chipset/storage configuration to Packer variables/templates.

## Provider Integration Pattern

Provider-specific scripts live in `providers/{name}/` using common + per‑OS subdirectories. Scripts follow a two-script pattern:

### 1. install_dependencies.sh

Installs build tools, kernel headers, or other prerequisites needed by the provider.

**Example (VirtualBox):**

```bash
#!/usr/bin/env bash
set -o pipefail
source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"
lib::strict
lib::setup_traps
lib::require_root

main() {
    lib::header "Installing VirtualBox build dependencies"
    lib::install_kernel_build_deps  # Provided by OS library (APT/DNF)

    if lib::check_reboot_required; then
        lib::warn "Reboot required after kernel packages"
        shutdown -r now
        sleep 60
    fi
}
main "$@"
```

### 2. Integration script (guest_additions.sh, integration_services.sh, tools.sh)

Installs the provider-specific integration (guest additions, integration services, tools).

**Key points:**

- Assume dependencies are already installed
- Use lib helpers for all operations
- Verify installation (e.g., check for kernel modules)
- Clean up temporary files and logs
- Check for reboot requirements via `lib::check_reboot_required()`

### Shared Helpers in libraries

Two helpers support provider integration:

- `lib::install_kernel_build_deps()` - Installs build tools + headers (APT/DNF handled by OS library)
- `lib::check_reboot_required()` - Detects if reboot is needed after package changes

### Providers Directory Layout (VirtualBox)

```
providers/virtualbox/
  common/
    install_dependencies.sh   # OS-agnostic logic
    guest_additions.sh        # OS-agnostic logic
  debian/
    install_dependencies.sh   # Wrapper → ../common/install_dependencies.sh
    guest_additions.sh        # Wrapper → ../common/guest_additions.sh
  rhel/
    install_dependencies.sh   # Wrapper or specialized logic (future)
    guest_additions.sh        # Wrapper or specialized logic (future)
  opensuse/
    install_dependencies.sh   # Wrapper or specialized logic (future)
    guest_additions.sh        # Wrapper or specialized logic (future)
```

Use Packer locals to choose the script by OS family:

```hcl
locals {
  os_family = contains(["debian","ubuntu"], var.os_name) ? "debian"
           : contains(["almalinux","rocky","rhel"], var.os_name) ? "rhel"
           : var.os_name

  vbox_install_deps_script    = "providers/virtualbox/${local.os_family}/install_dependencies.sh"
  vbox_guest_additions_script = "providers/virtualbox/${local.os_family}/guest_additions.sh"
}
```

### Adding a New Provider

To add support for a new provider (e.g., VMware, Parallels):

1. Create `providers/{name}/` directory
2. Write `install_dependencies.sh` (use lib helpers where possible)
3. Write integration script (e.g., `tools.sh`)
4. Add provider phases to Packer template:
   ```hcl
   provisioner "shell" {
     only = ["source.vmware-iso.vm"]  // optional: provider-specific
     inline = [
       "bash /usr/local/lib/k8s/scripts/providers/vmware/install_dependencies.sh",
       "bash /usr/local/lib/k8s/scripts/providers/vmware/tools.sh",
     ]
     environment_vars = [
       "LIB_DIR=/usr/local/lib/k8s",
       "LIB_CORE_SH=/usr/local/lib/k8s/scripts/_common/lib-core.sh",
       "LIB_OS_SH=/usr/local/lib/k8s/scripts/_common/lib-debian.sh", // or lib-rhel.sh
       ...
     ]
     execute_command = "sudo -S bash -c '{{ .Vars }} {{ .Path }}'"
     expect_disconnect = true
   }
   ```

## Variant Pattern

Variant-specific scripts live in `variants/{name}/` and provide specialized configurations on top of the base box.
Variants are activated via the `variant` variable in `.pkrvars.hcl` files.

**Available variants:**

- `base` - Minimal base box (no variant scripts run)
- `k8s-node` - Kubernetes node with kubeadm, kubelet, kubectl, and container runtime
- `docker-host` - Docker host with Docker Engine and docker-compose

### Variant Script Organization

Variant scripts are executed as Phase 2d in the Packer build after base configuration but before cleanup. Variants use
explicit OS-family subdirectories. OS-agnostic logic lives in `common/`.

**k8s-node layout (OS-specific + common):**

```
variants/k8s-node/
├── common/
│   ├── prepare.sh                 # Disable swap, kernel modules, core sysctl
│   └── configure_kernel.sh        # Ensure modules at boot, verify
├── debian/
│   ├── install_container_runtime.sh  # containerd or CRI-O (APT)
│   └── install_kubernetes.sh         # kubeadm, kubelet, kubectl (APT)
├── rhel/                          # Planned: DNF-based equivalents
└── common/
    └── configure_networking.sh    # Bridge netfilter, IP forwarding
```

**docker-host layout (OS-specific):**

```
variants/docker-host/
├── debian/
│   ├── install_docker.sh          # Docker Engine/CLI/Compose (APT)
│   └── configure_docker.sh        # daemon.json, logrotate, systemd limits
└── rhel/                          # Planned
```

Packer selects the correct per-OS scripts dynamically based on `local.os_family`.

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

### Variant Script Guidelines

- **Environment variables available:**
    - `LIB_CORE_SH` - Path to core library
    - `LIB_OS_SH` - Path to OS-specific library (Debian/RHEL)
    - `LIB_DIR` - Base directory for scripts
    - `VARIANT` - Current variant name (e.g., "k8s-node")
    - `K8S_VERSION` - Kubernetes version (k8s-node only)
    - `CONTAINER_RUNTIME` - Container runtime choice (k8s-node only)
    - `CRIO_VERSION` - CRI-O version (k8s-node with cri-o only)

- **Follow the same rules as all scripts:**
    - Use library helpers
    - Maintain idempotency
    - Log with lib functions
    - Export `DEBIAN_FRONTEND=noninteractive`

- **Variant-specific patterns:**
    - Keep base box minimal; add functionality only in variants
    - Variant scripts should not duplicate base configuration
    - Branch on `CONTAINER_RUNTIME` or similar env vars for options
    - Verify installations after completion

### Adding a New Variant

To add a new variant (e.g., database-server):

1. Create `variants/{name}/` directory
2. Add OS structure: `variants/{name}/common/` (optional), `variants/{name}/debian/`, `variants/{name}/rhel/` (as
   needed)
3. Write ordered scripts per OS (e.g., `debian/install_postgres.sh`, `debian/configure_postgres.sh`)
4. Update the template `variant_scripts` map to use `${local.os_family}` for OS selection
5. Update `variant` variable validation to include the new variant
6. Add make/rake targets for convenience builds

### Variant Script Example

```bash
#!/usr/bin/env bash
set -o pipefail
source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"
lib::strict
lib::setup_traps
lib::require_root

main() {
    lib::header "Preparing system for ${VARIANT}"
    export DEBIAN_FRONTEND=noninteractive

    # Use environment variables passed from Packer
    local variant="${VARIANT:-unknown}"
    lib::log "Configuring variant: ${variant}"

    # Your variant-specific logic here
    lib::ensure_packages package1 package2

    lib::success "Variant preparation complete"
}

main "$@"
```

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
  lib::ensure_apt_updated
  lib::ensure_packages curl ca-certificates
  # ... your logic here ...
  lib::success "Completed"
}

main "$@"
```

## Idempotency Patterns

- Check state before acting (files, services, packages, commands).
- Let native tools enforce idempotency (apt, systemctl, usermod).
- Provide feedback when skipping or applying changes.

Examples

- Package install: `lib::ensure_packages ca-certificates curl`
- File copy if changed: `lib::ensure_file src.conf /etc/app/app.conf`
- Service enable+start: `lib::ensure_service myservice`

## Configuration & Inputs

- Inputs precedence: CLI flags → environment variables → internal defaults.
- Validate required inputs early, for example: `: "${FOO:?FOO is required}"`.
- Keep scripts non-interactive by default; use `lib::confirm` only for explicit confirmations.

## Testing & Linting

- Scripts are executed by Packer as root during provisioning.
- Test via built boxes in Vagrant rather than running scripts locally.
- Run ShellCheck locally before changes where possible (repo has `.shellcheckrc`).

## Host-Agnostic Notes

- Assume headless guests during provisioning; do not require interactive TTY.

## Naming and Layout

The scripts directory follows a four-tier organization for scalability.

**Organization rules:**

- `_common/` = Provider-agnostic + OS-family-agnostic scripts that work everywhere
- `providers/{name}/` = Provider-specific integration (guest additions, drivers, services)
- `{os}/` = OS-specific configuration (package managers, init systems, networking)
- `variants/{name}/` = Variant-specific provisioning (k8s-node, docker-host, etc.)

**Naming conventions:**

- Use descriptive, action-oriented filenames (e.g., `sshd.sh`, `vagrant.sh`, `cleanup.sh`)
- Drop OS suffixes when files are already in OS-specific directories (e.g., `cleanup.sh` not `cleanup_debian.sh`)
- Keep script responsibilities narrow; split large scripts into logical units

## Do/Don’t Quick List

- Do: source libraries (`${LIB_CORE_SH}`, `${LIB_OS_SH}`), be idempotent, log via helpers, gate with `require_root`.
- Do: minimize apt calls, prefer helpers, verify downloads with checksums when possible.
- Don’t: echo blindly, hardcode absolute paths that vary by distro, or reboot.
- Don’t: introduce architecture-specific VirtualBox tweaks into scripts; keep that in Packer vars.

## Doc Changelog

| Version | Date       | Changes                                                                                                                                     |
|---------|------------|---------------------------------------------------------------------------------------------------------------------------------------------|
| 1.7.0   | 2025-11-14 | Changed: Variants use OS-specific subdirectories; providers/virtualbox prepared for multi‑OS (common + per‑OS wrappers); added dynamic selection examples. |
| 1.6.0   | 2025-11-14 | Changed: Switch to modular libraries (`lib-core.sh` + OS-specific); updated sourcing pattern and environment vars (LIB_CORE_SH, LIB_OS_SH). |
| 1.5.1   | 2025-11-13 | Changed: Replaced references to lib::apt_update_once with lib::ensure_apt_updated.                                                          |
| 1.5.0   | 2025-11-13 | Added Variant Pattern section; updated directory layout to four-tier with variants/.                                                        |
| 1.4.0   | 2025-11-13 | Added Provider Integration Pattern; lib helpers for providers; deprecated build_tools.                                                      |
| 1.3.0   | 2025-11-13 | Restructured directory layout: added providers/ tier; renamed debian scripts.                                                               |
| 1.2.0   | 2025-11-13 | Merged general Bash guidance; focused on this project; removed K8s/Azure specifics.                                                         |
| 1.1.0   | 2025-11-13 | Align header to root standard; clarify apt non-interactive; verifiers.                                                                      |
| 1.0.0   | 2025-11-13 | Initial version aligned to root documentation standard.                                                                                     |
