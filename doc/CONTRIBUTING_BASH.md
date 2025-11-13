---
status: Normative specification
version: 1.0.0
scope: Bash standards for bootstrap/install scripts and helpers across modules; targets Vagrant VM runtime and optional AKS workflows
---

# Bash Scripting Standards (Kubernetes + Azure)

This repository uses Bash for optional helper tooling across local Kubernetes clusters (via Vagrant) and optional Azure AKS practice. These standards capture established patterns and formalize best practices to keep scripts robust, idempotent, and easy to maintain.

## Scope & Goals
- Write safe, auditable Bash for provisioning and validation.
- Prefer clarity over cleverness; small, composable functions.
- Fail fast on errors; produce actionable, timestamped logs.

## File Naming & Layout
- Filenames: kebab-case.
- Put shared/ad‑hoc helpers under `scripts/` and keep optional module‑specific logic under each module’s `assets/` (only if explicitly requested).
- One logical task per script. Reuse shared helpers from `scripts/lib.sh`.

## Shebang, Strict Mode, Indentation
- Shebang on line 1: `#!/usr/bin/env bash` or `#!/bin/bash` (be consistent within a directory).
- Strict mode via lib helper: Source `scripts/lib.sh` and call `lib::strict` and `lib::setup_traps` instead of inlining `set -Eeuo pipefail` and `IFS=$'\n\t'`.
  - Fallback: only if the lib is unavailable, set strict mode inline.
- Indentation: 4 spaces; no tabs.

## Logging & Output Discipline
- Use `scripts/lib.sh` logging helpers for consistency:
  - `log`, `warn`, `error`, `success`, optional `debug` (enabled with `VERBOSE=1`).
  - UI helpers: `header`, `subheader`, `hr` (horizontal rule), `kv` (key-value pairs), `cmd` (show commands).
- Send information to stdout; warnings/errors to stderr.
- Keep default output quiet; prefer concise output flags (e.g., `--only-show-errors` / `-o none` in Azure).
- Summarize results and next steps at the end of each script.
- Disable timestamps in logs with `LOG_NO_TS=1` when needed (e.g., piped output).
- Disable colors with `NO_COLOR=1` for non-interactive environments.

## Error Handling & Traps
- Centralized error handler and cleanup:
  - `trap 'lib::on_err $LINENO "$BASH_COMMAND"' ERR` (via `lib::setup_traps`) and `trap cleanup EXIT` when needed.
- On error, include line number and failing command in the log.
- Exit non‑zero on unrecoverable failures; return from functions otherwise.

## Configuration & Inputs
- Order of precedence: CLI flags → environment variables → defaults.
- Source environment files created by provisioning:
  - Always: `/etc/k8s-env`
  - When using Azure/AKS: `/etc/azure-env`
- Do not rely on interactive shell exports.
- When creating a new module, first define variables in the module `Vagrantfile` (`shell.env`) and persist them via `scripts/bootstrap.sh`. Scripts must only read from `/etc/k8s-env` and `/etc/azure-env`.
- Validate required inputs early with parameter expansion checks, e.g.:
  - `: "${CLUSTER_NAME:?CLUSTER_NAME is required}"`
- Parse CLI flags with `getopts`/`getopt` where appropriate (support `--yes/--assume-yes`, `--dry-run`, `--verbose`).
- Use the shared `require_commands` helper to verify tool availability:
  ```bash
  require_commands kubectl helm jq || exit 1
  ```

## Idempotency & Safety
- Prefer read‑only checks for inspection and verification.
- For destructive actions, require explicit confirmation (or a `--yes` flag) and log clearly.
  - Use the shared `confirm` helper for user prompts:
    ```bash
    confirm "Delete all resources?" || exit 0
    # Respects ASSUME_YES=1 or YES=1 flags for automation
    ```
- Always check state before taking action; fail fast with actionable errors.
- Prefer `--no-wait` for long‑running Azure operations and follow with `az ... wait` where supported.
- Never echo secrets. Mask sensitive values and avoid tracing around them.

### Idempotency Patterns: Practical Catalog

This catalog consolidates our recommended, state‑driven patterns for writing safe, re‑runnable Bash. Prefer checking the real system state and letting native tools enforce idempotency.

