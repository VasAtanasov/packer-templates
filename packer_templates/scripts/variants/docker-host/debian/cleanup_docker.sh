#!/usr/bin/env bash
source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

lib::header "Docker Host Variant Cleanup"

lib::subheader "Removing build dependencies"
lib::log "Removing kernel headers and build essentials..."
apt-get remove -y --purge \
  build-essential \
  linux-headers-"$(uname -r)" \
  dkms \
  || lib::warn "Some build packages were not installed or already removed"

lib::subheader "Cleaning temporary files"
lib::log "Removing Docker installation artifacts..."
rm -rf /tmp/docker-install
rm -rf /tmp/docker-compose-*
rm -rf /tmp/containerd-*

lib::subheader "Cleaning package caches"
lib::log "Cleaning APT cache..."
apt-get autoremove -y
apt-get clean
rm -rf /var/cache/apt/archives/*.deb

lib::subheader "Verification"
lib::log "Verifying Docker..."
lib::verify_commands docker
lib::verify_services docker
lib::log "Verifying Docker Compose..."
lib::verify_commands docker-compose || lib::warn "docker-compose not found (may be using docker compose v2)"
lib::log "Verifying Docker is functional..."
if ! docker --version >/dev/null 2>&1; then
  lib::error "Docker binary present but not functional"
fi

lib::log "Verifying Docker packages are held..."
held_packages=$(apt-mark showhold | grep -E "docker-ce|docker-ce-cli|containerd.io" || true)
if [[ -n "$held_packages" ]]; then
    lib::success "Docker packages are held:"
    echo "$held_packages" | while read -r pkg; do
        lib::log "  - $pkg"
    done
else
    lib::warn "Docker packages are not held (expected: docker-ce, docker-ce-cli, containerd.io)"
fi

lib::success "Docker Host variant cleanup complete"
lib::log "Installed Docker components:"
lib::cmd "docker --version"
lib::cmd "docker compose version" || lib::cmd "docker-compose --version" || lib::warn "Docker Compose version check failed"
