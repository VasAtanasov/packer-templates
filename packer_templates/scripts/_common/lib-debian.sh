#!/usr/bin/env bash

# Debian/Ubuntu-specific library functions (APT-based systems)
# Requires: lib-core.sh must be sourced first
# Compatible: Debian 11+, Ubuntu 20.04+

if [ -n "${_LIB_DEBIAN_INCLUDED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
readonly _LIB_DEBIAN_INCLUDED=1

# Package query (dpkg)
if ! declare -F lib::pkg_installed >/dev/null 2>&1; then
lib::pkg_installed() {
    dpkg-query -W -f='${Status}\n' "$1" 2>/dev/null | grep -q "install ok installed"
}
fi

# Throttled apt-get update with TTL and invalidation
if ! declare -F lib::ensure_apt_updated >/dev/null 2>&1; then
lib::ensure_apt_updated() {
    local ttl="${APT_UPDATE_TTL:-300}" # seconds
    local now lists_dir need_update
    now=$(date +%s)
    lists_dir="/var/lib/apt/lists"
    need_update=0

    if [ "${APT_CACHE_INVALIDATED:-0}" = "1" ]; then
        need_update=1
    fi

    if [ "$(find "$lists_dir" -type f 2>/dev/null | wc -l | tr -d ' ')" = "0" ]; then
        need_update=1
    fi

    if [ ${need_update} -eq 0 ] && [ -n "${APT_UPDATED_TS:-}" ] && [ $((now - APT_UPDATED_TS)) -lt "$ttl" ]; then
        lib::debug "apt cache considered fresh (ttl=${ttl}s)"
        return 0
    fi

    lib::log "Updating apt cache..."
    if apt-get update -qq; then
        APT_UPDATED_TS=$now; export APT_UPDATED_TS
        APT_CACHE_INVALIDATED=0; export APT_CACHE_INVALIDATED
        lib::log "apt cache updated"
        return 0
    else
        APT_UPDATED_TS=$now; export APT_UPDATED_TS
        lib::warn "apt update encountered warnings/errors"
        return 0
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
        APT_CACHE_INVALIDATED=1; export APT_CACHE_INVALIDATED
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
    APT_CACHE_INVALIDATED=1; export APT_CACHE_INVALIDATED
    return 0
}
fi

# Single package installation
if ! declare -F lib::ensure_package >/dev/null 2>&1; then
lib::ensure_package() {
    local package=$1
    if lib::pkg_installed "$package"; then
        lib::log "$package already installed"
        return 0
    fi
    lib::ensure_apt_updated
    lib::log "Installing $package..."
    if apt-get install -y "$package" >/dev/null 2>&1; then
        lib::log "$package installed"
    else
        lib::error "Failed to install $package"
        return 1
    fi
}
fi

# Bulk package installation
if ! declare -F lib::ensure_packages >/dev/null 2>&1; then
lib::ensure_packages() {
    local to_install=() p
    for p in "$@"; do
        if lib::pkg_installed "$p"; then
            lib::log "$p already installed"
        else
            to_install+=("$p")
        fi
    done
    if [ ${#to_install[@]} -eq 0 ]; then
        return 0
    fi
    lib::ensure_apt_updated
    lib::log "Installing packages: ${to_install[*]}..."
    if apt-get install -y "${to_install[@]}" >/dev/null 2>&1; then
        lib::log "Packages installed"
        return 0
    else
        lib::error "Failed to install packages: ${to_install[*]}"
        return 1
    fi
}
fi

# Kernel build dependencies for VirtualBox additions on Debian/Ubuntu
if ! declare -F lib::install_kernel_build_deps >/dev/null 2>&1; then
lib::install_kernel_build_deps() {
    lib::log "Installing kernel build dependencies..."
    export DEBIAN_FRONTEND=noninteractive
    lib::ensure_apt_updated

    local arch
    arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"

    local kernel_headers="linux-headers-$(uname -r)"

    lib::ensure_packages build-essential dkms bzip2 tar gcc g++ make libc6-dev "$kernel_headers"
    lib::success "Kernel build dependencies installed"
}
fi

# Reboot detection for Debian/Ubuntu (with fallback if needs-restarting is present)
if ! declare -F lib::check_reboot_required >/dev/null 2>&1; then
lib::check_reboot_required() {
    if [ -f /var/run/reboot-required ]; then
        lib::log "Reboot required (found /var/run/reboot-required)"
        return 0
    fi
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