#### Core Principles
- Check before acting: inspect current state first.
- Let tools be idempotent: apt, systemctl, usermod often no‑op when state is satisfied.
- Fail fast and loud: strict mode + clear errors; do not paper over failures.
- Provide feedback: log whether an action was performed or skipped.

#### Tool/Package Installation
```bash
# Prefer command existence for CLIs
if ! command -v kubectl &>/dev/null; then
  log "Installing kubectl..."
  curl -fsSLo /usr/local/bin/kubectl "https://dl.k8s.io/release/${KUBECTL_VERSION:-$(curl -fsSL https://dl.k8s.io/release/stable.txt)}/bin/linux/amd64/kubectl"
  chmod 0755 /usr/local/bin/kubectl
else
  success "kubectl already installed"
fi

# Let apt handle idempotency; optionally add feedback
apt-get update -y
for pkg in docker.io kubelet kubeadm; do
  if ! dpkg -l | grep -q "^ii  ${pkg} "; then
    log "Installing ${pkg}..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$pkg"
  else
    success "${pkg} already installed"
  fi
done
```

#### File Operations
```bash
# Copy once
if [ ! -f /etc/kubernetes/admin.conf ]; then
  log "Copying admin.conf"
  install -m 0600 -o root -g root admin.conf /etc/kubernetes/admin.conf
else
  success "admin.conf present"
fi

# Copy only if content differs
if ! cmp -s source.conf /etc/myapp/app.conf; then
  log "Updating app.conf"
  install -m 0644 -o root -g root source.conf /etc/myapp/app.conf
else
  success "app.conf up to date"
fi

# Directories
[ -d /etc/kubernetes/manifests ] || {
  log "Creating manifests dir"
  mkdir -p /etc/kubernetes/manifests
}
```

#### Services
```bash
# Enable if not enabled; start if not active
if ! systemctl is-enabled docker &>/dev/null; then
  log "Enabling docker"
  systemctl enable docker
fi
if ! systemctl is-active docker &>/dev/null; then
  log "Starting docker"
  systemctl start docker
else
  success "docker running"
fi

# Combined pattern
systemctl is-active docker &>/dev/null || systemctl enable --now docker
```

#### Users/Groups
```bash
# Add current user to docker group if missing
if ! groups "$USER" | grep -q '\bdocker\b'; then
  log "Adding $USER to docker group"
  usermod -aG docker "$USER"
else
  success "$USER already in docker group"
fi

# Create system user if absent
id -u kubeuser &>/dev/null || useradd -r -s /usr/sbin/nologin kubeuser
```

#### Config (key=value)
```bash
# Append if missing
if ! grep -q '^net.ipv4.ip_forward=1' /etc/sysctl.conf; then
  log "Enabling IP forwarding"
  echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
  sysctl -p >/dev/null
else
  success "IP forwarding already enabled"
fi

# Update or append helper
update_config() {
  local file=$1 key=$2 value=$3
  if grep -q "^${key}=" "$file"; then
    sed -i "s|^${key}=.*|${key}=${value}|" "$file"
    log "Updated ${key} in ${file}"
  else
    echo "${key}=${value}" >>"$file"
    log "Added ${key} to ${file}"
  fi
}
```

#### Environment variables in shell profiles
```bash
if ! grep -q '^export KUBECONFIG=' /home/vagrant/.bashrc; then
  echo 'export KUBECONFIG=/etc/kubernetes/admin.conf' >> /home/vagrant/.bashrc
  chown vagrant:vagrant /home/vagrant/.bashrc
fi
```

#### Download and install a specific binary version
```bash
install_kubectl() {
  local version=${1:-v1.30.2}
  local bin=/usr/local/bin/kubectl
  if command -v kubectl &>/dev/null; then
    local cur
    cur=$(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion' || true)
    if [ "$cur" = "$version" ]; then
      success "kubectl $version already installed"
      return 0
    fi
    log "Upgrading kubectl from ${cur:-unknown} to $version"
  else
    log "Installing kubectl $version"
  fi
  curl -fsSLo "$bin" "https://dl.k8s.io/release/$version/bin/linux/amd64/kubectl"
  chmod 0755 "$bin"
}
```

