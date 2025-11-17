---
title: Custom Scripts (Extensibility)
version: 1.2.0
status: Active
scope: Custom script extension point for provisioning
---

# Custom Scripts Extension Point

This directory provides an extension mechanism to add custom provisioning steps without modifying core templates.
Custom scripts are discovered automatically per OS family and executed during the main provisioning phase.

## How It Works

- Primary location: `packer_templates/scripts/custom/${os_family}/` (e.g., `debian/`, `rhel/`).
- Optional scoped locations (higher precedence):
  - Variant: `packer_templates/scripts/custom/${os_family}/${variant}`
  - Provider: `packer_templates/scripts/custom/${os_family}/${provider}` (e.g., `virtualbox`, `vmware`, `qemu`)
  - Precedence order: variant → provider → OS family
- Only files matching `??-*.sh` (two‑digit prefix) are executed, in lexicographic order.
- Scripts run after variant steps and before base cleanup.
  - Reference: packer_templates/locals.pkr.hcl:114–117, 120–145.

## Execution Order

1. OS-specific configuration (systemd, sudoers, networking)
2. Variant scripts (k8s-node, docker-host, etc.)
3. Custom scripts (this extension point)
4. Base OS cleanup
5. Final minimization

## Available Context

- Libraries: `LIB_CORE_SH`, `LIB_OS_SH` (source both)
- Variant: `VARIANT` (always available)
- Provider: `PACKER_BUILDER_TYPE` (e.g., `virtualbox-iso`, `vmware-iso`)
- K8s variant only: `K8S_VERSION`, `CONTAINER_RUNTIME`, `CRIO_VERSION`

## Naming and Ordering

- Use zero‑padded numeric prefixes to control order: `01-…`, `02-…`, `10-…`
- Keep names purpose‑driven, e.g., `20-monitoring.sh`, `30-harden-sshd.sh`
- Only files matching `??-*.sh` are executed; non‑matching files are ignored by discovery

## Script Contract

- Shebang and safety: `#!/usr/bin/env bash` and `set -o pipefail`
- Source libraries: `source "${LIB_CORE_SH}"` and `source "${LIB_OS_SH}"`
- Enable strict mode and traps: `lib::strict`; `lib::setup_traps`
- Require root: `lib::require_root`
- Idempotent operations only; safe to re-run
- Prefer helpers (APT/DNF, files, services) over raw commands

## Provider/Variant Gating

- Gate by variant with `VARIANT` to avoid running on unintended builds
- Gate by provider using `PACKER_BUILDER_TYPE` when provider specifics matter

Example gating snippet:

```bash
case "${VARIANT:-base}" in
  k8s-node|docker-host) ;;  # allowed
  *) echo "Skipping for variant=${VARIANT:-base}"; exit 0 ;;
esac

case "${PACKER_BUILDER_TYPE:-unknown}" in
  virtualbox-iso|virtualbox-ovf) ;;  # supported
  *) echo "Skipping for builder=${PACKER_BUILDER_TYPE:-unknown}"; exit 0 ;;
esac
```

## Reboots and Long Operations

- Avoid reboots inside custom scripts. If unavoidable, ensure:
  - All preceding steps are idempotent
  - Post‑reboot logic is safe to re-run or skip when complete
- Use `lib::retry` for transient downloads/network calls

## Files, Paths, and Cleanup

- Place temporary files in `/var/tmp` if needed after provisioning; `/tmp` may be cleared by minimization
- Write persistent config under standard locations (e.g., `/etc/...`, `/usr/local/bin`)
- Remember `/usr/local/lib/scripts` is removed at the end of the build

## Logging and Diagnostics

- Use `lib::header`, `lib::subheader`, `lib::log`, `lib::warn`, `lib::error`
- Verify outcomes with `lib::verify_commands`, `lib::verify_services`, `lib::verify_files`

## Security and Integrity

- Do not hardcode secrets
- Verify downloads with checksums (use `lib::ensure_downloaded`)

## Line Endings and Permissions

- Ensure LF line endings; CRLF endings are normalized to LF during script staging
- Scripts are made executable during staging; keep the executable bit in VCS for clarity

## Minimal Example

```bash
#!/usr/bin/env bash
set -o pipefail
source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"
lib::strict
lib::setup_traps
lib::require_root

lib::header "Custom Provisioning: Monitoring Agent"

# Optional gating
case "${VARIANT:-base}" in
  k8s-node|docker-host) ;; else
  *) lib::log "Skipping for variant=${VARIANT:-base}"; exit 0 ;;
esac

lib::subheader "Install prerequisites"
lib::ensure_packages curl jq || exit 1

lib::subheader "Configure service"
lib::ensure_line_in_file "ENABLE_MONITORING=yes" "/etc/default/myagent"
lib::ensure_service "myagent.service" || true

lib::subheader "Verify"
lib::verify_commands curl jq
lib::verify_services myagent.service || true

lib::success "Custom provisioning complete"
```

## Testing Your Custom Scripts

1. Add your script to the appropriate OS directory
2. Make it executable: `chmod +x debian/01-my-script.sh`
3. Build: `make build TEMPLATE=debian/12-x86_64.pkrvars.hcl`
4. Verify: SSH into the box and check your customizations

## See Also

- `../../scripts/_common/lib-core.sh` – shared helpers
- `../../scripts/_common/lib-debian.sh` – Debian/Ubuntu helpers
- `../AGENTS.md` – provisioning script rules and skeletons
- `../../AGENTS.md` – repo‑wide guidance and documentation standard

## Doc Changelog

| Version | Date       | Changes                                                     |
|---------|------------|-------------------------------------------------------------|
| 1.2.0   | 2025-11-17 | Add variant/provider scoping, strict file pattern (??-*.sh), provider gating guidance, CRLF normalization note. |
| 1.1.0   | 2025-11-17 | Added Best Practices, header metadata, and changelog block. |
| 1.0.0   | 2025-11-13 | Initial README for custom scripts extension.               |
