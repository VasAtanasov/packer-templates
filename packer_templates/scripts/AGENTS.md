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

## Library Usage

- Always source the shared library first:
  - Preferred: `source "${LIB_SH}"`
  - Fallback (when running locally): `source "$(dirname "$0")/../_common/lib.sh"`
- Respect env flags if present: `VERBOSE=1`, `ASSUME_YES=1`, `LOG_NO_TS=1`.
- Use helpers instead of ad‑hoc commands:
  - Packages: `lib::apt_update_once`, `lib::ensure_package(s)`
  - Files: `lib::ensure_directory`, `lib::ensure_file`, `lib::ensure_symlink`
  - Services: `lib::ensure_service_enabled`, `lib::ensure_service_running`, `lib::ensure_service`
  - System: `lib::ensure_swap_disabled`, `lib::ensure_kernel_module`, `lib::ensure_sysctl`
  - Downloads: `lib::ensure_downloaded <url> <dest> [sha256]`

## APT and System Changes

- Do not run `apt-get update` directly; call `lib::apt_update_once`.
- Prefer `lib::ensure_package(s)` over raw `apt-get install`.
- Avoid dist-upgrade or kernel upgrades outside the dedicated update script.
- Never reboot implicitly. If absolutely required, fail with a clear message and rationale.
- Disable unattended upgrades only via the designated script(s).

## File and Service Management

- Create directories/files via helpers to ensure idempotency and correct perms.
- Manage services using the service helpers; avoid raw `systemctl` unless there’s
  no helper for the specific action.
- When editing config lines, use `lib::ensure_line_in_file` or an explicit
  file replacement via `lib::ensure_file`.

## Architecture Awareness

- Keep logic architecture-neutral by default; branch only when required.
- Detect architecture using `dpkg --print-architecture` or `${PACKER_ARCH}` if provided.
- For VirtualBox specifics, leave chipset/storage configuration to Packer variables/templates.

## Script Skeleton

```bash
#!/usr/bin/env bash

set -o pipefail

if [ -z "${LIB_SH:-}" ]; then
  # local fallback for ad-hoc runs
  SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  LIB_SH="${SCRIPT_DIR}/../_common/lib.sh"
fi
source "${LIB_SH}"

lib::strict
lib::setup_traps
lib::require_root

main() {
  lib::header "Doing a thing"
  lib::apt_update_once
  lib::ensure_packages curl ca-certificates
  # ... your logic here ...
  lib::success "Completed"
}

main "$@"
```

## Testing and Local Runs

- Scripts must run outside Packer for quick iteration. Provide the local fallback
  sourcing path shown above.
- Do not assume Packer user or working directory; compute paths from `BASH_SOURCE`.

## WSL2/VirtualBox Notes

- Do not rely on `--nat-localhostreachable1` in any provisioning logic.
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