#### Verification and Testing Idempotency
Keep verification separate from provisioning. A simple check script can assert state without mutating it.
```bash
check_command() { command -v "$1" &>/dev/null && echo "✓ $1" || { echo "✗ $1"; return 1; }; }
check_file()    { [ -f "$1" ] && echo "✓ $1" || { echo "✗ $1"; return 1; }; }
check_service() { systemctl is-active "$1" &>/dev/null && echo "✓ $1" || { echo "✗ $1"; return 1; }; }

FAILED=0; check_command kubectl || FAILED=1; check_service docker || FAILED=1; exit "$FAILED"
```

#### Locks: Use Sparingly and Intentionally
- Prefer state checks (command/package/file/service) over lock files for most tasks.
- Acceptable exceptions:
  - Coarse‑grained, one‑time bootstrap wrappers to skip expensive sections after success.
  - Long‑running installers that cannot easily be made idempotent via state checks.
- If you use a lock, ensure it only marks success (create after completion) and document how to re‑run.

## Kubernetes CLI Conventions
- Verify context: `kubectl config current-context` and `kubectl cluster-info`.
- Keep validation non‑mutating: only `get`, `version`, `auth can-i`, and other read operations.
- For readiness checks, poll with timeouts and clear messaging (e.g., wait for nodes Ready, kube‑system pods Ready).
- Use namespaces explicitly (`-n <ns>`) and avoid global effects.

## Azure CLI Conventions
- Verify login when Azure is in scope using the shared helper:
  ```bash
  check_azure_login || exit 1
  ```
  - Checks for `az` CLI availability and active login
  - Provides actionable error messages with `az login --use-device-code` guidance
- Support `AZ_SUBSCRIPTION_ID` and set it when provided:
  - `if [ -n "${AZ_SUBSCRIPTION_ID:-}" ]; then az account set --subscription "$AZ_SUBSCRIPTION_ID"; fi`
- Prefer deterministic outputs: always combine `--query` with `-o tsv` or `-o table` for logs. Example:
  - `SUB_ID=$(az account show --query id -o tsv)`
- Provider registration: ensure required providers are Registered; auto-register only when `REGISTER_PROVIDERS=1` is set.
  - Namespaces often needed: `Microsoft.ContainerService`, `Microsoft.Network`, `Microsoft.Compute`, `Microsoft.ContainerRegistry`.
  - Preferred: use the shared helper in `scripts/lib.sh`:
    ```bash
    ensure_provider_registered Microsoft.ContainerService Microsoft.Network || exit 1
    ```
  - Set `REGISTER_PROVIDERS=1` to auto-register missing providers; otherwise a warning is emitted.
  - Configure timeout with `PROVIDER_REGISTRATION_TIMEOUT=300` (default: 150 seconds).
- Tagging: when a module requires Azure resource creation (outside default automation), apply consistent tags: `Module`, `Context`, `Owner`, `Purpose`.
- Resource checks: prefer existence checks before create/delete and use `wait` when available.
  - Exists: `az group exists -n "$AZ_RESOURCE_GROUP"` or `az resource show ...`
  - Delete: `az group delete -n "$AZ_RESOURCE_GROUP" --yes --no-wait` then `az group wait -n "$AZ_RESOURCE_GROUP" --deleted` (if synchronous behavior is needed).
  - Throttling: use retry/backoff on `az` operations that may hit 429/5xx.

## Structure & Modularity
- Use small, focused functions. Naming: `snake_case` (e.g., `create_resource_group`).
- `readonly` uppercase for constants; use `local` for function scope variables.
- Quote all variable expansions; use arrays when building complex command arguments.
- Prefer `printf` for formatting; avoid `echo -e`.
- Avoid nested `if` statements: use early returns (`return`/`continue`) and guard clauses to keep code flat and readable.
  ```bash
  # Bad: nested if statements
  if [ "$state" != "ready" ]; then
      if [ "$auto_fix" = "1" ]; then
          if fix_state; then
              log "Fixed"
          else
              error "Failed"
          fi
      fi
  fi

  # Good: guard clauses and early returns
  if [ "$state" = "ready" ]; then
      return 0
  fi
  if [ "$auto_fix" != "1" ]; then
      warn "Auto-fix disabled"
      return 1
  fi
  if ! fix_state; then
      error "Failed to fix state"
      return 1
  fi
  log "Fixed"
  ```

