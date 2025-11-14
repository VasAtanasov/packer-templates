#!/usr/bin/env bash

# Configure kernel parameters for Kubernetes
# Note: This script is separate from prepare.sh for modularity
# Some configurations may already be handled by prepare.sh

set -o pipefail

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

main() {
    lib::header "Configuring kernel for Kubernetes"

    export DEBIAN_FRONTEND=noninteractive

    # Ensure kernel modules are loaded at boot
    local modules_file="/etc/modules-load.d/k8s.conf"
    lib::ensure_directory "$(dirname "$modules_file")"

    if [ ! -f "$modules_file" ] || ! grep -q "br_netfilter" "$modules_file"; then
        lib::log "Creating kernel modules configuration..."
        cat > "$modules_file" <<EOF
# Kernel modules required for Kubernetes networking
overlay
br_netfilter
EOF
        lib::log "Kernel modules configuration created"
    else
        lib::log "Kernel modules already configured"
    fi

    # Verify modules are loaded
    lib::log "Verifying kernel modules..."
    if lsmod | grep -q overlay && lsmod | grep -q br_netfilter; then
        lib::success "Required kernel modules are loaded"
    else
        lib::warn "Some kernel modules may not be loaded yet (will load on next boot)"
    fi

    lib::success "Kernel configured for Kubernetes"
}

main "$@"
