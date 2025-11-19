#!/usr/bin/env bash

# OS-agnostic shared Bash helpers for provisioning scripts.
# Safe to source multiple times. Defines functions only if missing.

if [ -n "${_LIB_CORE_INCLUDED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
readonly _LIB_CORE_INCLUDED=1

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

# --- Command/binary helpers (OS-agnostic) ---
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

# --- System configuration (OS-agnostic) ---
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
    lib::log "DEBUG: Executing v2 of lib::ensure_sysctl"
    local param=$1 value=$2
    local sysctl_file="/etc/sysctl.d/k8s.conf"
    local line="${param} = ${value}"

    lib::ensure_directory "$(dirname "$sysctl_file")"

    # Check if the line is already correctly in the file.
    # The -x option to grep matches the whole line. -F treats the string literally.
    if [ -f "$sysctl_file" ] && grep -q -x -F "${line}" "${sysctl_file}"; then
        lib::log "sysctl '${line}' already persisted in ${sysctl_file}"
    else
        lib::log "Ensuring sysctl '${line}' is persisted in ${sysctl_file}..."
        # Remove any old, incorrect entry for this parameter to avoid duplicates.
        if [ -f "$sysctl_file" ]; then
            sed -i "/^${param}[[:space:]]*=/d" "${sysctl_file}"
        fi
        # Add the new, correct line.
        echo "${line}" >> "${sysctl_file}"
        lib::log "sysctl parameter persisted."
    fi

    # After ensuring persistence, check and set the live kernel value if needed.
    local current; current=$(sysctl -n "$param" 2>/dev/null || echo "")
    if [ "$current" != "$value" ]; then
        lib::log "Applying live sysctl value: ${param} = ${value}"
        if ! sysctl -w "${param}=${value}" >/dev/null 2>&1; then
            lib::warn "Failed to set live sysctl value for ${param}. Applying from file."
            # As a fallback, try to apply all settings from the file.
            sysctl -p "${sysctl_file}" >/dev/null 2>&1 || true
        fi
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
