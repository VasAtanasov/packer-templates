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

    local k8s_version="${K8S_VERSION:-1.33}"
    lib::log "Kubernetes version: ${k8s_version}"

    # Configure Kubernetes repo (pkgs.k8s.io)
    lib::subheader "Configuring Kubernetes yum repo"
    local repo_file="/etc/yum.repos.d/kubernetes.repo"
    local baseurl="https://pkgs.k8s.io/core:/stable:/v${k8s_version}/rpm/"
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

    # Install packages with disables of repo-level excludes
    lib::subheader "Installing kubelet kubeadm kubectl"
    lib::ensure_yum_dnf_updated
    if command -v dnf >/dev/null 2>&1; then
        dnf install -y kubelet kubeadm kubectl --disableexcludes=kubernetes >/dev/null 2>&1 || {
            lib::error "Failed to install Kubernetes packages via dnf"; return 1; }
    else
        yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes >/dev/null 2>&1 || {
            lib::error "Failed to install Kubernetes packages via yum"; return 1; }
    fi

    # Enable kubelet (expected to stay inactive until kubeadm init/join)
    systemctl enable kubelet >/dev/null 2>&1 || true

    # Verify binaries
    lib::subheader "Verification"
    lib::verify_commands kubeadm kubelet kubectl
    if command -v kubeadm >/dev/null 2>&1; then
        lib::cmd kubeadm version -o short || true
    fi

    lib::success "Kubernetes components installed"
}

main "$@"

