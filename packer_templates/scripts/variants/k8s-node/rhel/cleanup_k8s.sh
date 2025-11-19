#!/usr/bin/env bash

# Kubernetes Node Variant Cleanup (RHEL/AlmaLinux/Rocky)
# Removes variant-specific build artifacts and cleans caches, but keeps k8s + runtime

set -o pipefail

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

lib::header "Kubernetes Variant Cleanup (RHEL family)"

# Remove build toolchains and headers if present
lib::subheader "Removing build dependencies"
if command -v dnf >/dev/null 2>&1; then
  dnf remove -y gcc cpp make kernel-headers kernel-devel kernel-uek-devel dkms 2>/dev/null || true
else
  yum remove -y gcc cpp make kernel-headers kernel-devel kernel-uek-devel dkms 2>/dev/null || true
fi

# Clean temporary files
lib::subheader "Cleaning temporary files"
rm -rf /tmp/k8s-install /tmp/containerd-* /tmp/cri-o-* 2>/dev/null || true

# Clean package caches
lib::subheader "Cleaning package caches"
if command -v dnf >/dev/null 2>&1; then
  dnf autoremove -y >/dev/null 2>&1 || true
  dnf clean all -y >/dev/null 2>&1 || true
else
  yum autoremove -y >/dev/null 2>&1 || true
  yum clean all -y >/dev/null 2>&1 || true
fi
rm -rf /var/cache/dnf /var/cache/yum 2>/dev/null || true

# Verification (ensure main components remain)
lib::subheader "Verification"
lib::verify_commands kubeadm kubelet kubectl
case "${CONTAINER_RUNTIME}" in
  containerd|"")
    lib::verify_commands containerd
    lib::verify_services containerd || true
    ;;
  cri-o|crio)
    lib::verify_commands crio || lib::warn "crio not found"
    lib::verify_services crio || true
    ;;
  docker)
    lib::verify_commands docker || lib::warn "docker not found"
    lib::verify_services docker || true
    lib::verify_services cri-docker.service || true
    ;;
esac

lib::success "Kubernetes variant cleanup complete (RHEL family)"
