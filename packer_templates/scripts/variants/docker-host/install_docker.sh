#!/usr/bin/env bash

set -o pipefail

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

main() {
    lib::header "Installing Docker Engine"
    export DEBIAN_FRONTEND=noninteractive

    # Install prerequisites
    lib::log "Installing Docker prerequisites..."
    lib::ensure_apt_updated
    lib::ensure_packages \
        ca-certificates \
        curl \
        gnupg \
        lsb-release

    # Add Docker GPG key
    lib::log "Adding Docker GPG key..."
    local keyring="/etc/apt/keyrings/docker.gpg"
    lib::ensure_directory "$(dirname "$keyring")"

    if [ ! -f "$keyring" ]; then
        curl -fsSL https://download.docker.com/linux/debian/gpg | \
            gpg --dearmor -o "$keyring"
        chmod a+r "$keyring"
        lib::success "Docker GPG key added"
    else
        lib::log "Docker GPG key already exists"
    fi

    # Add Docker repository
    lib::log "Adding Docker repository..."
    local arch
    arch="$(dpkg --print-architecture)"
    local codename
    codename="$(. /etc/os-release && echo "$VERSION_CODENAME")"

    local repo_file="/etc/apt/sources.list.d/docker.list"
    local repo_line="deb [arch=${arch} signed-by=${keyring}] https://download.docker.com/linux/debian ${codename} stable"

    lib::ensure_apt_source_file "$repo_file" "$repo_line"

    # Update apt cache after adding Docker repository
    lib::log "Updating apt cache with Docker repository..."
    lib::ensure_apt_updated

    # Install Docker packages
    lib::log "Installing Docker packages..."
    lib::ensure_packages \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin

    # Enable and start Docker service
    lib::log "Enabling Docker service..."
    lib::ensure_service docker

    # Add vagrant user to docker group
    lib::log "Adding vagrant user to docker group..."
    usermod -aG docker vagrant || lib::warn "Failed to add vagrant to docker group"

    # Verify installation
    lib::log "Verifying Docker installation..."
    if docker --version >/dev/null 2>&1; then
        local docker_version
        docker_version="$(docker --version | awk '{print $3}' | sed 's/,$//')"
        lib::success "Docker ${docker_version} installed successfully"
    else
        lib::error "Docker installation verification failed"
        return 1
    fi

    if docker compose version >/dev/null 2>&1; then
        local compose_version
        compose_version="$(docker compose version --short)"
        lib::success "Docker Compose ${compose_version} installed successfully"
    else
        lib::warn "Docker Compose verification failed"
    fi

    lib::success "Docker Engine installation complete"
}

main "$@"
