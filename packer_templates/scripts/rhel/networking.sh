#!/usr/bin/env bash
set -o pipefail

# Basic networking adjustments for RHEL-family systems

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

main() {
  lib::header "Configuring networking (RHEL family)"

  # Ensure NetworkManager is enabled and running (default on Alma/RHEL)
  if systemctl list-unit-files | grep -q '^NetworkManager\.service'; then
    lib::ensure_service_enabled NetworkManager
    lib::ensure_service_running NetworkManager
  fi

  # Keep default predictable interface names; do not force eth0
  lib::log "Leaving predictable interface names as-is (no GRUB changes)"

  lib::success "Networking baseline complete"
}

main "$@"

