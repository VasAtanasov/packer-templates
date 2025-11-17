#!/usr/bin/env bash
# =============================================================================
# Kubernetes Node Variant Cleanup (Debian/Ubuntu)
# =============================================================================
# Removes Kubernetes-specific build artifacts and temporary files
# Part of variant-specific provisioning - runs after k8s installation
# =============================================================================

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

lib::header "Kubernetes Variant Cleanup"

# -----------------------------------------------------------------------------
# Remove Build Dependencies
# -----------------------------------------------------------------------------
lib::subheader "Removing build dependencies"

# Remove kernel headers and build tools used for guest additions/modules
lib::log "Removing kernel headers and build essentials..."
apt-get remove -y --purge \
  build-essential \
  linux-headers-"$(uname -r)" \
  dkms \
  || lib::warn "Some build packages were not installed or already removed"

# -----------------------------------------------------------------------------
# Clean Temporary Files
# -----------------------------------------------------------------------------
lib::subheader "Cleaning temporary files"

# Remove k8s-specific temp directories (if any were created)
lib::log "Removing k8s installation artifacts..."
rm -rf /tmp/k8s-install
rm -rf /tmp/containerd-*
rm -rf /tmp/cri-o-*

# -----------------------------------------------------------------------------
# Clean Package Cache
# -----------------------------------------------------------------------------
lib::subheader "Cleaning package caches"

lib::log "Cleaning APT cache..."
apt-get autoremove -y
apt-get clean
rm -rf /var/cache/apt/archives/*.deb

# -----------------------------------------------------------------------------
# Verification
# -----------------------------------------------------------------------------
lib::subheader "Verification"

# Verify k8s binaries are still present (should NOT be removed)
lib::log "Verifying Kubernetes binaries..."
lib::verify_commands kubectl kubeadm kubelet

# Verify container runtime is still present
case "${CONTAINER_RUNTIME}" in
  containerd)
    lib::log "Verifying containerd..."
    lib::verify_commands containerd
    lib::verify_services containerd
    ;;
  cri-o|crio)
    lib::log "Verifying CRI-O..."
    lib::verify_commands crio
    lib::verify_services crio
    ;;
esac

lib::success "Kubernetes variant cleanup complete"

# Show what's still installed (for logging/debugging)
lib::log "Installed Kubernetes components:"
lib::cmd "kubectl version --client --short"
lib::cmd "kubeadm version"
lib::cmd "kubelet --version"
