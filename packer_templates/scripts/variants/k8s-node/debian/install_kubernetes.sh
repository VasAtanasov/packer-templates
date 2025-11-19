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
    lib::ensure_apt_updated
    lib::ensure_packages apt-transport-https ca-certificates curl gnupg

    local k8s_version="${K8S_VERSION:-1.28}"
    lib::log "Kubernetes version: $k8s_version"

    # Extract major.minor version for repository (e.g., "1.28" from "1.28.5")
    local k8s_repo_version
    k8s_repo_version=$(echo "$k8s_version" | grep -oE '^[0-9]+\.[0-9]+')

    if [ -z "$k8s_repo_version" ]; then
        lib::error "Invalid Kubernetes version format: $k8s_version"
        lib::error "Expected format: major.minor (e.g., 1.28) or major.minor.patch (e.g., 1.28.5)"
        return 1
    fi

    # Add Kubernetes APT repository (always uses major.minor)
    lib::log "Adding Kubernetes repository for v${k8s_repo_version}..."
    local keyring="/etc/apt/keyrings/kubernetes-apt-keyring.gpg"
    local repo_url="https://pkgs.k8s.io/core:/stable:/v${k8s_repo_version}/deb"

    lib::ensure_apt_key_from_url \
        "https://pkgs.k8s.io/core:/stable:/v${k8s_repo_version}/deb/Release.key" \
        "$keyring"

    lib::ensure_apt_source_file \
        "/etc/apt/sources.list.d/kubernetes.list" \
        "deb [signed-by=${keyring}] ${repo_url}/ /"

    # Install Kubernetes components
    lib::ensure_apt_updated

    # Check if patch version is specified (e.g., 1.28.5)
    if [[ "$k8s_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        lib::log "Installing Kubernetes ${k8s_version} (specific patch version)..."
        lib::log "Package version pattern: ${k8s_version}-*"

        # Install specific patch version with wildcard for package revision
        # This matches packages like kubectl=1.28.5-1.1, kubectl=1.28.5-2.1, etc.
        export DEBIAN_FRONTEND=noninteractive
        apt-get install -y \
            "kubeadm=${k8s_version}-*" \
            "kubelet=${k8s_version}-*" \
            "kubectl=${k8s_version}-*" \
            "cri-tools" || {
            lib::error "Failed to install Kubernetes ${k8s_version}"
            lib::error "Version may not exist in repository. Available versions:"
            apt-cache madison kubeadm | head -n 5
            return 1
        }
    else
        lib::log "Installing latest Kubernetes from ${k8s_repo_version} repository..."
        lib::ensure_packages kubeadm kubelet kubectl cri-tools
    fi

    lib::log "Enabling bash completion for kubectl..."
    lib::ensure_directory "/etc/bash_completion.d"
    if command -v kubectl >/dev/null 2>&1; then
        kubectl completion bash > /etc/bash_completion.d/kubectl || \
            lib::warn "Failed to write kubectl bash completion"
    else
        lib::warn "kubectl not found after installation; skipping bash completion setup"
    fi

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

    lib::log "Pre-pulling core Kubernetes images for version ${k8s_version}..."
    if command -v kubeadm >/dev/null 2>&1; then
        kubeadm config images pull --kubernetes-version "${k8s_version}" || \
            lib::warn "Failed to pre-pull images. This may be due to a network issue or an older kubeadm version. Continuing..."
    fi

    lib::success "Kubernetes components installed"
    lib::log "Node is ready for 'kubeadm init' or 'kubeadm join'"
}

main "$@"

