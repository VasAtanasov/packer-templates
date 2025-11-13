#!/usr/bin/env bash

# Install build dependencies required for VirtualBox Guest Additions compilation
# This script installs kernel headers, build tools, and DKMS for compiling kernel modules

set -o pipefail

source "${LIB_SH}"

lib::strict
lib::setup_traps
lib::require_root

main() {
    lib::header "Installing VirtualBox build dependencies"

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

main "$@"
