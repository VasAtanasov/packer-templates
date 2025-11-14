#!/usr/bin/env bash

# RHEL/AlmaLinux/Rocky-specific library functions (DNF/YUM-based systems)
# Requires: lib-core.sh must be sourced first
# Compatible: AlmaLinux 8+, Rocky Linux 8+, RHEL 8+

if [ -n "${_LIB_RHEL_INCLUDED:-}" ]; then
    return 0 2>/dev/null || exit 0
fi
readonly _LIB_RHEL_INCLUDED=1

# Package query (rpm)
if ! declare -F lib::pkg_installed >/dev/null 2>&1; then
lib::pkg_installed() {
    rpm -q "$1" >/dev/null 2>&1
}
fi

# DNF/YUM metadata refresh with TTL
if ! declare -F lib::ensure_yum_dnf_updated >/dev/null 2>&1; then
lib::ensure_yum_dnf_updated() {
    local ttl="${YUM_DNF_UPDATE_TTL:-300}"
    local now=$(date +%s)
    local need_update=0

    if [ "${YUM_DNF_CACHE_INVALIDATED:-0}" = "1" ]; then
        need_update=1
    fi

    if [ ${need_update} -eq 0 ] && [ -n "${YUM_DNF_UPDATED_TS:-}" ] && [ $((now - YUM_DNF_UPDATED_TS)) -lt "$ttl" ]; then
        lib::debug "dnf cache considered fresh (ttl=${ttl}s)"
        return 0
    fi

    lib::log "Updating dnf cache..."
    if command -v dnf >/dev/null 2>&1; then
        if dnf makecache -q; then
            YUM_DNF_UPDATED_TS=$now; export YUM_DNF_UPDATED_TS
            YUM_DNF_CACHE_INVALIDATED=0; export YUM_DNF_CACHE_INVALIDATED
            lib::log "dnf cache updated"
            return 0
        fi
    elif command -v yum >/dev/null 2>&1; then
        if yum makecache -q; then
            YUM_DNF_UPDATED_TS=$now; export YUM_DNF_UPDATED_TS
            YUM_DNF_CACHE_INVALIDATED=0; export YUM_DNF_CACHE_INVALIDATED
            lib::log "yum cache updated"
            return 0
        fi
    fi
    YUM_DNF_UPDATED_TS=$now; export YUM_DNF_UPDATED_TS
    lib::warn "yum/dnf cache update encountered warnings/errors"
    return 0
}
fi

# Install RPM GPG key from URL and import
if ! declare -F lib::ensure_yum_dnf_key_from_url >/dev/null 2>&1; then
lib::ensure_yum_dnf_key_from_url() {
    local url=$1 dest=$2
    lib::ensure_directory "$(dirname "$dest")"
    if [ -f "$dest" ]; then
        lib::log "RPM key present: $dest"
        return 0
    fi
    lib::log "Fetching RPM key from $url -> $dest"
    if curl -fsSL "$url" -o "$dest"; then
        chmod a+r "$dest" || true
        rpm --import "$dest" 2>/dev/null || true
        lib::log "RPM key installed: $dest"
        YUM_DNF_CACHE_INVALIDATED=1; export YUM_DNF_CACHE_INVALIDATED
    else
        lib::error "Failed to install RPM key: $url"
        return 1
    fi
}
fi

# Ensure YUM/DNF repo file exists with given content
if ! declare -F lib::ensure_yum_dnf_repo_file >/dev/null 2>&1; then
lib::ensure_yum_dnf_repo_file() {
    local file=$1 content=$2
    lib::ensure_directory "$(dirname "$file")"
    if [ -f "$file" ]; then
        lib::log "YUM/DNF repo present: $file"
        return 0
    fi
    lib::log "Writing YUM/DNF repo: $file"
    printf '%s\n' "$content" > "$file"
    YUM_DNF_CACHE_INVALIDATED=1; export YUM_DNF_CACHE_INVALIDATED
    return 0
}
fi

# Single package installation (dnf/yum)
if ! declare -F lib::ensure_package >/dev/null 2>&1; then
lib::ensure_package() {
    local package=$1
    if lib::pkg_installed "$package"; then
        lib::log "$package already installed"
        return 0
    fi
    lib::ensure_yum_dnf_updated
    lib::log "Installing $package..."
    if command -v dnf >/dev/null 2>&1; then
        dnf install -y "$package" >/dev/null 2>&1 || { lib::error "Failed to install $package"; return 1; }
    else
        yum install -y "$package" >/dev/null 2>&1 || { lib::error "Failed to install $package"; return 1; }
    fi
    lib::log "$package installed"
}
fi

# Bulk package installation (dnf/yum)
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
    lib::ensure_yum_dnf_updated
    lib::log "Installing packages: ${to_install[*]}..."
    if command -v dnf >/dev/null 2>&1; then
        dnf install -y "${to_install[@]}" >/dev/null 2>&1 || { lib::error "Failed to install packages: ${to_install[*]}"; return 1; }
    else
        yum install -y "${to_install[@]}" >/dev/null 2>&1 || { lib::error "Failed to install packages: ${to_install[*]}"; return 1; }
    fi
    lib::log "Packages installed"
}
fi

# Kernel build dependencies (RHEL family)
if ! declare -F lib::install_kernel_build_deps >/dev/null 2>&1; then
lib::install_kernel_build_deps() {
    lib::log "Installing kernel build dependencies..."
    lib::ensure_yum_dnf_updated
    local kernel_devel="kernel-devel-$(uname -r)"
    # Try to install Development Tools group (ignore failures quietly)
    if command -v dnf >/dev/null 2>&1; then
        dnf groupinstall -y "Development Tools" >/dev/null 2>&1 || true
    else
        yum groupinstall -y "Development Tools" >/dev/null 2>&1 || true
    fi
    lib::ensure_packages dkms tar bzip2 "$kernel_devel"
    lib::success "Kernel build dependencies installed"
}
fi

# Reboot detection (needs-restarting)
if ! declare -F lib::check_reboot_required >/dev/null 2>&1; then
lib::check_reboot_required() {
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

