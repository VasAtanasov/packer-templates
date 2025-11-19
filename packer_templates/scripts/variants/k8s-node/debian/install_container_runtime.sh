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

    if lib::pkg_installed containerd.io || lib::pkg_installed containerd; then
        if lib::systemd_active containerd; then
            lib::success "containerd already installed and active, skipping..."
            return 0
        fi
    fi

    export DEBIAN_FRONTEND=noninteractive

    lib::log "Ensuring prerequisites..."
    lib::ensure_packages apt-transport-https ca-certificates curl gnupg lsb-release || true

    lib::ensure_apt_updated

    lib::ensure_apt_key_from_url https://download.docker.com/linux/debian/gpg /etc/apt/keyrings/docker.gpg

    lib::log "Adding Docker APT repository (idempotent)..."
    lib::ensure_apt_source_file /etc/apt/sources.list.d/docker.list \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(. /etc/os-release && echo \"$VERSION_CODENAME\") stable"
    lib::ensure_apt_updated

    lib::log "Installing containerd.io..."
    lib::ensure_packages containerd.io || true

    lib::log "Configuring containerd for Kubernetes (systemd cgroup + pause image)..."
    # Create default config if missing
    lib::log "Generating containerd default configuration..."
    lib::ensure_directory "/etc/containerd"
    containerd config default > /etc/containerd/config.toml

    # Ensure systemd cgroup driver
    if grep -q '^[[:space:]]*SystemdCgroup[[:space:]]*=[[:space:]]*false' /etc/containerd/config.toml; then
        sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
    fi

    # Update pause container image to version compatible with Kubernetes 1.30+
    lib::log "Updating pause container image to 3.10..."
    if grep -q 'sandbox_image.*pause:3\.[0-9]' /etc/containerd/config.toml; then
        sed -i 's|pause:3\.[0-9]|pause:3.10|g' /etc/containerd/config.toml
        lib::log "Pause image updated to 3.10"
    else
        lib::log "Pause image already at correct version or not found"
    fi


    lib::log "Enabling and (re)starting containerd service..."
    lib::ensure_service containerd || true
    systemctl restart containerd
    
    lib::log "Verifying containerd installation..."
    systemctl is-active containerd >/dev/null 2>&1 || { lib::error "containerd not active"; exit 1; }

    lib::success "containerd installed and configured successfully."
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

install_docker_runtime() {
    lib::header "Installing Docker Engine + cri-dockerd (Debian/Ubuntu)"

    export DEBIAN_FRONTEND=noninteractive

    lib::ensure_apt_updated
    lib::ensure_packages ca-certificates curl gnupg lsb-release

    # Docker CE APT repository
    lib::subheader "Configuring Docker CE repository"
    local dk_key="/etc/apt/keyrings/docker.gpg"
    lib::ensure_directory "/etc/apt/keyrings"
    if [ ! -f "$dk_key" ]; then
        curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o "$dk_key"
        chmod a+r "$dk_key"
    fi
    local arch codename
    arch="$(dpkg --print-architecture)"
    codename="$(. /etc/os-release; echo "$VERSION_CODENAME")"
    lib::ensure_apt_source_file \
        "/etc/apt/sources.list.d/docker.list" \
        "deb [arch=${arch} signed-by=${dk_key}] https://download.docker.com/linux/debian ${codename} stable"

    # cri-dockerd APT repository (pkgs.k8s.io)
    lib::subheader "Configuring cri-dockerd repository"
    local cri_key="/etc/apt/keyrings/cri-dockerd-apt-keyring.gpg"
    lib::ensure_apt_key_from_url \
        "https://pkgs.k8s.io/addons:/cri-dockerd:/stable/deb/Release.key" \
        "$cri_key"
    lib::ensure_apt_source_file \
        "/etc/apt/sources.list.d/cri-dockerd.list" \
        "deb [signed-by=${cri_key}] https://pkgs.k8s.io/addons:/cri-dockerd:/stable/deb/ /"

    lib::ensure_apt_updated

    # Install Docker Engine and cri-dockerd
    lib::ensure_packages docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin cri-dockerd

    # Enable Docker and cri-dockerd
    lib::ensure_service docker
    lib::ensure_service cri-docker.socket
    lib::ensure_service cri-docker.service

    # Configure kubelet to use cri-dockerd
    lib::ensure_line_in_file 'KUBELET_EXTRA_ARGS=--container-runtime=remote --container-runtime-endpoint=unix:///var/run/cri-dockerd.sock' \
        "/etc/default/kubelet"
    systemctl daemon-reload || true
    systemctl restart kubelet || true

    lib::success "Docker runtime installed and configured for Kubernetes via cri-dockerd"
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
        docker)
            install_docker_runtime
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
