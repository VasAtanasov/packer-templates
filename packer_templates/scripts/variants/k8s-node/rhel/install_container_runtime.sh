#!/usr/bin/env bash

# Install container runtime (containerd or CRI-O) on RHEL-family systems

set -o pipefail

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

install_containerd() {
    lib::header "Installing containerd (RHEL family)"

    lib::ensure_yum_dnf_updated

    # Ensure repo tooling is present
    if ! command -v dnf >/dev/null 2>&1; then
        lib::error "dnf not found; this script targets EL8/EL9 (dnf-based)"
        return 1
    fi
    lib::ensure_packages dnf-plugins-core || true

    # Enable CodeReady Builder (EL9) or PowerTools (EL8) for containerd
    local major
    major=$(awk -F= '/^VERSION_ID=/{gsub(/"/,"",$2);print $2}' /etc/os-release | cut -d. -f1)
    if [ "${major}" = "9" ]; then
        lib::log "Enabling CRB repository (EL9)"
        dnf config-manager --set-enabled crb >/dev/null 2>&1 || true
    elif [ "${major}" = "8" ]; then
        lib::log "Enabling PowerTools repository (EL8)"
        dnf config-manager --set-enabled powertools >/dev/null 2>&1 || \
        dnf config-manager --set-enabled PowerTools >/dev/null 2>&1 || true
    fi

    lib::ensure_yum_dnf_updated

    # Try native containerd first
    if ! lib::pkg_installed containerd; then
        lib::log "Attempting to install containerd from OS repositories"
        if ! lib::ensure_packages containerd; then
            lib::warn "containerd not available in OS repos; adding Docker CE repo for containerd.io"
            # Add Docker CE repo as a fallback provider for containerd.io
            dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >/dev/null 2>&1 || true
            lib::ensure_yum_dnf_updated
            lib::ensure_packages containerd.io || {
                lib::error "Failed to install containerd or containerd.io"
                return 1
            }
            # Align service name if using containerd.io
            if ! systemctl list-unit-files | grep -q '^containerd\.service'; then
                lib::warn "containerd.service not found; verifying containerd.io installation"
            fi
        fi
    fi

    lib::log "Generating and configuring containerd default configuration..."
    lib::ensure_directory "/etc/containerd"
    containerd config default \
      | sed 's/SystemdCgroup = false/SystemdCgroup = true/' \
      | sed -E 's|(sandbox_image[[:space:]]*=[[:space:]]*".*pause:)3\.[0-9]+|\13.10|' \
      > /etc/containerd/config.toml

    lib::log "Enabling and (re)starting containerd service..."
    lib::ensure_service containerd || true
    systemctl restart containerd

    lib::success "containerd installed and configured"
}

install_crio() {
    lib::header "Installing CRI-O (RHEL family)"

    if ! command -v dnf >/dev/null 2>&1; then
        lib::error "dnf not found; this script targets EL8/EL9 (dnf-based)"
        return 1
    fi

    lib::ensure_yum_dnf_updated

    # CRIO_VERSION comes from Packer vars, default to 1.28 to align with Debian
    local crio_version="${CRIO_VERSION:-1.28}"

    lib::log "Configuring CRI-O v${crio_version}"

    # Configure CRI-O repo (pkgs.k8s.io)
    lib::subheader "Configuring CRI-O yum repo"
    local repo_file="/etc/yum.repos.d/crio.repo"
    local baseurl="https://pkgs.k8s.io/addons:/cri-o:/stable:/v${crio_version}/rpm/"
    local gpgkey="${baseurl}repodata/repomd.xml.key"

    read -r -d '' repo_content <<EOF || true
[crio]
name=CRI-O
baseurl=${baseurl}
enabled=1
gpgcheck=1
gpgkey=${gpgkey}
EOF
    lib::ensure_yum_dnf_repo_file "$repo_file" "$repo_content"
    lib::ensure_yum_dnf_updated

    # Install packages
    lib::ensure_packages cri-o cri-tools

    # Enable and start services
    lib::ensure_service crio

    lib::success "CRI-O installed and configured"
}

install_docker_runtime() {
    lib::header "Installing Docker Engine + cri-dockerd (RHEL family)"

    if ! command -v dnf >/dev/null 2>&1; then
        lib::error "dnf not found; this script targets EL8/EL9 (dnf-based)"
        return 1
    fi

    lib::ensure_packages dnf-plugins-core || true

    # Docker CE repo for EL
    lib::subheader "Configuring Docker CE repository"
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo >/dev/null 2>&1 || true
    lib::ensure_yum_dnf_updated

    # cri-dockerd repo (pkgs.k8s.io)
    lib::subheader "Configuring cri-dockerd repository"
    local repo_file="/etc/yum.repos.d/cri-dockerd.repo"
    local baseurl="https://pkgs.k8s.io/addons:/cri-dockerd:/stable/rpm/"
    local gpgkey="${baseurl}repodata/repomd.xml.key"
    read -r -d '' repo_content <<EOF || true
[cri-dockerd]
name=CRI Dockerd Stable
baseurl=${baseurl}
enabled=1
gpgcheck=1
gpgkey=${gpgkey}
EOF
    lib::ensure_yum_dnf_repo_file "$repo_file" "$repo_content"
    lib::ensure_yum_dnf_updated

    # Install packages
    lib::ensure_packages docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin cri-dockerd

    # Enable and start services
    lib::ensure_service docker
    lib::ensure_service cri-docker.socket
    lib::ensure_service cri-docker.service

    # Configure kubelet to use cri-dockerd
    lib::ensure_line_in_file 'KUBELET_EXTRA_ARGS=--container-runtime=remote --container-runtime-endpoint=unix:///var/run/cri-dockerd.sock' \
        "/etc/sysconfig/kubelet"
    systemctl daemon-reload || true
    systemctl restart kubelet || true

    lib::success "Docker runtime installed and configured for Kubernetes via cri-dockerd"
}

main() {
    lib::header "Installing container runtime (RHEL family)"

    local runtime="${CONTAINER_RUNTIME:-containerd}"
    lib::log "Selected container runtime: $runtime"

    case "$runtime" in
        containerd)
            install_containerd
            ;;
        cri-o|crio)
            install_crio || return 1
            ;;
        docker)
            install_docker_runtime || return 1
            ;;
        *)
            lib::error "Unknown container runtime: $runtime"
            lib::error "Supported runtimes: containerd (recommended)"
            return 1
            ;;
    esac

    lib::success "Container runtime installation complete"
}

main "$@"
