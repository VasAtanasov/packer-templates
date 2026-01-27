#!/usr/bin/env bash
#
# Purpose: Install and configure oh-my-posh terminal prompt for vagrant user
# Usage: Called by Packer provisioner during custom script phase
#

set -o pipefail

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

readonly OH_MY_POSH_INSTALL_DIR="/usr/local/bin"
readonly OH_MY_POSH_THEMES_DIR="/usr/local/share/oh-my-posh/themes"
readonly OH_MY_POSH_VERSION="${OH_MY_POSH_VERSION:-latest}"
readonly OH_MY_POSH_THEME="${OH_MY_POSH_THEME:-stelbent.minimal}"

ensure_dependencies() {
    lib::header "Ensuring required dependencies"
    export DEBIAN_FRONTEND=noninteractive

    lib::ensure_apt_updated
    lib::ensure_packages curl unzip

    lib::success "Dependencies ready"
}

install_oh_my_posh() {
    lib::header "Installing oh-my-posh"

    if command -v oh-my-posh &>/dev/null; then
        local current_version
        current_version=$(oh-my-posh version 2>/dev/null || echo "unknown")
        lib::success "oh-my-posh already installed (version: ${current_version})"
        return 0
    fi

    lib::log "Downloading and installing oh-my-posh..."
    lib::ensure_directory "${OH_MY_POSH_INSTALL_DIR}" "root" "0755"

    if curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d "${OH_MY_POSH_INSTALL_DIR}"; then
        lib::success "oh-my-posh binary installed to ${OH_MY_POSH_INSTALL_DIR}"
    else
        lib::error "Failed to install oh-my-posh binary"
        return 1
    fi

    if ! command -v oh-my-posh &>/dev/null; then
        lib::error "oh-my-posh installation failed - binary not found in PATH"
        return 1
    fi

    local installed_version
    installed_version=$(oh-my-posh version 2>/dev/null || echo "unknown")
    lib::success "oh-my-posh installed successfully (version: ${installed_version})"
}

download_themes() {
    lib::header "Downloading oh-my-posh themes"

    lib::ensure_directory "${OH_MY_POSH_THEMES_DIR}" "root" "0755"
    lib::log "Downloading themes from GitHub..."

    local themes_zip="/tmp/oh-my-posh-themes.zip"
    
    if curl -fsSL https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/themes.zip -o "${themes_zip}"; then
        lib::log "Extracting themes..."
        if unzip -q -o "${themes_zip}" -d "${OH_MY_POSH_THEMES_DIR}"; then
            rm -f "${themes_zip}"
            lib::success "Themes downloaded to ${OH_MY_POSH_THEMES_DIR}"
        else
            lib::error "Failed to extract themes"
            rm -f "${themes_zip}"
            return 1
        fi
    else
        lib::warn "Failed to download themes, continuing with default theme"
    fi
}

configure_user_shell() {
    local username="${1}"
    local home_dir="${2}"
    local theme="${3:-pure}"
    local bashrc="${home_dir}/.bashrc"

    lib::log "Configuring oh-my-posh for user: ${username}"

    if [ ! -f "${bashrc}" ]; then
        touch "${bashrc}"
        chown "${username}:${username}" "${bashrc}"
    fi

    if grep -q 'oh-my-posh init bash' "${bashrc}"; then
        lib::success "oh-my-posh already configured for ${username}"
        return 0
    fi

    local theme_path="${OH_MY_POSH_THEMES_DIR}/${theme}.omp.json"

    if [ -f "${theme_path}" ]; then
        cat >> "${bashrc}" <<'EOF'

# oh-my-posh prompt (only for interactive shells, not during MOTD/login)
if [[ $- == *i* ]] && [ -z "${RUNNING_MOTD:-}" ] && [ "${TERM:-}" != "dumb" ]; then
    # Ensure cache directories exist with correct ownership
    if [ ! -d "${HOME}/.cache" ]; then
        mkdir -p "${HOME}/.cache"
        chmod 0700 "${HOME}/.cache"
    fi
    if [ ! -d "${HOME}/.cache/oh-my-posh" ]; then
        mkdir -p "${HOME}/.cache/oh-my-posh"
        chmod 0755 "${HOME}/.cache/oh-my-posh"
    fi
    # Only init if we can write to the cache (skip if owned by root)
    if [ -w "${HOME}/.cache/oh-my-posh" ]; then
EOF
        cat >> "${bashrc}" <<EOF
        eval "\$(oh-my-posh init bash --config ${theme_path})"
    fi
fi
EOF
        lib::log "Using theme: ${theme}"
    else
        cat >> "${bashrc}" <<'EOF'

# oh-my-posh prompt (only for interactive shells, not during MOTD/login)
if [[ $- == *i* ]] && [ -z "${RUNNING_MOTD:-}" ] && [ "${TERM:-}" != "dumb" ]; then
    # Ensure cache directories exist with correct ownership
    if [ ! -d "${HOME}/.cache" ]; then
        mkdir -p "${HOME}/.cache"
        chmod 0700 "${HOME}/.cache"
    fi
    if [ ! -d "${HOME}/.cache/oh-my-posh" ]; then
        mkdir -p "${HOME}/.cache/oh-my-posh"
        chmod 0755 "${HOME}/.cache/oh-my-posh"
    fi
    # Only init if we can write to the cache (skip if owned by root)
    if [ -w "${HOME}/.cache/oh-my-posh" ]; then
        eval "$(oh-my-posh init bash)"
    fi
fi
EOF
        lib::warn "Theme '${theme}' not found, using default"
    fi

    # Ensure .cache directory and oh-my-posh subdirectory exist with correct ownership
    local cache_base="${home_dir}/.cache"
    local cache_dir="${cache_base}/oh-my-posh"
    
    # Create .cache directory if it doesn't exist
    lib::ensure_directory "${cache_base}" "${username}" "0700"
    
    # Create oh-my-posh cache directory
    lib::ensure_directory "${cache_dir}" "${username}" "0755"

    chown "${username}:${username}" "${bashrc}"
    lib::success "oh-my-posh configured for ${username}"
}

configure_vagrant_user() {
    lib::header "Configuring oh-my-posh for vagrant user"

    if id vagrant &>/dev/null; then
        configure_user_shell "vagrant" "/home/vagrant" "${OH_MY_POSH_THEME}"
    else
        lib::warn "vagrant user not found, skipping configuration"
    fi
}

show_completion_info() {
    lib::header "Installation Complete"
    lib::log "Configured for: vagrant user"
    lib::log "Default theme: ${OH_MY_POSH_THEME} (minimal, no special fonts required)"
    lib::log ""
    lib::log "To activate: exec bash"
    lib::log "Browse themes: https://ohmyposh.dev/docs/themes"
}

main() {
    lib::header "oh-my-posh Installation and Configuration"

    ensure_dependencies
    install_oh_my_posh
    download_themes
    configure_vagrant_user
    show_completion_info

    lib::verify_commands oh-my-posh

    lib::success "oh-my-posh setup completed successfully"
}

main "$@"
