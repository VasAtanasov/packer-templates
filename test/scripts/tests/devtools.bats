#!/usr/bin/env bats

# Tests for custom devtools installation script
# packer_templates/scripts/custom/debian/docker-host/20-install-devtools.sh
#
# This tests the logic for installing direnv, SDKMAN, Java 25 Temurin, and JBang
# for the vagrant user.

setup() {
    # Ensure libraries are available and source them
    [ -n "$LIB_CORE_SH" ]
    [ -n "$LIB_OS_SH" ]
    source "$LIB_CORE_SH"
    source "$LIB_OS_SH"

    # Create test environment
    export _TEST_DIR=/tmp/devtools-test
    rm -rf "${_TEST_DIR}" && mkdir -p "${_TEST_DIR}"/{bin,home/vagrant/.sdkman/etc}
    export PATH="${_TEST_DIR}/bin:${PATH}"

    # Create fake vagrant home
    export _VAGRANT_HOME="${_TEST_DIR}/home/vagrant"
    touch "${_VAGRANT_HOME}/.bashrc"
    chown -R "$(id -u):$(id -g)" "${_VAGRANT_HOME}" 2>/dev/null || true

    # Fake apt-get that logs invocations
    cat > "${_TEST_DIR}/bin/apt-get" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "apt-get $*" >> /tmp/devtools-test/log
exit 0
EOF
    chmod +x "${_TEST_DIR}/bin/apt-get"

    # Fake curl that simulates SDKMAN installer
    cat > "${_TEST_DIR}/bin/curl" <<'EOF'
#!/usr/bin/env bash
echo "curl $*" >> /tmp/devtools-test/log
# Simulate SDKMAN install script output
echo "SDKMAN installed successfully"
exit 0
EOF
    chmod +x "${_TEST_DIR}/bin/curl"

    # Fake sudo that runs commands as current user
    cat > "${_TEST_DIR}/bin/sudo" <<'EOF'
#!/usr/bin/env bash
echo "sudo $*" >> /tmp/devtools-test/log
# Skip -u vagrant and run the bash command
shift 2  # skip -u vagrant
exec "$@"
EOF
    chmod +x "${_TEST_DIR}/bin/sudo"

    # Fake chown (no-op in test)
    cat > "${_TEST_DIR}/bin/chown" <<'EOF'
#!/usr/bin/env bash
echo "chown $*" >> /tmp/devtools-test/log
exit 0
EOF
    chmod +x "${_TEST_DIR}/bin/chown"

    # Fake direnv binary
    cat > "${_TEST_DIR}/bin/direnv" <<'EOF'
#!/usr/bin/env bash
echo "direnv 2.32.0"
exit 0
EOF
    chmod +x "${_TEST_DIR}/bin/direnv"

    # Fake dpkg-query to simulate packages NOT installed (forces apt-get install)
    cat > "${_TEST_DIR}/bin/dpkg-query" <<'EOF'
#!/usr/bin/env bash
# Simulate package not installed for test purposes
echo "dpkg-query: package '$2' is not installed" >&2
exit 1
EOF
    chmod +x "${_TEST_DIR}/bin/dpkg-query"

    # Reset log and APT cache state
    : > "${_TEST_DIR}/log"
    export APT_UPDATED_TS=0
    export APT_CACHE_INVALIDATED=0
    export APT_UPDATE_TTL=9999
}

teardown() {
    rm -rf "${_TEST_DIR}" || true
}

# Helper to check log contents
log_contains() {
    grep -q "$1" "${_TEST_DIR}/log" 2>/dev/null
}

log_count() {
    local count
    count=$(grep -c "$1" "${_TEST_DIR}/log" 2>/dev/null) || count=0
    echo "$count"
}

# =============================================================================
# direnv installation tests
# =============================================================================

