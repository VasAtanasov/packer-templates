#!/usr/bin/env bash
set -o pipefail

# RHEL-family base systemd adjustments (placeholder)
# Using shared libraries for consistency; currently no special actions needed.

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

main() {
  lib::header "RHEL systemd baseline configuration"

  # Ensure default target is multi-user (usually default already)
  if systemctl get-default | grep -qE 'graphical\.target'; then
    lib::log "Switching default target to multi-user.target"
    systemctl set-default multi-user.target || true
  else
    lib::log "multi-user.target already default"
  fi

  lib::success "RHEL systemd baseline complete"
}

main "$@"