## Retries & Backoff
- Wrap eventually‑consistent operations with a retry helper from `lib.sh`:
  ```bash
  # Usage: retry <max_attempts> <base_delay_seconds> <command> [args...]
  retry 5 2 kubectl get nodes || error "Failed to reach cluster"
  ```
  - Uses linear backoff: delay increases by base_delay × attempt_number.
  - Logs attempt counts and the error code on each failure.
  - Azure: specifically handle HTTP 429 (Too Many Requests) and 5xx responses by retrying the command, not just the `wait` call.

## Temporary Files & Locks
- Create temp files/dirs with `mktemp` and clean via `trap ... EXIT`.
- Prefer state checks over locks. If a lock is necessary (e.g., coarse bootstrap guard), create it only on successful completion and document how to reset.

## Dependencies & Installers
- Source reusable installers from `scripts/` in `bootstrap.sh`.
- Install packages with `DEBIAN_FRONTEND=noninteractive` and GPG‑verified keyrings.

## Security Practices
- Do not commit credentials or `.env` files.
- Mask any secrets in logs. Avoid printing connection strings.
- Verify downloads where feasible; only curl-to-bash from official sources and log provenance.
- Do not commit kubeconfigs; prefer regenerating or retrieving via `az aks get-credentials` when needed.
- After Azure tasks, consider `az logout` in cleanup or at session end (optional for local dev).

## Testing & Validation
- Lint scripts: `bash -n script.sh`. Prefer `shellcheck` locally; keep the codebase warning‑free where practical.
- Ensure validation uses non‑mutating commands and exits with clear codes/messages.
- Test idempotency: run scripts twice and verify the second run is a no-op.
- Test with strict mode: scripts should work with `set -Eeuo pipefail` without modification.

## Portability & Target Environment
- Scripts target Bash (use `[[ ]]`, arrays, `mapfile`). Do not claim POSIX `sh` compliance.
- Assume Debian 12 inside Vagrant; guard OS‑specific paths if reusing elsewhere.

## Common Patterns & Anti-Patterns

**✅ DO:**
```bash
# Check state before action
if command -v kubectl &>/dev/null; then
    log "kubectl already installed"
    return 0
fi

# Use parameter expansion for required variables
: "${CLUSTER_NAME:?CLUSTER_NAME is required}"

# Quote all expansions
kubectl apply -f "$MANIFEST_PATH"

# Use arrays for complex commands
local az_args=(
    --resource-group "$AZ_RESOURCE_GROUP"
    --location "$AZ_LOCATION"
    --only-show-errors
)
az group create "${az_args[@]}"

# Explicit output redirection
kubectl get pods > /dev/null 2>&1

# Use local for function variables
my_function() {
    local var1="value"
    local var2
    var2=$(some_command)
}
```

**❌ DON'T:**
```bash
# Don't use unquoted variables
kubectl apply -f $MANIFEST_PATH  # BAD

# Don't ignore errors silently without reason
some_command || true  # BAD: hides real issues

# Don't use command substitution in conditions without quotes
if [ $(some_command) = "value" ]; then  # BAD: word splitting

# Don't nest if statements
if [ "$a" = "1" ]; then
    if [ "$b" = "2" ]; then
        # ... BAD: use guard clauses instead
    fi
fi

# Don't use global variables in functions
my_function() {
    result="value"  # BAD: pollutes global scope
}

# Don't use eval
eval "$user_input"  # BAD: security risk

# Don't use ls to iterate
for file in $(ls *.txt); do  # BAD: breaks on spaces
    ...
done

# Instead use globs:
for file in *.txt; do
    ...
done
```

## Shared Library Architecture

The repository uses two shared bash libraries with distinct purposes:

### `scripts/lib.sh` - Runtime/Bootstrap Library

**Purpose**: Shared helper functions for runtime/bootstrap scripts that execute inside Vagrant VMs during provisioning.

**Usage**: Source in bootstrap scripts and install scripts that run during `vagrant up`:
```bash
source /vagrant/scripts/lib.sh
lib::strict
lib::setup_traps
```

