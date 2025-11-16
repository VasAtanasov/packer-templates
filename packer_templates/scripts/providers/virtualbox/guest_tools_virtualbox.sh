#!/usr/bin/env bash

# Install VirtualBox Guest Additions (Consolidated)
# This script:
#   1. Installs kernel build dependencies (headers, build tools, DKMS)
#   2. Installs VirtualBox Guest Additions from mounted ISO
#   3. Removes build dependencies to reduce box size
#
# Dependencies: lib-core.sh, lib-{debian,rhel}.sh
# Environment variables:
#   - LIB_CORE_SH: Path to lib-core.sh
#   - LIB_OS_SH: Path to OS-specific library (lib-debian.sh or lib-rhel.sh)
#   - HOME_DIR: Vagrant user home directory (default: /home/vagrant)

set -o pipefail

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

# ==============================================================================
# Step 1: Install Build Dependencies
# ==============================================================================
install_build_dependencies() {
    lib::subheader "Installing VirtualBox build dependencies"

    # Use shared library helper for kernel build dependencies
    lib::install_kernel_build_deps

    # Check if reboot is required after package installation
    if lib::check_reboot_required; then
        lib::warn "Reboot required after installing kernel packages"
        lib::log "Initiating reboot..."
        shutdown -r now
        sleep 60
    else
        lib::success "VirtualBox build dependencies installed (no reboot needed)"
    fi
}

# ==============================================================================
# Step 2: Install Guest Additions
# ==============================================================================
install_guest_additions() {
    lib::subheader "Installing VirtualBox Guest Additions"

    export DEBIAN_FRONTEND=noninteractive

    local home_dir="${HOME_DIR:-/home/vagrant}"
    local arch
    arch="$(uname -m)"

    # Read Guest Additions version from .vbox_version file
    if [ ! -f "${home_dir}/.vbox_version" ]; then
        lib::error "Guest Additions version file not found: ${home_dir}/.vbox_version"
        return 1
    fi

    local ver
    ver="$(cat "${home_dir}/.vbox_version")"
    local iso="VBoxGuestAdditions_${ver}.iso"

    lib::log "Guest Additions version: ${ver}"
    lib::log "Guest Additions ISO: ${iso}"

    # Check if ISO exists
    if [ ! -f "${home_dir}/${iso}" ]; then
        lib::error "Guest Additions ISO not found: ${home_dir}/${iso}"
        return 1
    fi

    # Mount the ISO
    lib::log "Mounting Guest Additions ISO..."
    local mount_point="/tmp/vbox"
    lib::ensure_directory "${mount_point}"

    if ! mount -o loop "${home_dir}/${iso}" "${mount_point}"; then
        lib::error "Failed to mount Guest Additions ISO"
        return 1
    fi

    # Install Guest Additions
    lib::log "Installing Guest Additions for architecture: ${arch}"

    local installer
    case "${arch}" in
        aarch64|arm64)
            installer="${mount_point}/VBoxLinuxAdditions-arm64.run"
            ;;
        *)
            installer="${mount_point}/VBoxLinuxAdditions.run"
            ;;
    esac

    if [ ! -f "${installer}" ]; then
        lib::error "Guest Additions installer not found: ${installer}"
        umount "${mount_point}" || true
        return 1
    fi

    # Run installer (may return non-zero even on success)
    lib::log "Running Guest Additions installer..."
    "${installer}" --nox11 || true

    # Verify installation by checking for vboxsf kernel module
    if ! modinfo vboxsf >/dev/null 2>&1; then
        lib::error "Guest Additions installation failed - vboxsf module not found"
        umount "${mount_point}" || true
        return 1
    fi

    lib::success "Guest Additions installed successfully"

    # Cleanup
    lib::log "Cleaning up ISO and mount point..."
    umount "${mount_point}" || true
    rm -rf "${mount_point}"
    rm -f "${home_dir}"/*.iso
    rm -rf /var/log/vboxadd*

    # Check if reboot is required
    if lib::check_reboot_required; then
        lib::warn "Reboot required after Guest Additions installation"
        lib::log "Initiating reboot..."
        shutdown -r now
        sleep 60
    else
        lib::success "Guest Additions installation complete (no reboot needed)"
    fi
}

# ==============================================================================
# Step 3: Remove Build Dependencies
# ==============================================================================
remove_build_dependencies() {
    lib::subheader "Removing VirtualBox build dependencies"

    # Use shared library helper to remove kernel build dependencies
    lib::remove_kernel_build_deps

    lib::log "Removing leftover logs"
    rm -rf /var/log/vboxadd*

    lib::success "VirtualBox build dependencies removed"
}

# ==============================================================================
# Main
# ==============================================================================
main() {
    lib::header "VirtualBox Guest Additions Installation (Consolidated)"

    # Step 1: Install build dependencies
    install_build_dependencies

    # Step 2: Install Guest Additions
    install_guest_additions

    # Step 3: Remove build dependencies (cleanup)
    remove_build_dependencies

    lib::success "VirtualBox Guest Additions installation complete"
}

main "$@"
