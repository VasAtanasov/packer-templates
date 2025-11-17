#!/usr/bin/env bash
# =============================================================================
# Provider Guest Tools Entry Point
# =============================================================================
# Detects the provider at runtime using PACKER_BUILDER_TYPE and installs
# the appropriate guest tools (VirtualBox Guest Additions, VMware Tools, etc.)
# =============================================================================

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

lib::header "Provider Guest Tools Installation"

# Packer automatically sets PACKER_BUILDER_TYPE during builds:
# - virtualbox-iso, virtualbox-ovf
# - vmware-iso
# - qemu
# - etc.

lib::log "Detected builder type: ${PACKER_BUILDER_TYPE:-unknown}"

case "${PACKER_BUILDER_TYPE}" in
  virtualbox-iso|virtualbox-ovf)
    lib::log "Installing VirtualBox Guest Additions..."

    # Check if guest additions should be installed
    if [[ "${VBOX_GUEST_ADDITIONS_MODE:-upload}" == "disable" ]]; then
      lib::warn "VirtualBox Guest Additions disabled via VBOX_GUEST_ADDITIONS_MODE"
    else
      bash "${LIB_DIR}/providers/virtualbox/install_guest_additions.sh"
    fi
    ;;

  vmware-iso)
    lib::log "Installing VMware Tools..."

    # Check if VMware Tools should be installed
    if [[ "${VMWARE_TOOLS_MODE:-auto}" == "disable" ]]; then
      lib::warn "VMware Tools disabled via VMWARE_TOOLS_MODE"
    else
      bash "${LIB_DIR}/providers/vmware/install_vmware_tools.sh"
    fi
    ;;

  qemu)
    lib::log "Installing QEMU Guest Agent..."
    bash "${LIB_DIR}/providers/qemu/install_qemu_guest_agent.sh"
    ;;

  *)
    lib::warn "Unknown or unsupported builder type '${PACKER_BUILDER_TYPE}'"
    lib::warn "Skipping guest tools installation"
    ;;
esac

lib::success "Provider guest tools installation complete"
