# Custom Scripts Extension Point

This directory provides an extension mechanism for adding custom scripts to your Packer builds without modifying the core template files.

## How It Works

- Place custom shell scripts in the OS-specific subdirectory (`debian/` or `rhel/`)
- Scripts are automatically discovered and executed during provisioning
- Scripts run **after** variant provisioning but **before** base OS cleanup

## Execution Order

```
1. OS-specific configuration (systemd, sudoers, networking)
2. Variant scripts (k8s-node, docker-host, etc.)
3. → Custom scripts (YOUR EXTENSIONS) ←
4. Base OS cleanup
5. Minimization
```

## Script Naming Convention

Use numeric prefixes to control execution order:

```
debian/
  01-company-monitoring.sh
  02-security-hardening.sh
  03-custom-packages.sh
```

Scripts are sorted alphabetically, so `01-` runs before `02-`, etc.

## Script Requirements

Your custom scripts must follow these conventions:

### 1. Source the Libraries
```bash
#!/usr/bin/env bash
source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"
```

### 2. Use Library Functions
```bash
lib::header "Custom Company Setup"
lib::ensure_package "monitoring-agent"
lib::ensure_service "monitoring-agent" started enabled
lib::success "Custom setup complete"
```

### 3. Be Idempotent
Scripts should be safe to run multiple times without causing errors.

### 4. Handle Errors
Use `set -euo pipefail` or `lib::strict` for proper error handling.

## Example Custom Script

```bash
#!/usr/bin/env bash
# 01-company-setup.sh

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

lib::header "Installing Company Tools"

# Install company-specific packages
lib::ensure_packages \
  company-monitoring-agent \
  company-security-scanner

# Configure monitoring
lib::ensure_file "/etc/monitoring/config.yml" \
  "server: monitoring.company.com" \
  root:root 0644

# Enable services
lib::ensure_service "monitoring-agent" started enabled

lib::success "Company tools installed successfully"
```

## Environment Variables Available

All custom scripts have access to:

- `LIB_DIR` - Library directory path
- `LIB_CORE_SH` - Core library path
- `LIB_OS_SH` - OS-specific library path
- `VARIANT` - Current variant (base, k8s-node, docker-host)
- K8s-specific (if variant=k8s-node):
  - `K8S_VERSION`
  - `CONTAINER_RUNTIME`
  - `CRIO_VERSION`

## Git Configuration

By default, custom scripts are **ignored by git** so you can keep them private or per-environment. If you want to commit custom scripts to your repository, modify `.gitignore` accordingly.

## Testing Your Custom Scripts

1. Add your script to the appropriate OS directory
2. Make it executable: `chmod +x debian/01-my-script.sh`
3. Build: `make build TEMPLATE=debian/12-x86_64.pkrvars.hcl`
4. Verify: SSH into the box and check your customizations

## Cleanup

If your custom scripts install temporary build tools, they should clean up after themselves. However, the base OS cleanup will also remove common build artifacts.

## See Also

- `packer_templates/scripts/_common/lib-core.sh` - Available helper functions
- `packer_templates/scripts/_common/lib-debian.sh` - Debian-specific helpers
- `AGENTS.md` - Full provisioning script guidelines
