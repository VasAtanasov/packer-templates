#!/usr/bin/env bash

# Pre-pulls container images for a list of CNI plugins to speed up cluster bootstrapping.
# This script is designed to be configurable via environment variables for production use.

set -o pipefail

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

# --- Main Logic ---

main() {
  lib::header "Pre-pulling CNI Images"

  # ---------------------------------------------------------------------------
  # Configuration via Environment Variables
  # ---------------------------------------------------------------------------
  # CNI_PLUGINS:          Comma-separated list of CNI plugins (e.g., "calico,flannel").
  # CNI_REGISTRY_MIRROR:  Optional registry mirror URL (e.g., "myregistry.com").
  # CNI_CALICO_VERSION:   Version for Calico images. Defaults to "v3.27.3".
  # CNI_FLANNEL_VERSION:  Version for the main Flannel image. Defaults to "v0.25.1".
  # CNI_FLANNEL_PLUGIN_VERSION: Version for the Flannel CNI plugin. Defaults to "v1.4.0-flannel1".
  # ---------------------------------------------------------------------------
  local cni_plugins_str="${CNI_PLUGINS:-calico}"
  local registry_mirror="${CNI_REGISTRY_MIRROR:-}"

  if [ -z "$cni_plugins_str" ] || [ "$cni_plugins_str" = "none" ]; then
    lib::log "No CNI plugins specified. Skipping CNI image pre-pulling."
    return 0
  fi

  if ! command -v crictl >/dev/null 2>&1; then
    lib::error "crictl command not found. Cannot pre-pull CNI images."
    lib::error "Please ensure 'cri-tools' package is installed."
    return 1
  fi

  if [ -n "$registry_mirror" ]; then
    lib::log "Using registry mirror: ${registry_mirror}"
  fi

  # Convert comma-separated string to an array to safely handle iteration
  local cni_plugins=()
  IFS=',' read -r -a cni_plugins <<< "$cni_plugins_str"

  # --- Loop and Pull ---

  for plugin in "${cni_plugins[@]}"; do
    local images_to_pull=()
    local cni_name=""

    lib::subheader "Processing CNI: ${plugin}"

    case "$plugin" in
      calico)
        cni_name="Calico"
        local calico_version="${CNI_CALICO_VERSION:-v3.27.3}"
        local calico_registry="${registry_mirror:-docker.io}"

        images_to_pull=(
          "${calico_registry}/calico/cni:${calico_version}"
          "${calico_registry}/calico/node:${calico_version}"
          "${calico_registry}/calico/kube-controllers:${calico_version}"
        )
        ;;

      flannel)
        cni_name="Flannel"
        local flannel_version="${CNI_FLANNEL_VERSION:-v0.25.1}"
        local flannel_plugin_version="${CNI_FLANNEL_PLUGIN_VERSION:-v1.4.0-flannel1}"
        local flannel_registry="${registry_mirror:-docker.io}"

        images_to_pull=(
          "${flannel_registry}/flannel/flannel-cni-plugin:${flannel_plugin_version}"
          "${flannel_registry}/flannel/flannel:${flannel_version}"
        )
        ;;

      cilium)
        lib::warn "CNI plugin 'cilium' is not yet implemented in this script. Skipping."
        continue
        ;;

      none|'')
        continue
        ;;

      *)
        lib::warn "Unknown CNI plugin '${plugin}'. Skipping."
        continue
        ;;
    esac

    # --- Image Pulling ---
    local all_successful=true
    for image in "${images_to_pull[@]}"; do
      lib::log "Pulling ${image}..."
      if crictl pull "${image}"; then
        lib::success "Successfully pulled ${image}"
      else
        lib::warn "Failed to pull ${image}. The node will attempt to pull it at runtime."
        all_successful=false
      fi
    done

    if [ "$all_successful" = true ]; then
      lib::success "All CNI images for ${cni_name} pulled successfully."
    else
      lib::warn "Could not pull all CNI images for ${cni_name}."
    fi

  done

  lib::hr
  lib::success "CNI image pre-pulling process complete."
}

main "$@"