#!/usr/bin/env bash
# =============================================================================
# Custom Scripts Runner
# =============================================================================
# Discovers and executes custom scripts from /usr/local/lib/scripts/custom/
# following the precedence: variant → provider → OS family
#
# Pattern: Only files matching ??-*.sh (two-digit prefix + hyphen)
# Execution order: Sorted alphabetically within each scope
# =============================================================================

set -euo pipefail

# Source libraries
source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::setup_traps
lib::require_root

# Determine OS family from LIB_OS_SH path
os_family=$(basename "${LIB_OS_SH}" | sed 's/lib-\(.*\)\.sh/\1/')

lib::header "Running Custom Scripts"
lib::log "OS Family: ${os_family}"
lib::log "Variant: ${VARIANT:-base}"
lib::log "Provider: ${PACKER_BUILDER_TYPE:-unknown}"

# Extract provider family from PACKER_BUILDER_TYPE (e.g., virtualbox-iso → virtualbox)
provider_family=""
if [[ -n "${PACKER_BUILDER_TYPE:-}" ]]; then
  case "${PACKER_BUILDER_TYPE}" in
    virtualbox-*) provider_family="virtualbox" ;;
    vmware-*) provider_family="vmware" ;;
    qemu) provider_family="qemu" ;;
    *) provider_family="${PACKER_BUILDER_TYPE}" ;;
  esac
fi

# Define search paths with precedence (variant → provider → OS family)
search_paths=()

# Variant-specific (highest precedence)
if [[ -n "${VARIANT:-}" && "${VARIANT}" != "base" ]]; then
  variant_path="${LIB_DIR}/custom/${os_family}/${VARIANT}"
  if [[ -d "${variant_path}" ]]; then
    search_paths+=("${variant_path}")
  fi
fi

# Provider-specific (medium precedence)
if [[ -n "${provider_family}" ]]; then
  provider_path="${LIB_DIR}/custom/${os_family}/${provider_family}"
  if [[ -d "${provider_path}" ]]; then
    search_paths+=("${provider_path}")
  fi
fi

# OS family (lowest precedence)
os_path="${LIB_DIR}/custom/${os_family}"
if [[ -d "${os_path}" ]]; then
  search_paths+=("${os_path}")
fi

# Collect all matching scripts (with deduplication)
declare -A seen_scripts
all_scripts=()

for path in "${search_paths[@]}"; do
  lib::log "Scanning: ${path}"
  
  # Find all ??-*.sh files (two-digit prefix pattern)
  while IFS= read -r -d '' script; do
    script_name=$(basename "${script}")
    
    # Skip if already seen (precedence: earlier paths win)
    if [[ -n "${seen_scripts[${script_name}]:-}" ]]; then
      lib::debug "Skipping duplicate: ${script_name} (already found in ${seen_scripts[${script_name}]})"
      continue
    fi
    
    seen_scripts["${script_name}"]="${path}"
    all_scripts+=("${script}")
    
  done < <(find "${path}" -maxdepth 1 -type f -name '[0-9][0-9]-*.sh' -print0 2>/dev/null | sort -z)
done

# Execute scripts in sorted order
if [[ ${#all_scripts[@]} -eq 0 ]]; then
  lib::log "No custom scripts found"
  lib::success "Custom scripts execution complete (0 scripts)"
  exit 0
fi

lib::log "Found ${#all_scripts[@]} custom script(s)"
lib::hr

executed=0
failed=0

for script in "${all_scripts[@]}"; do
  script_name=$(basename "${script}")
  script_dir=$(dirname "${script}")
  
  lib::subheader "Executing: ${script_name}"
  lib::kv "Path" "${script}"
  lib::kv "Source" "$(basename "${script_dir}")"
  
  if [[ ! -x "${script}" ]]; then
    lib::warn "Script not executable, fixing permissions"
    chmod +x "${script}"
  fi
  
  # Execute script with error handling
  if bash -euxo pipefail "${script}"; then
    executed=$((executed + 1))
    lib::success "✓ ${script_name} completed successfully"
  else
    exit_code=$?
    failed=$((failed + 1))
    lib::error "✗ ${script_name} failed with exit code ${exit_code}"
    lib::error "Aborting custom scripts execution"
    exit "${exit_code}"
  fi
  
  lib::hr
done

# Summary
lib::header "Custom Scripts Summary"
lib::kv "Total Found" "${#all_scripts[@]}"
lib::kv "Executed" "${executed}"
lib::kv "Failed" "${failed}"

if [[ ${failed} -eq 0 ]]; then
  lib::success "All custom scripts executed successfully"
else
  lib::error "Some custom scripts failed"
  exit 1
fi
