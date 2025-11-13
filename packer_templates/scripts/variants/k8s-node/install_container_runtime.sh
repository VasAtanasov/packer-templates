#!/usr/bin/env bash

# Install and configure container runtime for Kubernetes
# Supports: containerd (default) and cri-o

set -o pipefail

source "${LIB_SH}"

lib::strict
lib::setup_traps
lib::require_root

install_containerd() {
    lib::log "Installing containerd..."

    export DEBIAN_FRONTEND=noninteractive
    lib::apt_update_once

    # Install containerd
    lib::ensure_packages containerd

    # Configure containerd to use systemd cgroup driver
    lib::log "Configuring containerd..."
    lib::ensure_directory /etc/containerd

    if [ ! -f /etc/containerd/config.toml ]; then
        containerd config default > /etc/containerd/config.toml
        lib::log "Generated default containerd configuration"
    fi

    # Enable systemd cgroup driver (required for kubelet)
    if ! grep -q "SystemdCgroup = true" /etc/containerd/config.toml; then
        lib::log "Enabling systemd cgroup driver..."
        sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    fi

    # Restart containerd to apply configuration
    lib::ensure_service containerd

    lib::log "Verifying containerd installation..."
    if command -v ctr >/dev/null 2>&1; then
        local version
        version=$(ctr --version | head -n1)
        lib::log "Containerd installed: $version"
    fi

    lib::success "containerd installed and configured"
}

install_crio() {
    lib::log "Installing CRI-O..."

    export DEBIAN_FRONTEND=noninteractive
    lib::apt_update_once

    local os_version
    os_version="Debian_$(lsb_release -rs | cut -d. -f1)"
    local crio_version="${CRIO_VERSION:-1.28}"

    lib::log "CRI-O version: $crio_version, OS: $os_version"

    # Add CRI-O repository
    lib::log "Adding CRI-O repository..."
    local keyring="/usr/share/keyrings/libcontainers-crio-archive-keyring.gpg"
    local repo_url="https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/${crio_version}/${os_version}"

    lib::ensure_apt_key_from_url \
        "https://download.opensuse.org/repositories/devel:/kubic:/libcontainers:/stable:/cri-o:/${crio_version}/${os_version}/Release.key" \
        "$keyring"

    lib::ensure_apt_source_file \
        "/etc/apt/sources.list.d/devel:kubic:libcontainers:stable:cri-o:${crio_version}.list" \
        "deb [signed-by=${keyring}] ${repo_url}/ /"

    # Install CRI-O
    lib::apt_update_once
    lib::ensure_packages cri-o cri-o-runc

    # Enable and start CRI-O
    lib::ensure_service crio

    lib::log "Verifying CRI-O installation..."
    if command -v crictl >/dev/null 2>&1; then
        local version
        version=$(crictl --version | head -n1)
        lib::log "CRI-O installed: $version"
    fi

    lib::success "CRI-O installed and configured"
}

main() {
    lib::header "Installing container runtime"

    local runtime="${CONTAINER_RUNTIME:-containerd}"

    lib::log "Selected container runtime: $runtime"

    case "$runtime" in
        containerd)
            install_containerd
            ;;
        cri-o|crio)
            install_crio
            ;;
        *)
            lib::error "Unknown container runtime: $runtime"
            lib::error "Supported runtimes: containerd, cri-o"
            return 1
            ;;
    esac

    lib::success "Container runtime installation complete"
}

main "$@"
