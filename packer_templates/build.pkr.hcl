// =============================================================================
// Consolidated Build Configuration
// =============================================================================
// Provider-agnostic build orchestration and provisioning
// Dynamically adapts based on enabled sources and provider capabilities
// =============================================================================

build {
  // Use all enabled sources from variable
  sources = var.sources_enabled

  // ===========================================================================
  // File Upload: Scripts Tree
  // ===========================================================================
  // Upload entire scripts directory once to temporary location
  provisioner "file" {
    source      = "${path.root}/scripts"
    destination = "/tmp/packer-scripts"
  }

  // ===========================================================================
  // Install Scripts to Persistent Location
  // ===========================================================================
  // Copy scripts to /usr/local/lib/scripts/ (survives reboots and /tmp cleanup)
  provisioner "shell" {
    inline = [
      "install -d -m 0755 /usr/local/lib/scripts",
      "cp -r /tmp/packer-scripts /usr/local/lib/scripts",
      "chmod -R 0755 /usr/local/lib/scripts",
      "find /usr/local/lib/scripts -type f -name '*.sh' -exec chmod 0755 {} \\;",
      "chown -R root:root /usr/local/lib/scripts"
    ]
    execute_command = local.execute_command
  }

  // ===========================================================================
  // Phase 1: System Preparation
  // ===========================================================================
  // Update packages and disable automatic updates (may reboot)
  provisioner "shell" {
    scripts = ["${path.root}/scripts/_common/update_packages.sh"]
    environment_vars = [
      "LIB_DIR=/usr/local/lib/scripts",
      "LIB_CORE_SH=${local.lib_core_sh}",
      "LIB_OS_SH=${local.lib_os_sh[var.os_name]}",
    ]
    execute_command   = local.execute_command
    expect_disconnect = true // May reboot
    pause_before      = "10s"
    valid_exit_codes  = [0, 143]
  }

  provisioner "shell" {
    inline = [
      "echo 'Waiting after reboot'"
    ]
    pause_after = "10s"
  }

  // ===========================================================================
  // Phase 2a: Base OS Configuration
  // ===========================================================================
  provisioner "shell" {
    scripts = local.common_scripts
    environment_vars = [
      "LIB_DIR=/usr/local/lib/scripts",
      "LIB_CORE_SH=${local.lib_core_sh}",
      "LIB_OS_SH=${local.lib_os_sh[var.os_name]}",
    ]
    execute_command   = local.execute_command
    expect_disconnect = true
    pause_before      = "10s"
  }

  provisioner "shell" {
    inline = [
      "echo 'Waiting after reboot'"
    ]
    pause_after = "10s"
  }

  // ===========================================================================
  // Phase 2b: Provider Integration - Guest Tools (Provider-Agnostic)
  // ===========================================================================
  provisioner "shell" {
    // Only run if at least one provider needs guest tools
    // Automatically detects and installs tools for all enabled providers
    only = length(local.providers_with_tools) > 0 ? var.sources_enabled : []

    scripts = local.guest_tools_scripts
    environment_vars = [
      "LIB_DIR=/usr/local/lib/scripts",
      "LIB_CORE_SH=${local.lib_core_sh}",
      "LIB_OS_SH=${local.lib_os_sh[var.os_name]}",
      "HOME_DIR=/home/vagrant",
    ]
    execute_command   = local.execute_command
    expect_disconnect = true // May reboot after guest tools installation
    pause_before      = "10s"
  }

  provisioner "shell" {
    only = length(local.providers_with_tools) > 0 ? var.sources_enabled : []

    inline = [
      "echo 'Waiting after provider guest tools installation'"
    ]
    pause_after = "10s"
  }

  // ===========================================================================
  // Phase 2c: OS Specific Configuration
  // ===========================================================================
  provisioner "shell" {
    scripts = local.os_scripts[local.os_family]
    environment_vars = [
      "LIB_DIR=/usr/local/lib/scripts",
      "LIB_CORE_SH=${local.lib_core_sh}",
      "LIB_OS_SH=${local.lib_os_sh[var.os_name]}",
    ]
    execute_command   = local.execute_command
    expect_disconnect = true
    pause_before      = "10s"
  }

  // ===========================================================================
  // Phase 2d: Variant-specific Provisioning
  // ===========================================================================
  /*
  provisioner "shell" {
    // Only run if variant is not "base"
    // Note: This is provider-agnostic - runs for all enabled sources
    only = var.variant != "base" ? var.sources_enabled : []

    inline = length(local.selected_variant_scripts) > 0 ? [
      for script in local.selected_variant_scripts :
      "bash /usr/local/lib/scripts/${script}"
    ] : ["echo 'No variant scripts to run (base variant)'"]

    environment_vars = concat(
      [
        "LIB_DIR=/usr/local/lib/scripts",
        "LIB_CORE_SH=${local.lib_core_sh}",
        "LIB_OS_SH=${local.lib_os_sh[var.os_name]}",
        "VARIANT=${var.variant}",
      ],
      # Add K8s-specific vars only for k8s-node variant
      var.variant == "k8s-node" ? [
        "K8S_VERSION=${var.kubernetes_version}",
        "CONTAINER_RUNTIME=${var.container_runtime}",
        "CRIO_VERSION=${var.crio_version}",
      ] : []
    )

    execute_command = local.execute_command
  }
  */

  // ===========================================================================
  // Phase 3a: Cleanup
  // ===========================================================================
  provisioner "shell" {
    scripts = local.cleanup_scripts[local.os_family]
    environment_vars = [
      "LIB_DIR=/usr/local/lib/scripts",
      "LIB_CORE_SH=${local.lib_core_sh}",
      "LIB_OS_SH=${local.lib_os_sh[var.os_name]}",
    ]
    expect_disconnect = true
    pause_after       = "10s"
    execute_command   = local.execute_command
  }

  // ===========================================================================
  // Phase 3b: Minimize
  // ===========================================================================
  provisioner "shell" {
    scripts = ["${path.root}/scripts/_common/minimize.sh"]
    environment_vars = [
      "LIB_DIR=/usr/local/lib/scripts",
      "LIB_CORE_SH=${local.lib_core_sh}",
      "LIB_OS_SH=${local.lib_os_sh[var.os_name]}",
    ]
    expect_disconnect = true
    pause_after       = "10s"
    execute_command   = local.execute_command
  }

  // ===========================================================================
  // Final Cleanup: Remove Build Scripts
  // ===========================================================================
  provisioner "shell" {
    inline = [
      "rm -rf /usr/local/lib/scripts"
    ]
    execute_command = local.execute_command
  }

  // ===========================================================================
  // Post-Processor: Vagrant Box
  // ===========================================================================
  post-processor "vagrant" {
    compression_level    = 9
    output               = "${path.root}/../builds/build_complete/${local.box_name}.virtualbox.box"
    vagrantfile_template = null
  }
}
