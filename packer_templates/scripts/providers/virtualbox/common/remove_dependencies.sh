#!/usr/bin/env bash

# Remove not needed build dependencies required for VirtualBox Guest Additions compilation
# This script installs kernel headers, build tools, and DKMS for compiling kernel modules

set -o pipefail

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

main() {
    lib::header "Removing VirtualBox build dependencies"

    # Use shared library helper for kernel build dependencies
    lib::remove_kernel_build_deps

    lib::log "removing leftover logs"
    rm -rf /var/log/vboxadd*

    # Check if reboot is required after package installation
    if lib::check_reboot_required; then
        lib::warn "Reboot required after installing kernel packages"
        lib::log "Initiating reboot..."
        shutdown -r now
        sleep 60
    else
        lib::success "VirtualBox build dependencies removed (no reboot needed)"
    fi
}

main "$@"

