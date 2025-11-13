#!/usr/bin/env bash

# Shared Bash helpers for runtime/bootstrap scripts.
# Safe to source multiple times. Define functions only if missing.

if [ -n "${_LIB_BASH_INCLUDED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
readonly _LIB_BASH_INCLUDED=1

# --- Color/TTY detection ---
if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    _CLR_BLU="\033[34m"; _CLR_GRN="\033[32m"; _CLR_YLW="\033[33m"; _CLR_RED="\033[31m"; _CLR_CYN="\033[36m"; _CLR_MAG="\033[35m"; _CLR_GRY="\033[90m"; _CLR_DIM="\033[2m"; _CLR_BLD="\033[1m"; _CLR_RST="\033[0m"
else
    _CLR_BLU=""; _CLR_GRN=""; _CLR_YLW=""; _CLR_RED=""; _CLR_CYN=""; _CLR_MAG=""; _CLR_GRY=""; _CLR_DIM=""; _CLR_BLD=""; _CLR_RST=""
fi

# Public color aliases (expected by scripts)
NC="${_CLR_RST}"; BOLD="${_CLR_BLD}"; DIM="${_CLR_DIM}"
RED="${_CLR_RED}"; GREEN="${_CLR_GRN}"; YELLOW="${_CLR_YLW}"; BLUE="${_CLR_BLU}"
MAGENTA="${_CLR_MAG}"; CYAN="${_CLR_CYN}"; GRAY="${_CLR_GRY}"

# --- Strict mode helper (optional) ---
if ! declare -F lib::strict >/dev/null 2>&1; then
lib::strict() {
    set -Eeuo pipefail
    IFS=$'\n\t'
}
fi

# --- Logging helpers ---
_lib_ts() { date '+%Y-%m-%d %H:%M:%S'; }

if ! declare -F lib::log >/dev/null 2>&1; then
if [ "${LOG_NO_TS:-0}" = "1" ]; then
  lib::log()     { printf "%b%s%b\n"   "${_CLR_BLU}" "$*" "${_CLR_RST}"; }
  lib::success() { printf "%b%s%b\n"   "${_CLR_GRN}" "$*" "${_CLR_RST}"; }
  lib::warn()    { printf "%b%s%b\n"   "${_CLR_YLW}" "$*" "${_CLR_RST}" 1>&2; }
  lib::error()   { printf "%b%s%b\n"   "${_CLR_RED}" "$*" "${_CLR_RST}" 1>&2; }
  lib::debug()   { if [ "${VERBOSE:-}" = "1" ]; then printf "%b%s%b\n" "${_CLR_DIM}" "$*" "${_CLR_RST}"; fi; }
else
  lib::log()     { printf "%s %b%s%b\n"   "[$(_lib_ts)]" "${_CLR_BLU}" "$*" "${_CLR_RST}"; }
  lib::success() { printf "%s %b%s%b\n"   "[$(_lib_ts)]" "${_CLR_GRN}" "$*" "${_CLR_RST}"; }
  lib::warn()    { printf "%s %b%s%b\n"   "[$(_lib_ts)]" "${_CLR_YLW}" "$*" "${_CLR_RST}" 1>&2; }
  lib::error()   { printf "%s %b%s%b\n"   "[$(_lib_ts)]" "${_CLR_RED}" "$*" "${_CLR_RST}" 1>&2; }
  lib::debug()   { if [ "${VERBOSE:-}" = "1" ]; then printf "%s %b%s%b\n" "[$(_lib_ts)]" "${_CLR_DIM}" "$*" "${_CLR_RST}"; fi; }
fi
fi

# --- Error trap ---
if ! declare -F lib::on_err >/dev/null 2>&1; then
lib::on_err() {
    local status=$?
    local line=${1:-}
    local cmd=${2:-}
    lib::error "Command failed (exit=$status) at line $line: ${cmd}"
}
fi

# --- UI helpers (section headings + key/values) ---
if ! declare -F lib::hr >/dev/null 2>&1; then
lib::hr() { printf "%b%s%b\n" "${_CLR_GRY}" "══════════════════════════════════════════════════════════════" "${_CLR_RST}"; }
fi
if ! declare -F lib::header >/dev/null 2>&1; then
lib::header() { echo; lib::hr; printf "%b%s%b\n" "${_CLR_CYN}" "${1:-}" "${_CLR_RST}"; lib::hr; }
fi
if ! declare -F lib::subheader >/dev/null 2>&1; then
lib::subheader() { printf "%b-- %s --%b\n" "${_CLR_MAG}" "$*" "${_CLR_RST}"; }
fi
if ! declare -F lib::kv >/dev/null 2>&1; then
lib::kv() { printf "%b%-22s%b %b%s%b\n" "${_CLR_DIM}" "$1" "${_CLR_RST}" "${_CLR_BLU}" "${2:-}" "${_CLR_RST}"; }
fi
if ! declare -F lib::cmd >/dev/null 2>&1; then
lib::cmd() { printf "%b$ %s%b\n" "${_CLR_GRY}" "$*" "${_CLR_RST}"; }
fi

if ! declare -F lib::setup_traps >/dev/null 2>&1; then
lib::setup_traps() {
    trap 'lib::on_err $LINENO "$BASH_COMMAND"' ERR
}
fi

# --- Command availability ---
if ! declare -F lib::require_commands >/dev/null 2>&1; then
lib::require_commands() {
    local missing=0
    for c in "$@"; do
        if ! command -v "$c" >/dev/null 2>&1; then
            lib::error "Missing required command: $c"
            missing=1
        fi
    done
    return $missing
}
fi

# --- Root / requirements ---
if ! declare -F lib::require_root >/dev/null 2>&1; then
lib::require_root() {
    if [ "${EUID:-$(id -u)}" -ne 0 ]; then
        lib::error "This script must be run as root"
        return 1
    fi
}
fi

# --- Idempotency and state helpers ---
if ! declare -F lib::lock_path >/dev/null 2>&1; then
lib::lock_path() {
    local name=${1:?lock name}
    echo "/var/lib/k8s-installs/${name}.done"
}
fi

if ! declare -F lib::ensure_lock_dir >/dev/null 2>&1; then
lib::ensure_lock_dir() {
    install -d -m 0755 /var/lib/k8s-installs || true
}
fi

if ! declare -F lib::cmd_exists >/dev/null 2>&1; then
lib::cmd_exists() { command -v "$1" >/dev/null 2>&1; }
fi

if ! declare -F lib::pkg_installed >/dev/null 2>&1; then
lib::pkg_installed() {
    dpkg-query -W -f='${Status}\n' "$1" 2>/dev/null | grep -q "install ok installed"
}
fi

if ! declare -F lib::systemd_active >/dev/null 2>&1; then
lib::systemd_active() { systemctl is-active --quiet "$1"; }
fi

if ! declare -F lib::semver_from_string >/dev/null 2>&1; then
# Extracts first v?X.Y.Z from a string
lib::semver_from_string() {
    echo "$*" | sed -n 's/.*\([vV]\?[0-9]\+\.[0-9]\+\.[0-9]\+\).*/\1/p' | head -n1
}
fi

# --- Retry with backoff ---
if ! declare -F lib::retry >/dev/null 2>&1; then
lib::retry() {
    local max=${1:?max attempts}; shift
    local delay=${1:?base delay seconds}; shift
    local attempt=1
    while true; do
        if "$@"; then
            return 0
        fi
        local rc=$?
        if (( attempt >= max )); then
            return "$rc"
        fi
        lib::warn "Attempt $attempt failed (rc=$rc). Retrying in $((delay*attempt))s..."
        sleep $((delay * attempt))
        attempt=$((attempt + 1))
    done
}
fi

# --- Confirmation ---
if ! declare -F lib::confirm >/dev/null 2>&1; then
lib::confirm() {
    local prompt=${1:-"Are you sure?"}
    if [ "${ASSUME_YES:-}" = "1" ] || [ "${YES:-}" = "1" ]; then
        return 0
    fi
    read -r -p "$prompt [y/N]: " ans
    case "$ans" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}
fi

# --- APT helpers ---
if ! declare -F lib::ensure_apt_updated >/dev/null 2>&1; then
lib::ensure_apt_updated() {
    local stamp="/var/lib/apt/periodic/update-success-stamp"
    local max_age=3600
    if [ -f "$stamp" ]; then
        local age=$(( $(date +%s) - $(stat -c %Y "$stamp") ))
        if [ $age -lt $max_age ]; then
            lib::log "apt cache is fresh (${age}s old)"
            return 0
        fi
    fi
    lib::log "Updating apt cache..."
    if apt-get update -qq; then
        lib::log "apt cache updated"
    else
        lib::warn "apt update encountered warnings"
    fi
}
fi

if ! declare -F lib::apt_update_once >/dev/null 2>&1; then
APT_UPDATED=0
lib::apt_update_once() {
    if [ ${APT_UPDATED:-0} -eq 0 ]; then
        lib::ensure_apt_updated || true
        APT_UPDATED=1
    fi
}
fi

# Ensure an APT keyring from a URL (gpg --dearmor)
if ! declare -F lib::ensure_apt_key_from_url >/dev/null 2>&1; then
lib::ensure_apt_key_from_url() {
    local url=$1 dest=$2
    lib::ensure_directory "$(dirname "$dest")"
    if [ -f "$dest" ]; then
        lib::log "APT key present: $dest"
        return 0
    fi
    lib::log "Fetching APT key from $url -> $dest"
    if curl -fsSL "$url" | gpg --dearmor -o "$dest"; then
        chmod a+r "$dest" || true
        lib::log "APT key installed: $dest"
    else
        lib::error "Failed to install APT key: $url"
        return 1
    fi
}
fi

# Ensure an APT source file contains exactly one line
if ! declare -F lib::ensure_apt_source_file >/dev/null 2>&1; then
lib::ensure_apt_source_file() {
    local file=$1 line=$2
    lib::ensure_directory "$(dirname "$file")"
    if [ -f "$file" ] && grep -Fxq "$line" "$file"; then
        lib::log "APT source present: $file"
        return 0
    fi
    lib::log "Writing APT source: $file"
    printf '%s\n' "$line" > "$file"
    return 0
}
fi

# --- Packages / Tools ---
if ! declare -F lib::ensure_package >/dev/null 2>&1; then
lib::ensure_package() {
    local package=$1
    if lib::pkg_installed "$package"; then
        lib::log "$package already installed"
        return 0
    fi
    lib::apt_update_once
    lib::log "Installing $package..."
    if apt-get install -y "$package" >/dev/null 2>&1; then
        lib::log "$package installed"
    else
        lib::error "Failed to install $package"
        return 1
    fi
}
fi

if ! declare -F lib::ensure_packages >/dev/null 2>&1; then
lib::ensure_packages() {
    local failed=0 p
    for p in "$@"; do
        lib::ensure_package "$p" || ((failed++))
    done
    if [ $failed -gt 0 ]; then
        lib::error "$failed package(s) failed to install"
        return 1
    fi
}
fi

# --- Provider Support ---
# Helpers for provider integration (guest additions, kernel modules, etc.)

if ! declare -F lib::install_kernel_build_deps >/dev/null 2>&1; then
lib::install_kernel_build_deps() {
    lib::log "Installing kernel build dependencies..."
    export DEBIAN_FRONTEND=noninteractive
    lib::apt_update_once

    local arch
    arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"

    # Install kernel headers for current running kernel
    local kernel_headers="linux-headers-$(uname -r)"

    lib::ensure_packages build-essential dkms bzip2 tar "$kernel_headers"
    lib::success "Kernel build dependencies installed"
}
fi

if ! declare -F lib::check_reboot_required >/dev/null 2>&1; then
lib::check_reboot_required() {
    # Check for the /var/run/reboot-required file (Debian/Ubuntu)
    if [ -f /var/run/reboot-required ]; then
        lib::log "Reboot required (found /var/run/reboot-required)"
        return 0
    fi

    # Check for needs-restarting command (RHEL-based systems)
    if command -v needs-restarting >/dev/null 2>&1; then
        if needs-restarting -r >/dev/null 2>&1 || needs-restarting -s >/dev/null 2>&1; then
            lib::log "Reboot required (needs-restarting)"
            return 0
        fi
    fi

    lib::log "No reboot required"
    return 1
}
fi

if ! declare -F lib::ensure_command >/dev/null 2>&1; then
lib::ensure_command() {
    local cmd=$1 install_func=${2:-}
    if command -v "$cmd" >/dev/null 2>&1; then
        lib::log "$cmd available ($(command -v "$cmd"))"
        return 0
    fi
    if [ -z "$install_func" ]; then
        lib::error "$cmd not found and no install function provided"
        return 1
    fi
    lib::log "$cmd not found, installing..."
    if $install_func; then
        lib::log "$cmd installed successfully"
    else
        lib::error "Failed to install $cmd"
        return 1
    fi
}
fi

if ! declare -F lib::install_binary >/dev/null 2>&1; then
lib::install_binary() {
    local url=${1:?url required}
    local name=${2:?name required}
    local dest="/usr/local/bin/$name"
    if [ -f "$dest" ]; then
        lib::log "$name at $dest"
        return 0
    fi
    lib::log "Downloading $name from $url..."
    local tmp; tmp=$(mktemp)
    if curl -fsSL "$url" -o "$tmp"; then
        chmod +x "$tmp" && mv "$tmp" "$dest"
        lib::log "$name installed to $dest"
    else
        rm -f "$tmp"
        lib::error "Failed to download $name"
        return 1
    fi
}
fi

# --- Filesystem helpers ---
if ! declare -F lib::ensure_directory >/dev/null 2>&1; then
lib::ensure_directory() {
    local dir=$1 owner=${2:-root} mode=${3:-0755}
    if [ -d "$dir" ]; then
        lib::log "$dir (exists)"
        return 0
    fi
    lib::log "Creating directory $dir..."
    mkdir -p "$dir"
    chown "$owner" "$dir"
    chmod "$mode" "$dir"
    lib::log "$dir created"
}
fi

if ! declare -F lib::ensure_file >/dev/null 2>&1; then
lib::ensure_file() {
    local src=$1 dst=$2 owner=${3:-root} mode=${4:-0644}
    if [ ! -f "$src" ]; then
        lib::error "Source file not found: $src"
        return 1
    fi
    local dstdir; dstdir=$(dirname "$dst")
    lib::ensure_directory "$dstdir"
    if [ -f "$dst" ] && cmp -s "$src" "$dst" 2>/dev/null; then
        lib::log "$dst (identical)"
        return 0
    fi
    lib::log "Updating $dst..."
    cp "$src" "$dst"
    chown "$owner" "$dst"
    chmod "$mode" "$dst"
    lib::log "$dst updated"
}
fi

if ! declare -F lib::ensure_symlink >/dev/null 2>&1; then
lib::ensure_symlink() {
    local target=$1 link=$2
    if [ -L "$link" ] && [ "$(readlink "$link")" = "$target" ]; then
        lib::log "$link → $target"
        return 0
    fi
    lib::log "Creating symlink $link → $target..."
    ln -sf "$target" "$link" && lib::log "Symlink created" || { lib::error "Failed to create symlink"; return 1; }
}
fi

# --- Services ---
if ! declare -F lib::ensure_service_enabled >/dev/null 2>&1; then
lib::ensure_service_enabled() {
    local service=$1
    if systemctl is-enabled "$service" >/dev/null 2>&1; then
        lib::log "$service already enabled"
        return 0
    fi
    lib::log "Enabling $service..."
    if systemctl enable "$service" >/dev/null 2>&1; then
        lib::log "$service enabled"
    else
        lib::error "Failed to enable $service"
        return 1
    fi
}
fi

if ! declare -F lib::ensure_service_running >/dev/null 2>&1; then
lib::ensure_service_running() {
    local service=$1
    if systemctl is-active "$service" >/dev/null 2>&1; then
        lib::log "$service already running"
        return 0
    fi
    lib::log "Starting $service..."
    if systemctl start "$service" >/dev/null 2>&1; then
        lib::log "$service started"
    else
        lib::error "Failed to start $service"
        return 1
    fi
}
fi

if ! declare -F lib::ensure_service >/dev/null 2>&1; then
lib::ensure_service() {
    local service=$1
    # Attempt to enable and start regardless of list-unit-files visibility
    lib::ensure_service_enabled "$service" || return 1
    lib::ensure_service_running "$service" || return 1
}
fi

# --- Users / groups ---
if ! declare -F lib::ensure_user_in_group >/dev/null 2>&1; then
lib::ensure_user_in_group() {
    local user=$1 group=$2
    if groups "$user" 2>/dev/null | grep -q "\b$group\b"; then
        lib::log "$user in $group group"
        return 0
    fi
    lib::log "Adding $user to $group group..."
    if usermod -aG "$group" "$user"; then
        lib::log "$user added to $group (takes effect next login)"
    else
        lib::error "Failed to add $user to $group"
        return 1
    fi
}
fi

# --- Downloads ---
if ! declare -F lib::ensure_downloaded >/dev/null 2>&1; then
lib::ensure_downloaded() {
    local url=$1 dest=$2 expected=${3:-}
    if [ -f "$dest" ]; then
        if [ -z "$expected" ]; then
            lib::log "$dest (exists)"
            return 0
        fi
        local actual; actual=$(sha256sum "$dest" | awk '{print $1}')
        if [ "$actual" = "$expected" ]; then
            lib::log "$dest (verified)"
            return 0
        fi
        lib::log "$dest exists but checksum mismatch; re-downloading..."
    fi
    lib::log "Downloading $url..."
    lib::ensure_directory "$(dirname "$dest")"
    if curl -fsSL -o "$dest" "$url"; then
        if [ -n "$expected" ]; then
            local actual; actual=$(sha256sum "$dest" | awk '{print $1}')
            if [ "$actual" != "$expected" ]; then
                lib::error "Checksum verification failed for $dest"
                rm -f "$dest"
                return 1
            fi
            lib::log "$dest downloaded and verified"
        else
            lib::log "$dest downloaded"
        fi
    else
        lib::error "Failed to download $url"
        return 1
    fi
}
fi

# --- Environment / config lines ---
if ! declare -F lib::ensure_line_in_file >/dev/null 2>&1; then
lib::ensure_line_in_file() {
    local line=$1 file=$2
    if [ -f "$file" ] && grep -qF "$line" "$file"; then
        lib::log "Line already in $file"
        return 0
    fi
    lib::log "Adding line to $file..."
    install -d -m 0755 "$(dirname "$file")"
    echo "$line" >> "$file"
    lib::log "Line added to $file"
}
fi

if ! declare -F lib::ensure_env_export >/dev/null 2>&1; then
lib::ensure_env_export() {
    local profile=$1 name=$2 value=$3
    local export_line="export ${name}=\"$value\""
    if [ -f "$profile" ] && grep -q "^export ${name}=" "$profile"; then
        lib::log "$name already set in $profile"
        return 0
    fi
    lib::ensure_directory "$(dirname "$profile")"
    lib::log "Setting $name in $profile..."
    echo "$export_line" >> "$profile"
    lib::log "$name added to $profile (takes effect next login)"
}
fi

if ! declare -F lib::ensure_env_kv >/dev/null 2>&1; then
lib::ensure_env_kv() {
    local name=$1 value=$2 file=$3
    local line="${name}=${value}"
    lib::ensure_directory "$(dirname "$file")"
    if [ ! -f "$file" ]; then
        lib::log "Creating $file..."
        echo "$line" > "$file"
        lib::log "$file created"
        return 0
    fi
    if grep -q "^${name}=" "$file"; then
        local current; current=$(grep "^${name}=" "$file" | head -n1 | cut -d= -f2-)
        if [ "$current" = "$value" ]; then
            lib::log "${name} in $file (correct value)"
            return 0
        fi
        lib::log "Updating ${name} in $file..."
        sed -i "s|^${name}=.*|${line}|" "$file"
        lib::log "${name} updated in $file"
    else
        lib::log "Adding ${name} to $file..."
        echo "$line" >> "$file"
        lib::log "${name} added to $file"
    fi
}
fi

# --- Kubernetes system prep ---
if ! declare -F lib::ensure_swap_disabled >/dev/null 2>&1; then
lib::ensure_swap_disabled() {
    if [ "$(swapon --show | wc -l)" -eq 0 ]; then
        lib::log "Swap is disabled"
        return 0
    fi
    lib::log "Disabling swap..."
    swapoff -a || true
    if grep -q '^[^#].*\sswap\s' /etc/fstab; then
        lib::log "Commenting swap entries in /etc/fstab..."
        sed -i '/\sswap\s/s/^/#/' /etc/fstab
    fi
    lib::log "Swap disabled"
}
fi

if ! declare -F lib::ensure_kernel_module >/dev/null 2>&1; then
lib::ensure_kernel_module() {
    local module=$1
    if lsmod | grep -q "^$module\s"; then
        lib::log "Kernel module $module loaded"
        return 0
    fi
    lib::log "Loading kernel module $module..."
    if modprobe "$module"; then
        echo "$module" >> /etc/modules-load.d/k8s.conf
        lib::log "$module loaded"
    else
        lib::error "Failed to load kernel module $module"
        return 1
    fi
}
fi

if ! declare -F lib::ensure_sysctl >/dev/null 2>&1; then
lib::ensure_sysctl() {
    local param=$1 value=$2
    local current; current=$(sysctl -n "$param" 2>/dev/null || echo "")
    if [ "$current" = "$value" ]; then
        lib::log "sysctl $param = $value"
        return 0
    fi
    lib::log "Setting sysctl $param=$value..."
    sysctl -w "$param=$value" >/dev/null 2>&1 || true
    local sysctl_file="/etc/sysctl.d/k8s.conf"
    lib::ensure_directory "$(dirname "$sysctl_file")"
    if ! grep -q "^$param" "$sysctl_file" 2>/dev/null; then
        echo "$param = $value" >> "$sysctl_file"
    else
        sed -i "s|^$param\b.*|$param = $value|" "$sysctl_file"
    fi
    lib::log "sysctl parameter set"
}
fi

# --- Bootstrap Hooks & Scoped Env ---
# These functions consolidate repeated logic across bootstrap templates.

# Helper: source file if exists
if ! declare -F lib::source_if_exists >/dev/null 2>&1; then
lib::source_if_exists() {
    local f="$1"
    if [ -f "$f" ]; then
        # shellcheck disable=SC1090
        source "$f"
    fi
}
fi

# Helper: run all .sh files in directory
if ! declare -F lib::run_hook_dir >/dev/null 2>&1; then
lib::run_hook_dir() {
    local d="$1"
    if [ -d "$d" ]; then
        for f in "$d"/*.sh; do
            [ -f "$f" ] || continue
            bash "$f"
        done
    fi
}
fi

# Source scoped environment overrides
# Usage: lib::source_scoped_envs <script_dir>
# Requires: CLUSTER_NAME or CLUSTER_TYPE, NODE_ROLE (optional)
if ! declare -F lib::source_scoped_envs >/dev/null 2>&1; then
lib::source_scoped_envs() {
    local script_dir="${1:?script_dir required}"
    local scope_cluster="${CLUSTER_NAME:-${CLUSTER_TYPE:-}}"
    local scope_role="${NODE_ROLE:-}"

    # First, source global bootstrap.env.local if present
    lib::source_if_exists "${script_dir}/bootstrap.env.local"

    # Then source scoped env overrides (applied in order: cluster -> role -> cluster-role)
    if [ -n "${scope_cluster}" ]; then
        lib::source_if_exists "${script_dir}/env/cluster/${scope_cluster}.env.local"
    fi
    if [ -n "${scope_role}" ]; then
        lib::source_if_exists "${script_dir}/env/role/${scope_role}.env.local"
    fi
    if [ -n "${scope_cluster}" ] && [ -n "${scope_role}" ]; then
        lib::source_if_exists "${script_dir}/env/cluster-role/${scope_cluster}-${scope_role}.env.local"
    fi
}
fi

# Run all pre-bootstrap hooks
# Usage: lib::run_pre_hooks <script_dir>
# Requires: CLUSTER_NAME or CLUSTER_TYPE, NODE_ROLE (optional)
if ! declare -F lib::run_pre_hooks >/dev/null 2>&1; then
lib::run_pre_hooks() {
    local script_dir="${1:?script_dir required}"
    local scope_cluster="${CLUSTER_NAME:-${CLUSTER_TYPE:-}}"
    local scope_role="${NODE_ROLE:-}"

    # Global pre hook (single file)
    if [ -f "${script_dir}/bootstrap.pre.local.sh" ]; then
        bash "${script_dir}/bootstrap.pre.local.sh"
    fi

    # Global pre hooks (directory)
    lib::run_hook_dir "${script_dir}/bootstrap.pre.d"

    # Scoped pre hooks (in order: common -> cluster -> role -> cluster-role)
    lib::run_hook_dir "${script_dir}/bootstrap.pre.d/common"
    if [ -n "${scope_cluster}" ]; then
        lib::run_hook_dir "${script_dir}/bootstrap.pre.d/cluster/${scope_cluster}"
    fi
    if [ -n "${scope_role}" ]; then
        lib::run_hook_dir "${script_dir}/bootstrap.pre.d/role/${scope_role}"
    fi
    if [ -n "${scope_cluster}" ] && [ -n "${scope_role}" ]; then
        lib::run_hook_dir "${script_dir}/bootstrap.pre.d/cluster-role/${scope_cluster}-${scope_role}"
    fi
}
fi

# Run all post-bootstrap hooks
# Usage: lib::run_post_hooks <script_dir>
# Requires: CLUSTER_NAME or CLUSTER_TYPE, NODE_ROLE (optional)
if ! declare -F lib::run_post_hooks >/dev/null 2>&1; then
lib::run_post_hooks() {
    local script_dir="${1:?script_dir required}"
    local scope_cluster="${CLUSTER_NAME:-${CLUSTER_TYPE:-}}"
    local scope_role="${NODE_ROLE:-}"

    # Global post hook (single file)
    if [ -f "${script_dir}/bootstrap.post.local.sh" ]; then
        bash "${script_dir}/bootstrap.post.local.sh"
    fi

    # Global post hooks (directory)
    lib::run_hook_dir "${script_dir}/bootstrap.post.d"

    # Scoped post hooks (in order: common -> cluster -> role -> cluster-role)
    lib::run_hook_dir "${script_dir}/bootstrap.post.d/common"
    if [ -n "${scope_cluster}" ]; then
        lib::run_hook_dir "${script_dir}/bootstrap.post.d/cluster/${scope_cluster}"
    fi
    if [ -n "${scope_role}" ]; then
        lib::run_hook_dir "${script_dir}/bootstrap.post.d/role/${scope_role}"
    fi
    if [ -n "${scope_cluster}" ] && [ -n "${scope_role}" ]; then
        lib::run_hook_dir "${script_dir}/bootstrap.post.d/cluster-role/${scope_cluster}-${scope_role}"
    fi
}
fi
# --- Verification helpers ---
if ! declare -F lib::verify_commands >/dev/null 2>&1; then
lib::verify_commands() {
    local missing=0 c
    for c in "$@"; do
        if command -v "$c" >/dev/null 2>&1; then
            lib::log "$c: $(command -v "$c")"
        else
            lib::error "$c: not found"
            ((missing++))
        fi
    done
    return $missing
}
fi

if ! declare -F lib::verify_files >/dev/null 2>&1; then
lib::verify_files() {
    local missing=0 f
    for f in "$@"; do
        if [ -f "$f" ]; then
            lib::log "$f: exists"
        else
            lib::error "$f: not found"
            ((missing++))
        fi
    done
    return $missing
}
fi

if ! declare -F lib::verify_services >/dev/null 2>&1; then
lib::verify_services() {
    local failed=0 s
    for s in "$@"; do
        if systemctl is-active "$s" >/dev/null 2>&1; then
            lib::log "$s: running"
        else
            lib::error "$s: not running"
            ((failed++))
        fi
    done
    return $failed
}
fi

# --- Azure helpers ---
if ! declare -F lib::check_azure_login >/dev/null 2>&1; then
lib::check_azure_login() {
    if ! command -v az >/dev/null 2>&1; then
        lib::error "Azure CLI (az) is not installed."
        return 127
    fi
    if ! az account show >/dev/null 2>&1; then
        lib::error "Not logged in to Azure CLI. Run: az login --use-device-code"
        return 1
    fi
    lib::debug "Azure account: $(az account show --query name -o tsv 2>/dev/null || true)"
}
fi

if ! declare -F lib::ensure_provider_registered >/dev/null 2>&1; then
lib::ensure_provider_registered() {
    local provider state i failed=0
    local max_wait=${PROVIDER_REGISTRATION_TIMEOUT:-150}
    local max_attempts=$((max_wait / 5))

    for provider in "$@"; do
        state=$(az provider show -n "$provider" --query registrationState -o tsv 2>/dev/null || echo "NotRegistered")

        # Early exit: already registered
        if [ "$state" = "Registered" ]; then
            lib::debug "Provider already registered: $provider"
            continue
        fi

        # Guard: auto-registration not enabled
        if [ "${REGISTER_PROVIDERS:-0}" != "1" ]; then
            lib::warn "Provider $provider not Registered. Set REGISTER_PROVIDERS=1 to auto-register."
            continue
        fi

        # Attempt registration
        lib::log "Registering provider: $provider (state=$state)"
        if ! az provider register -n "$provider" --only-show-errors >/dev/null; then
            lib::error "Failed to initiate registration for provider: $provider"
            failed=1
            continue
        fi

        # Poll until Registered or timeout
        for i in $(seq 1 "$max_attempts"); do
            state=$(az provider show -n "$provider" --query registrationState -o tsv 2>/dev/null || echo "NotRegistered")
            if [ "$state" = "Registered" ]; then
                lib::success "Provider registered: $provider"
                break
            fi
            sleep 5
        done

        # Check final state
        if [ "$state" != "Registered" ]; then
            lib::warn "Provider '$provider' registration state after timeout: $state"
            failed=1
        fi
    done
    return $failed
}
fi
