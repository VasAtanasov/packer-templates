#!/usr/bin/env bash
# =============================================================================
# Docker Host Variant Cleanup (Debian/Ubuntu)
# =============================================================================
# Removes Docker-specific build artifacts and temporary files
# Part of variant-specific provisioning - runs after Docker installation
# =============================================================================

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

lib::header "Docker Host Variant Cleanup"

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

# Remove docker-specific temp directories (if any were created)
lib::log "Removing Docker installation artifacts..."
rm -rf /tmp/docker-install
rm -rf /tmp/docker-compose-*
rm -rf /tmp/containerd-*

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

# Verify Docker is still present and functional (should NOT be removed)
lib::log "Verifying Docker..."
lib::verify_commands docker
lib::verify_services docker

# Verify Docker Compose is installed
lib::log "Verifying Docker Compose..."
lib::verify_commands docker-compose || lib::warn "docker-compose not found (may be using docker compose v2)"

# Check Docker version
lib::log "Verifying Docker is functional..."
if ! docker --version >/dev/null 2>&1; then
  lib::error "Docker binary present but not functional"
fi

lib::success "Docker Host variant cleanup complete"

# Show what's still installed (for logging/debugging)
lib::log "Installed Docker components:"
lib::cmd "docker --version"
lib::cmd "docker compose version" || lib::cmd "docker-compose --version" || lib::warn "Docker Compose version check failed"
