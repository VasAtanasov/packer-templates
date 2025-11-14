#!/usr/bin/env bash

# Install VirtualBox Guest Additions
# This script mounts the Guest Additions ISO, installs the additions, and cleans up
# Dependencies (kernel headers, build tools) should be installed via install_dependencies.sh first

set -o pipefail

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

main() {
    lib::header "Installing VirtualBox Guest Additions"

    export DEBIAN_FRONTEND=noninteractive

    local home_dir="${HOME_DIR:-/home/vagrant}"
    local arch
    arch="$(dpkg --print-architecture 2>/dev/null || uname -m)"

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
    if [ "${arch}" = "aarch64" ] || [ "${arch}" = "arm64" ]; then
        installer="${mount_point}/VBoxLinuxAdditions-arm64.run"
    else
        installer="${mount_point}/VBoxLinuxAdditions.run"
    fi

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
    lib::log "Cleaning up..."
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

main "$@"

