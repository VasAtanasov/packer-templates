#!/usr/bin/env bash
set -o pipefail

# Configure sudoers for vagrant user on RHEL-family systems

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

main() {
  lib::header "Configuring sudoers for vagrant"

  # Ensure sudo package is present
  lib::ensure_package sudo

  # Ensure secure_path contains standard dirs if present (idempotent)
  if [ -f /etc/sudoers ]; then
    if ! grep -q '^Defaults\s\+secure_path=' /etc/sudoers; then
      lib::log "Adding secure_path to /etc/sudoers"
      sed -i -e '/Defaults\s\+env_reset/a Defaults\tsecure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' /etc/sudoers
    else
      lib::log "secure_path already present in /etc/sudoers"
    fi
  fi

  # Canonical sudoers file for vagrant user
  local sudoers_file="/etc/sudoers.d/vagrant"
  printf '%s\n' 'vagrant ALL=(ALL) NOPASSWD:ALL' >"${sudoers_file}"
  chmod 0440 "${sudoers_file}"
  chown root:root "${sudoers_file}"

  # Avoid requiretty for vagrant (harmless if default is off)
  local tty_file="/etc/sudoers.d/vagrant-tty"
  printf '%s\n' 'Defaults:vagrant !requiretty' >"${tty_file}"
  chmod 0440 "${tty_file}"
  chown root:root "${tty_file}"

  lib::success "sudoers configured for vagrant"
}

main "$@"