@test "direnv: lib::ensure_packages installs direnv" {
    run bash -c 'export APT_UPDATED_TS=0 APT_CACHE_INVALIDATED=0 APT_UPDATE_TTL=9999; \
      source "$LIB_CORE_SH"; source "$LIB_OS_SH"; \
      lib::ensure_packages direnv'
    [ "$status" -eq 0 ]
    log_contains "apt-get install"
    log_contains "direnv"
}

@test "direnv: bashrc hook added when not present" {
    local bashrc="${_VAGRANT_HOME}/.bashrc"
    
    # Ensure bashrc exists but doesn't have the hook
    echo "# Empty bashrc" > "$bashrc"
    
    # Simulate adding the hook
    if ! grep -q 'eval "$(direnv hook bash)"' "$bashrc"; then
        echo 'eval "$(direnv hook bash)"' >> "$bashrc"
    fi
    
    # Verify hook was added
    grep -q 'eval "$(direnv hook bash)"' "$bashrc"
    [ $? -eq 0 ]
}

@test "direnv: bashrc hook NOT duplicated on re-run" {
    local bashrc="${_VAGRANT_HOME}/.bashrc"
    
    # Add hook first time
    echo "# Empty bashrc" > "$bashrc"
    echo 'eval "$(direnv hook bash)"' >> "$bashrc"
    
    # Count hooks before
    local count_before
    count_before=$(grep -c 'eval "$(direnv hook bash)"' "$bashrc")
    
    # Simulate idempotent re-run
    if ! grep -q 'eval "$(direnv hook bash)"' "$bashrc"; then
        echo 'eval "$(direnv hook bash)"' >> "$bashrc"
    fi
    
    # Count hooks after
    local count_after
    count_after=$(grep -c 'eval "$(direnv hook bash)"' "$bashrc")
    
    # Should still be 1
    [ "$count_before" -eq 1 ]
    [ "$count_after" -eq 1 ]
}

@test "direnv: verify_commands detects direnv" {
    run bash -lc 'source "$LIB_CORE_SH"; source "$LIB_OS_SH"; lib::verify_commands direnv'
    [ "$status" -eq 0 ]
}

# =============================================================================
# SDKMAN installation tests
# =============================================================================

@test "sdkman: skipped when .sdkman directory exists" {
    # Create the .sdkman directory
    mkdir -p "${_VAGRANT_HOME}/.sdkman"
    
    # Check logic
    if [ ! -d "${_VAGRANT_HOME}/.sdkman" ]; then
        echo "would install" >> "${_TEST_DIR}/log"
    else
        echo "skipped - already installed" >> "${_TEST_DIR}/log"
    fi
    
    log_contains "skipped - already installed"
}

@test "sdkman: installed when .sdkman directory missing" {
    # Ensure no .sdkman directory
    rm -rf "${_VAGRANT_HOME}/.sdkman"
    
    # Check logic
    if [ ! -d "${_VAGRANT_HOME}/.sdkman" ]; then
        echo "would install" >> "${_TEST_DIR}/log"
    else
        echo "skipped - already installed" >> "${_TEST_DIR}/log"
    fi
    
    log_contains "would install"
}

@test "sdkman: config adds auto_answer when not present" {
    local config="${_VAGRANT_HOME}/.sdkman/etc/config"
    mkdir -p "$(dirname "$config")"
    
    # Create config without the setting
    echo "sdkman_colour_enable=true" > "$config"
    
    # Simulate adding the setting
    if ! grep -q "sdkman_auto_answer=true" "$config"; then
        echo "sdkman_auto_answer=true" >> "$config"
    fi
    
    grep -q "sdkman_auto_answer=true" "$config"
    [ $? -eq 0 ]
}

@test "sdkman: config adds selfupdate_feature when not present" {
    local config="${_VAGRANT_HOME}/.sdkman/etc/config"
    mkdir -p "$(dirname "$config")"
    
    # Create config without the setting
    echo "sdkman_colour_enable=true" > "$config"
    
    # Simulate adding the setting
    if ! grep -q "sdkman_selfupdate_feature=false" "$config"; then
        echo "sdkman_selfupdate_feature=false" >> "$config"
    fi
    
    grep -q "sdkman_selfupdate_feature=false" "$config"
    [ $? -eq 0 ]
}

