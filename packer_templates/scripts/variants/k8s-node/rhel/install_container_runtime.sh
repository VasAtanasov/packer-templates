#!/usr/bin/env bash

# Install container runtime (containerd or CRI-O) on RHEL-family systems

set -o pipefail

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

install_containerd() {
    lib::header "Installing containerd (RHEL family)"

    lib::ensure_yum_dnf_updated

    # Install containerd package
    lib::ensure_packages containerd

    # Generate default config if missing
    if [ ! -f /etc/containerd/config.toml ]; then
        lib::log "Generating /etc/containerd/config.toml"
        install -d -m 0755 /etc/containerd
        containerd config default > /etc/containerd/config.toml || true
    fi

    # Ensure systemd cgroup driver
    if grep -q '^\s*SystemdCgroup\s*=\s*false' /etc/containerd/config.toml 2>/dev/null; then
        lib::log "Enabling SystemdCgroup in containerd config"
        sed -i 's/^\(\s*SystemdCgroup\)\s*=\s*false/\1 = true/' /etc/containerd/config.toml || true
    fi

    # Enable and start service
    lib::ensure_service containerd

    lib::success "containerd installed and configured"
}

install_crio() {
    lib::header "Installing CRI-O (RHEL family)"

    local crio_version="${CRIO_VERSION:-1.33}"
    lib::log "Requested CRI-O version: ${crio_version}"

    # NOTE: CRI-O on RHEL-family requires external repositories (Kubic).
    # To avoid brittle hardcoding, this repo currently recommends containerd on RHEL.
    lib::error "CRI-O installation on RHEL is not yet implemented in this repo."
    lib::error "Please set CONTAINER_RUNTIME=containerd (default) or extend this script with Kubic repos."
    return 1
}

main() {
    lib::header "Installing container runtime (RHEL family)"

    local runtime="${CONTAINER_RUNTIME:-containerd}"
    lib::log "Selected container runtime: $runtime"

    case "$runtime" in
        containerd)
            install_containerd
            ;;
        cri-o|crio)
            install_crio || return 1
            ;;
        *)
            lib::error "Unknown container runtime: $runtime"
            lib::error "Supported runtimes: containerd (recommended)"
            return 1
            ;;
    esac

    lib::success "Container runtime installation complete"
}

main "$@"

