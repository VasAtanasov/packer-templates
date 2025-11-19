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

    # Generate default config if missing
    if [ ! -f /etc/containerd/config.toml ]; then
        lib::log "Generating /etc/containerd/config.toml"
        install -d -m 0755 /etc/containerd
        containerd config default > /etc/containerd/config.toml || true
    fi

    # Ensure systemd cgroup driver
    if grep -q '^\s*SystemdCgroup\s*=\s*false' /etc/containerd/config.toml 2>/dev/null; then
        lib::log "Enabling SystemdCgroup in containerd config"
        sed -i 's/^\(\s*SystemdCgroup\)\s*=\s*false/\1 = true/' /etc/containerd/config.toml || true
    fi

    # Update pause container image to version compatible with Kubernetes 1.30+
    lib::log "Updating pause container image to 3.10..."
    if grep -q 'sandbox_image.*pause:3\.[0-9]' /etc/containerd/config.toml; then
        sed -i 's|pause:3\.[0-9]|pause:3.10|g' /etc/containerd/config.toml
        lib::log "Pause image updated to 3.10"
    else
        lib::log "Pause image already at correct version or not found"
    fi

    # Enable and start service
    lib::ensure_service containerd

    lib::success "containerd installed and configured"
}

install_crio() {
    lib::header "Installing CRI-O (RHEL family)"

    local crio_version="${CRIO_VERSION:-1.33}"
    lib::log "Requested CRI-O version: ${crio_version}"

    # NOTE: CRI-O on RHEL-family requires external repositories (Kubic).
    # To avoid brittle hardcoding, this repo currently recommends containerd on RHEL.
    lib::error "CRI-O installation on RHEL is not yet implemented in this repo."
    lib::error "Please set CONTAINER_RUNTIME=containerd (default) or extend this script with Kubic repos."
    return 1
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
