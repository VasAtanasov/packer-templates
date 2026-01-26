#!/usr/bin/env bash

set -o pipefail

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

main() {
    lib::header "Installing Development Tools for vagrant user"
    export DEBIAN_FRONTEND=noninteractive

    # 1. Install direnv via apt
    lib::ensure_packages direnv

    # 2. Add direnv hook to .bashrc (idempotent)
    local bashrc="/home/vagrant/.bashrc"
    if ! grep -q 'eval "$(direnv hook bash)"' "$bashrc"; then
        echo 'eval "$(direnv hook bash)"' >> "$bashrc"
        chown vagrant:vagrant "$bashrc"
        lib::success "direnv hook added to .bashrc"
    else
        lib::log "direnv hook already present in .bashrc"
    fi

    # 3. Install SDKMAN for vagrant user
    if [ ! -d "/home/vagrant/.sdkman" ]; then
        lib::log "Installing SDKMAN..."
        sudo -u vagrant bash -c 'curl -s "https://get.sdkman.io" | bash'
        lib::success "SDKMAN installed"
    else
        lib::log "SDKMAN already installed"
    fi

    # 4. Configure SDKMAN for non-interactive use
    local sdkman_config="/home/vagrant/.sdkman/etc/config"
    if [ -f "$sdkman_config" ]; then
        if ! grep -q "sdkman_auto_answer=true" "$sdkman_config"; then
            echo "sdkman_auto_answer=true" >> "$sdkman_config"
        fi
        if ! grep -q "sdkman_selfupdate_feature=false" "$sdkman_config"; then
            echo "sdkman_selfupdate_feature=false" >> "$sdkman_config"
        fi
        chown vagrant:vagrant "$sdkman_config"
    fi

    # 5. Install Java 25 Temurin via SDKMAN
    lib::log "Installing Java 25 Temurin..."
    sudo -u vagrant bash -c '
        export SDKMAN_DIR="$HOME/.sdkman"
        source "$SDKMAN_DIR/bin/sdkman-init.sh"
        sdk install java 25-tem
        sdk default java 25-tem
    '
    lib::success "Java 25 Temurin installed"

    # 6. Install JBang via SDKMAN
    lib::log "Installing JBang..."
    sudo -u vagrant bash -c '
        export SDKMAN_DIR="$HOME/.sdkman"
        source "$SDKMAN_DIR/bin/sdkman-init.sh"
        sdk install jbang
    '
    lib::success "JBang installed"

    # 7. Verify installations
    lib::subheader "Verifying installations"
    lib::verify_commands direnv

    sudo -u vagrant bash -c '
        export SDKMAN_DIR="$HOME/.sdkman"
        source "$SDKMAN_DIR/bin/sdkman-init.sh"
        sdk version
        java -version
        jbang version
    '

    lib::success "Development tools installation complete"
}

main "$@"
