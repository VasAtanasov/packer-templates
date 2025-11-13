---
title: AGENTS (Scripts Guidance)
version: 1.2.0
status: Active
scope: packer_templates/scripts
---

# AGENTS.md (Scripts)

Guidance for agents editing anything under `packer_templates/scripts/`.
This file’s scope applies to this directory and all descendants and takes
precedence over the root `AGENTS.md` for script-related changes.

## Goals

- Keep provisioning scripts deterministic, idempotent, and fast.
- Centralize common behavior via `_common/lib.sh`.
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

- Always source the shared library provided by Packer: `source "${LIB_SH}"`.
- Respect env flags if present: `VERBOSE=1`, `ASSUME_YES=1`, `LOG_NO_TS=1`.
- Use helpers instead of ad‑hoc commands:
    - Packages: `lib::apt_update_once`, `lib::ensure_package(s)`
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

- Do not run `apt-get update` directly; call `lib::apt_update_once`.
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

## Script Skeleton

```bash
#!/usr/bin/env bash

set -o pipefail

source "${LIB_SH}"

lib::strict
lib::setup_traps
lib::require_root

main() {
  lib::header "Doing a thing"
  export DEBIAN_FRONTEND=noninteractive
  lib::apt_update_once
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

- Cross-distro helpers live in `_common/`. Distro specifics go under `debian/`.
- Use descriptive, action-oriented filenames (e.g., `sshd.sh`, `vagrant.sh`,
  `cleanup_debian.sh`).
- Keep script responsibilities narrow. If a script grows large, split into logical
  units and call them from a small orchestrator.

## Do/Don’t Quick List

- Do: source `lib.sh`, be idempotent, log via helpers, gate with `require_root`.
- Do: minimize apt calls, prefer helpers, verify downloads with checksums when possible.
- Don’t: echo blindly, hardcode absolute paths that vary by distro, or reboot.
- Don’t: introduce architecture-specific VirtualBox tweaks into scripts; keep that in Packer vars.

## Doc Changelog

| Version | Date       | Changes                                                                                 |
|---------|------------|-----------------------------------------------------------------------------------------|
| 1.2.0   | 2025-11-13 | Merged general Bash guidance; focused on this project; removed K8s/Azure specifics.     |
| 1.1.0   | 2025-11-13 | Align header to root standard; clarify apt non-interactive; verifiers.                  |
| 1.0.0   | 2025-11-13 | Initial version aligned to root documentation standard.                                 |
