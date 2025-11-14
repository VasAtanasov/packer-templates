#!/usr/bin/env bash

# Install container runtime (containerd or CRI-O) on Debian-based systems

set -o pipefail

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

install_containerd() {
    lib::header "Installing containerd"

    export DEBIAN_FRONTEND=noninteractive

    lib::ensure_apt_updated

    # Install and configure containerd
    lib::ensure_packages containerd.io

    # Create default config if missing
    if [ ! -f /etc/containerd/config.toml ]; then
        lib::log "Generating containerd default configuration..."
        mkdir -p /etc/containerd
        containerd config default > /etc/containerd/config.toml
    fi

    # Ensure systemd cgroup driver
    if ! grep -q "SystemdCgroup = true" /etc/containerd/config.toml; then
        lib::log "Setting SystemdCgroup=true in containerd config"
        sed -i 's/^\(\s*SystemdCgroup\) = false/\1 = true/' /etc/containerd/config.toml || true
    fi

    # Enable and start containerd
    lib::ensure_service containerd

    lib::success "containerd installed and configured"
}

install_crio() {
    lib::header "Installing CRI-O"

    export DEBIAN_FRONTEND=noninteractive

    lib::ensure_apt_updated

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
    lib::ensure_apt_updated
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