**IMPORTANT**: This library is ONLY for runtime/bootstrap scripts (scripts that run inside VMs). When adding new helper functions:
- ✅ **Add to `lib.sh`** if the function is needed by runtime/bootstrap scripts (bootstrap.sh, install_*.sh)
- ❌ **Do NOT add generator-only functions** to lib.sh (use lib-generators.sh instead)

### `scripts/lib-generators.sh` - Generator Library

**Purpose**: Helper functions specifically for generator scripts (generate-*.sh) that create Vagrantfiles, bootstrap scripts, and module scaffolding.

**Usage**: Source in generator scripts:
```bash
source "${SCRIPT_DIR}/lib-generators.sh"
lib::strict
lib::setup_traps
```

**Key Features**:
- Internally sources `lib.sh`, so all base functions are available
- Contains `render_template()` for template rendering with envsubst
- Not copied to module directories (stays in project root)

**When to add functions**:
- ✅ **Add to `lib-generators.sh`** if the function is only used by generators (generate-*.sh)
- ✅ Functions that require dependencies not available in VMs (e.g., envsubst)
- ✅ Functions that perform file generation/templating operations

## Available lib.sh Helpers

The `scripts/lib.sh` library provides these reusable functions:

**Setup & Error Handling:**
- `lib::strict` - Enable strict mode (set -Eeuo pipefail, IFS)
- `lib::setup_traps` - Install error trap handler
- `lib::on_err` - Error handler (called by trap)

**Logging:**
- `log` - Info messages (blue)
- `success` - Success messages (green)
- `warn` - Warnings (yellow, stderr)
- `error` - Errors (red, stderr)
- `debug` - Debug messages (gray, only if VERBOSE=1)

**UI Formatting:**
- `header` - Section header with horizontal rules
- `subheader` - Subsection header
- `hr` - Horizontal rule separator
- `kv` - Key-value pair display
- `cmd` - Show command in dimmed style

**Validation & Dependencies:**
- `require_commands <cmd1> <cmd2>...` - Check for required CLI tools
- `confirm <prompt>` - User confirmation (respects YES/ASSUME_YES flags)

**Azure Helpers:**
- `check_azure_login` - Verify Azure CLI login status
- `ensure_provider_registered <provider1> <provider2>...` - Register Azure resource providers

**Retry Logic:**
- `retry <max> <delay> <command> [args...]` - Retry with linear backoff

**Environment Variables:**
- `VERBOSE=1` - Enable debug logging
- `LOG_NO_TS=1` - Disable timestamps in logs
- `NO_COLOR=1` - Disable color output
- `YES=1` or `ASSUME_YES=1` - Auto-confirm prompts
- `REGISTER_PROVIDERS=1` - Auto-register Azure providers
- `PROVIDER_REGISTRATION_TIMEOUT=<seconds>` - Provider registration timeout (default: 150)

## Standard Script Skeletons

Generic header for optional scripts:

```bash
#!/usr/bin/env bash
# Shared helpers + strict mode via lib; fallback to inline strict if missing
if [ -f /vagrant/scripts/lib.sh ]; then
  # shellcheck disable=SC1091
  source /vagrant/scripts/lib.sh
  lib::strict
  lib::setup_traps
else
  set -Eeuo pipefail
  IFS=$'\n\t'
fi

# Source environment (if present)
[ -f /etc/k8s-env ] && source /etc/k8s-env
[ -f /etc/azure-env ] && source /etc/azure-env

main() {
  log "Starting task..."
  # Implement task logic here (prefer idempotent, CLI-first steps)
}

main "$@"
```

Generic pattern for scripts that include destructive actions:

```bash
confirm_or_exit() {
  if [ "${YES:-0}" = "1" ]; then return 0; fi
  read -r -p "Proceed? [y/N] " ans
  [[ $ans == "y" || $ans == "Y" ]] || exit 0
}
```

Following these standards keeps scripts consistent, safe, and easy to reason about across all modules.

## Document History

| Version | Date       | Author     | Changes                                                         |
|---------|------------|------------|-----------------------------------------------------------------|
| 1.0.0   | 2025-11-03 | repo-maint | Added YAML frontmatter and Document History per AGENTS.md rules |
