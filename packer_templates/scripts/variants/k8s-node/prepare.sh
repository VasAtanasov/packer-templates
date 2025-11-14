#!/usr/bin/env bash

# Prepare system for Kubernetes installation
# Disables swap, configures required kernel modules and sysctl parameters

set -o pipefail

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

main() {
    lib::header "Preparing system for Kubernetes"

    # Disable swap (required by kubelet)
    lib::ensure_swap_disabled

    # Load required kernel modules for networking
    lib::log "Loading required kernel modules..."
    lib::ensure_kernel_module br_netfilter
    lib::ensure_kernel_module overlay

    # Configure sysctl parameters for Kubernetes networking
    lib::log "Configuring sysctl parameters..."
    lib::ensure_sysctl net.bridge.bridge-nf-call-iptables 1
    lib::ensure_sysctl net.bridge.bridge-nf-call-ip6tables 1
    lib::ensure_sysctl net.ipv4.ip_forward 1

    # Apply sysctl params without reboot
    sysctl --system >/dev/null 2>&1 || true

    lib::success "System prepared for Kubernetes"
}

main "$@"
