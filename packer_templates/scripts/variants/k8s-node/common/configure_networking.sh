#!/usr/bin/env bash

# Configure networking prerequisites for Kubernetes
# Sets up IP forwarding and CNI prerequisites

set -o pipefail

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

main() {
    lib::header "Configuring networking for Kubernetes"

    # Verify IP forwarding is enabled (should be done by prepare.sh)
    local ipv4_forward
    ipv4_forward=$(sysctl -n net.ipv4.ip_forward 2>/dev/null || echo "0")

    if [ "$ipv4_forward" = "1" ]; then
        lib::log "IPv4 forwarding: enabled"
    else
        lib::warn "IPv4 forwarding not enabled - verifying sysctl configuration..."
        lib::ensure_sysctl net.ipv4.ip_forward 1
        sysctl -w net.ipv4.ip_forward=1 >/dev/null 2>&1
    fi

    # Verify bridge netfilter is enabled
    if [ -f /proc/sys/net/bridge/bridge-nf-call-iptables ]; then
        local bridge_nf
        bridge_nf=$(cat /proc/sys/net/bridge/bridge-nf-call-iptables 2>/dev/null || echo "0")

        if [ "$bridge_nf" = "1" ]; then
            lib::log "Bridge netfilter: enabled"
        else
            lib::warn "Bridge netfilter not enabled - loading br_netfilter module..."
            lib::ensure_kernel_module br_netfilter
            echo 1 > /proc/sys/net/bridge/bridge-nf-call-iptables
        fi
    else
        lib::warn "/proc/sys/net/bridge/bridge-nf-call-iptables not present; ensure br_netfilter is available"
    fi

    lib::success "Networking configured for Kubernetes"
}

main "$@"

