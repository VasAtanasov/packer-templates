#!/usr/bin/env bash

# Install Kubernetes components: kubeadm, kubelet, kubectl
# Pins version to prevent automatic updates (Debian-based systems)

set -o pipefail

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

main() {
    lib::header "Installing Kubernetes components"

    export DEBIAN_FRONTEND=noninteractive

    local k8s_version="${K8S_VERSION:-1.28}"
    lib::log "Kubernetes version: $k8s_version"

    # Add Kubernetes APT repository
    lib::log "Adding Kubernetes repository..."
    local keyring="/etc/apt/keyrings/kubernetes-apt-keyring.gpg"
    local repo_url="https://pkgs.k8s.io/core:/stable:/v${k8s_version}/deb"

    lib::ensure_apt_key_from_url \
        "https://pkgs.k8s.io/core:/stable:/v${k8s_version}/deb/Release.key" \
        "$keyring"

    lib::ensure_apt_source_file \
        "/etc/apt/sources.list.d/kubernetes.list" \
        "deb [signed-by=${keyring}] ${repo_url}/ /"

    # Install Kubernetes components
    lib::log "Installing kubeadm, kubelet, kubectl..."
    lib::ensure_apt_updated
    lib::ensure_packages kubeadm kubelet kubectl

    # Hold packages to prevent automatic updates
    lib::log "Pinning Kubernetes packages..."
    apt-mark hold kubeadm kubelet kubectl

    # Enable kubelet service (it will fail to start until kubeadm init, but that's expected)
    lib::log "Enabling kubelet service..."
    systemctl enable kubelet >/dev/null 2>&1 || true

    # Verify installation
    lib::log "Verifying Kubernetes installation..."
    lib::verify_commands kubeadm kubelet kubectl

    if command -v kubeadm >/dev/null 2>&1; then
        local version
        version=$(kubeadm version -o short)
        lib::log "kubeadm version: $version"
    fi

    lib::success "Kubernetes components installed"
    lib::log "Node is ready for 'kubeadm init' or 'kubeadm join'"
}

main "$@"

