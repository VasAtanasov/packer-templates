#!/usr/bin/env bash

set -o pipefail

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

configure_docker_daemon() {
    lib::log "Configuring Docker daemon..."
    local daemon_json="/etc/docker/daemon.json"

    lib::ensure_directory /etc/docker

    if [ ! -f "$daemon_json" ]; then
        cat > "$daemon_json" <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "userland-proxy": false,
  "live-restore": true
}
EOF
        lib::success "Docker daemon configuration created"
    else
        lib::log "Docker daemon configuration already exists"
    fi
}

configure_docker_logging() {
    lib::log "Configuring log rotation for Docker..."

    local logrotate_file="/etc/logrotate.d/docker"
    if [ ! -f "$logrotate_file" ]; then
        cat > "$logrotate_file" <<'EOF'
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    delaycompress
    missingok
    notifempty
    copytruncate
}
EOF
        lib::success "Docker log rotation configured"
    else
        lib::log "Docker log rotation already configured"
    fi
}

configure_systemd_limits() {
    lib::log "Configuring systemd limits for Docker..."
    local override_dir="/etc/systemd/system/docker.service.d"
    local override_file="${override_dir}/override.conf"

    lib::ensure_directory "$override_dir"

    if [ ! -f "$override_file" ]; then
        cat > "$override_file" <<'EOF'
[Service]
LimitNOFILE=1048576
LimitNPROC=infinity
LimitCORE=infinity
EOF
        systemctl daemon-reload
        lib::success "Docker systemd limits configured"
    else
        lib::log "Docker systemd limits already configured"
    fi
}

verify_docker_configuration() {
    lib::log "Verifying Docker configuration..."

    # Check if Docker service is running
    if systemctl is-active --quiet docker; then
        lib::success "Docker service is running"
    else
        lib::error "Docker service is not running"
        return 1
    fi

    # Check Docker info
    if docker info >/dev/null 2>&1; then
        lib::success "Docker daemon is responding"
    else
        lib::error "Docker daemon is not responding"
        return 1
    fi

    # Display Docker info
    lib::log "Docker configuration summary:"
    docker info 2>/dev/null | grep -E "(Storage Driver|Logging Driver|Cgroup Driver)" || true
}

main() {
    lib::header "Configuring Docker"
    export DEBIAN_FRONTEND=noninteractive

    configure_docker_daemon
    configure_docker_logging
    configure_systemd_limits

    # Restart Docker to apply configuration
    lib::log "Restarting Docker service..."
    systemctl restart docker
    sleep 2

    verify_docker_configuration

    lib::success "Docker configuration complete"
}

main "$@"

