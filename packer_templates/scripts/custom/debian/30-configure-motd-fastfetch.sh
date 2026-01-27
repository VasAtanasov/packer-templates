#!/usr/bin/env bash
#
# Purpose: Configure dynamic MOTD with fastfetch for Debian systems
# Usage: Called by Packer provisioner during custom script phase
#

set -o pipefail

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

readonly MOTD_DIR="/etc/update-motd.d"
readonly FASTFETCH_MOTD_SCRIPT="${MOTD_DIR}/10-fastfetch"
readonly FASTFETCH_CONFIG_DIR="/etc/fastfetch"
readonly FASTFETCH_CONFIG="${FASTFETCH_CONFIG_DIR}/config.jsonc"

ensure_dependencies() {
    lib::header "Installing fastfetch"
    export DEBIAN_FRONTEND=noninteractive

    lib::ensure_apt_updated
    lib::ensure_packages fastfetch

    lib::success "Fastfetch installed"
}

disable_default_motd() {
    lib::header "Disabling default MOTD scripts"

    if [ ! -d "${MOTD_DIR}" ]; then
        lib::warn "MOTD directory ${MOTD_DIR} does not exist, skipping cleanup"
        return 0
    fi

    # Disable all default MOTD scripts by removing execute permission
    local disabled_count=0
    for script in "${MOTD_DIR}"/*; do
        if [ -f "${script}" ] && [ -x "${script}" ]; then
            lib::log "Disabling: $(basename "${script}")"
            chmod -x "${script}"
            disabled_count=$((disabled_count + 1))
        fi
    done

    if [ ${disabled_count} -gt 0 ]; then
        lib::success "Disabled ${disabled_count} default MOTD script(s)"
    else
        lib::log "No default MOTD scripts found to disable"
    fi
}

create_fastfetch_config() {
    lib::header "Creating fastfetch configuration"

    lib::ensure_directory "${FASTFETCH_CONFIG_DIR}" "root" "0755"

    cat > "${FASTFETCH_CONFIG}" <<'EOF'
{
    "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
    "logo": {
        "type": "auto"
    },
    "display": {
        "separator": ": "
    },
    "modules": [
        "title",
        "separator",
        "os",
        "kernel",
        "uptime",
        "packages",
        "shell",
        "terminal",
        "cpu",
        "memory",
        "disk",
        "break",
        "colors"
    ]
}
EOF

    chown root:root "${FASTFETCH_CONFIG}"
    chmod 0644 "${FASTFETCH_CONFIG}"

    lib::success "Fastfetch config created: ${FASTFETCH_CONFIG}"
}

create_motd_script() {
    lib::header "Creating MOTD script"

    lib::ensure_directory "${MOTD_DIR}" "root" "0755"

    cat > "${FASTFETCH_MOTD_SCRIPT}" <<'EOF'
#!/bin/bash

export HOME=/root
export RUNNING_MOTD=1

if command -v fastfetch >/dev/null 2>&1; then
    USER_NAME="${USER:-${LOGNAME:-vagrant}}"
    USER_HOME="$(getent passwd "${USER_NAME}" | cut -d: -f6)"
    
    if [ -n "${USER_HOME}" ] && [ -d "${USER_HOME}" ]; then
        sudo -u "${USER_NAME}" HOME="${USER_HOME}" RUNNING_MOTD=1 fastfetch --config /etc/fastfetch/config.jsonc 2>/dev/null
    else
        fastfetch --config /etc/fastfetch/config.jsonc 2>/dev/null
    fi
fi
EOF

    chown root:root "${FASTFETCH_MOTD_SCRIPT}"
    chmod 0755 "${FASTFETCH_MOTD_SCRIPT}"

    lib::success "MOTD script created: ${FASTFETCH_MOTD_SCRIPT}"
}

clear_static_motd() {
    lib::header "Clearing static MOTD files"

    # Clear /etc/motd (static message of the day)
    if [ -f /etc/motd ]; then
        > /etc/motd
        lib::log "Cleared /etc/motd"
    fi

    # Remove legal notice if present
    if [ -f /etc/legal ]; then
        rm -f /etc/legal
        lib::log "Removed /etc/legal"
    fi

    lib::success "Static MOTD files cleared"
}

verify_installation() {
    lib::header "Verifying installation"

    lib::verify_commands fastfetch

    if [ ! -f "${FASTFETCH_CONFIG}" ]; then
        lib::error "Fastfetch config not found: ${FASTFETCH_CONFIG}"
        return 1
    fi
    lib::log "✓ Fastfetch config present"

    if [ ! -x "${FASTFETCH_MOTD_SCRIPT}" ]; then
        lib::error "MOTD script not executable: ${FASTFETCH_MOTD_SCRIPT}"
        return 1
    fi
    lib::log "✓ MOTD script executable"

    lib::success "Installation verified"
}

show_completion_info() {
    lib::header "Configuration Complete"
    lib::log "Fastfetch MOTD configured for dynamic display"
    lib::log "Location: ${FASTFETCH_MOTD_SCRIPT}"
    lib::log "Config: ${FASTFETCH_CONFIG}"
    lib::log ""
    lib::log "Test output: fastfetch --config ${FASTFETCH_CONFIG}"
    lib::log "MOTD updates automatically on SSH login"
}

main() {
    lib::header "Configuring Dynamic MOTD with Fastfetch"

    ensure_dependencies
    disable_default_motd
    create_fastfetch_config
    create_motd_script
    clear_static_motd
    verify_installation
    show_completion_info

    lib::success "Fastfetch MOTD setup completed successfully"
}

main "$@"
