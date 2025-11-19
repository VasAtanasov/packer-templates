#!/usr/bin/env bash

# Install Kubernetes components on RHEL-family systems
# Uses pkgs.k8s.io RPM repositories with per-version pinning semantics

set -o pipefail

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

main() {
    lib::header "Installing Kubernetes components (RHEL family)"

    # Install prerequisites for Kubernetes repository
    lib::log "Installing prerequisites..."
    lib::ensure_yum_dnf_updated
    lib::ensure_packages ca-certificates curl gnupg2

    local k8s_version="${K8S_VERSION:-1.33}"
    lib::log "Kubernetes version: ${k8s_version}"

    # Extract major.minor version for repository (e.g., "1.28" from "1.28.5")
    local k8s_repo_version
    k8s_repo_version=$(echo "$k8s_version" | grep -oE '^[0-9]+\.[0-9]+')

    if [ -z "$k8s_repo_version" ]; then
        lib::error "Invalid Kubernetes version format: $k8s_version"
        lib::error "Expected format: major.minor (e.g., 1.28) or major.minor.patch (e.g., 1.28.5)"
        return 1
    fi

    # Configure Kubernetes repo (pkgs.k8s.io) - always uses major.minor
    lib::subheader "Configuring Kubernetes yum repo for v${k8s_repo_version}"
    local repo_file="/etc/yum.repos.d/kubernetes.repo"
    local baseurl="https://pkgs.k8s.io/core:/stable:/v${k8s_repo_version}/rpm/"
    local gpgkey="${baseurl}repodata/repomd.xml.key"

    read -r -d '' repo_content <<EOF || true
[kubernetes]
name=Kubernetes
baseurl=${baseurl}
enabled=1
gpgcheck=1
gpgkey=${gpgkey}
# Prevent unintended upgrades outside pinned stream
exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
EOF

    lib::ensure_yum_dnf_repo_file "$repo_file" "$repo_content"

    # Install packages with version-specific logic
    lib::subheader "Installing kubelet kubeadm kubectl"
    lib::ensure_yum_dnf_updated

    # Check if patch version is specified (e.g., 1.28.5)
    if [[ "$k8s_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        lib::log "Installing Kubernetes ${k8s_version} (specific patch version)..."

        # Install specific patch version
        # RPM packages typically use format: kubeadm-1.28.5-150500.1.1.x86_64
        if command -v dnf >/dev/null 2>&1; then
            dnf install -y \
                "kubelet-${k8s_version}*" \
                "kubeadm-${k8s_version}*" \
                "kubectl-${k8s_version}*" \
                "cri-tools" \
                --disableexcludes=kubernetes >/dev/null 2>&1 || {
                lib::error "Failed to install Kubernetes ${k8s_version} via dnf"
                lib::error "Version may not exist in repository. Available versions:"
                dnf list --showduplicates kubeadm 2>/dev/null | grep -E "^kubeadm" | head -n 5
                return 1
            }
        else
            yum install -y \
                "kubelet-${k8s_version}*" \
                "kubeadm-${k8s_version}*" \
                "kubectl-${k8s_version}*" \
                "cri-tools" \
                --disableexcludes=kubernetes >/dev/null 2>&1 || {
                lib::error "Failed to install Kubernetes ${k8s_version} via yum"
                lib::error "Version may not exist in repository. Available versions:"
                yum list --showduplicates kubeadm 2>/dev/null | grep -E "^kubeadm" | head -n 5
                return 1
            }
        fi
    else
        lib::log "Installing latest Kubernetes from ${k8s_repo_version} repository..."
        if command -v dnf >/dev/null 2>&1; then
            dnf install -y kubelet kubeadm kubectl cri-tools --disableexcludes=kubernetes >/dev/null 2>&1 || {
                lib::error "Failed to install Kubernetes packages via dnf"; return 1; }
        else
            yum install -y kubelet kubeadm kubectl cri-tools --disableexcludes=kubernetes >/dev/null 2>&1 || {
                lib::error "Failed to install Kubernetes packages via yum"; return 1; }
        fi
    fi

    # Enable kubelet (expected to stay inactive until kubeadm init/join)
    systemctl enable kubelet >/dev/null 2>&1 || true

    # Verify binaries
    lib::subheader "Verification"
    lib::verify_commands kubeadm kubelet kubectl
    if command -v kubeadm >/dev/null 2>&1; then
        lib::cmd kubeadm version -o short || true
    fi

    lib::log "Pre-pulling core Kubernetes images for version ${k8s_version}..."
    if command -v kubeadm >/dev/null 2>&1; then
        kubeadm config images pull --kubernetes-version "${k8s_version}" || \
            lib::warn "Failed to pre-pull images. This may be due to a network issue or an older kubeadm version. Continuing..."
    fi

    lib::success "Kubernetes components installed"
}

main "$@"