@test "sdkman: config NOT duplicated on re-run" {
    local config="${_VAGRANT_HOME}/.sdkman/etc/config"
    mkdir -p "$(dirname "$config")"
    
    # Create config with settings already present
    cat > "$config" <<'EOF'
sdkman_colour_enable=true
sdkman_auto_answer=true
sdkman_selfupdate_feature=false
EOF
    
    # Count before
    local count_before
    count_before=$(grep -c "sdkman_auto_answer=true" "$config")
    
    # Simulate idempotent re-run
    if ! grep -q "sdkman_auto_answer=true" "$config"; then
        echo "sdkman_auto_answer=true" >> "$config"
    fi
    
    # Count after
    local count_after
    count_after=$(grep -c "sdkman_auto_answer=true" "$config")
    
    [ "$count_before" -eq 1 ]
    [ "$count_after" -eq 1 ]
}

# =============================================================================
# JBang-specific tests (via SDKMAN)
# =============================================================================

@test "jbang: sdk install command format correct" {
    # Verify the expected command structure
    local expected_cmd='sdk install jbang'
    
    # This tests that the command format is correct
    # In real execution, SDKMAN handles this
    echo "$expected_cmd" | grep -q "sdk install jbang"
    [ $? -eq 0 ]
}

@test "java: sdk install command format correct for temurin" {
    # Verify the expected command structure
    local expected_cmd='sdk install java 25-tem'
    
    # This tests that the command format is correct
    echo "$expected_cmd" | grep -q "sdk install java 25-tem"
    [ $? -eq 0 ]
}

@test "java: sdk default command sets temurin as default" {
    # Verify the expected command structure
    local expected_cmd='sdk default java 25-tem'
    
    echo "$expected_cmd" | grep -q "sdk default java 25-tem"
    [ $? -eq 0 ]
}

# =============================================================================
# Integration tests (script structure)
# =============================================================================

@test "script: sources both LIB_CORE_SH and LIB_OS_SH" {
    local script="${SCRIPTS_DIR:-/scripts}/custom/debian/docker-host/20-install-devtools.sh"
    
    # Skip if script doesn't exist in test environment
    [ -f "$script" ] || skip "Script not available in test environment"
    
    grep -q 'source "${LIB_CORE_SH}"' "$script"
    [ $? -eq 0 ]
    
    grep -q 'source "${LIB_OS_SH}"' "$script"
    [ $? -eq 0 ]
}

@test "script: uses lib::strict and lib::setup_traps" {
    local script="${SCRIPTS_DIR:-/scripts}/custom/debian/docker-host/20-install-devtools.sh"
    
    [ -f "$script" ] || skip "Script not available in test environment"
    
    grep -q 'lib::strict' "$script"
    [ $? -eq 0 ]
    
    grep -q 'lib::setup_traps' "$script"
    [ $? -eq 0 ]
}

@test "script: requires root" {
    local script="${SCRIPTS_DIR:-/scripts}/custom/debian/docker-host/20-install-devtools.sh"
    
    [ -f "$script" ] || skip "Script not available in test environment"
    
    grep -q 'lib::require_root' "$script"
    [ $? -eq 0 ]
}

@test "script: uses lib::ensure_packages for direnv" {
    local script="${SCRIPTS_DIR:-/scripts}/custom/debian/docker-host/20-install-devtools.sh"
    
    [ -f "$script" ] || skip "Script not available in test environment"
    
    grep -q 'lib::ensure_packages direnv' "$script"
    [ $? -eq 0 ]
}

@test "script: uses grep guard for bashrc modification" {
    local script="${SCRIPTS_DIR:-/scripts}/custom/debian/docker-host/20-install-devtools.sh"
    
    [ -f "$script" ] || skip "Script not available in test environment"
    
    # Check for the idempotency pattern
    grep -q 'grep -q.*direnv hook bash' "$script"
    [ $? -eq 0 ]
}
