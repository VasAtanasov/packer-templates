// =============================================================================
// Consolidated Build Configuration
// =============================================================================
// Provider-agnostic build orchestration and provisioning
// Dynamically adapts based on enabled sources and provider capabilities
// =============================================================================

build {
  // Use all enabled sources (explicit list, or derived from primary_source)
  sources = local.enabled_sources

  // ===========================================================================
  // File Upload: Scripts Tree
  // ===========================================================================
  // Upload entire scripts directory once to temporary location
  provisioner "file" {
    source      = "${path.root}/scripts"
    destination = "/tmp/packer-scripts"
    except      = local.provisioner_except
  }

  // ===========================================================================
  // Install Scripts to Persistent Location
  // ===========================================================================
  // Copy scripts to /usr/local/lib/scripts/ (survives reboots and /tmp cleanup)
  provisioner "shell" {
    inline = [
      "install -d -m 0755 /usr/local/lib/scripts",
      "cp -r /tmp/packer-scripts/* /usr/local/lib/scripts/",
      // Normalize CRLF to LF for all shell scripts to avoid execution issues
      "find /usr/local/lib/scripts -type f -name '*.sh' -exec sed -i 's/\\r$//' {} +",
      "chmod -R 0755 /usr/local/lib/scripts",
      "find /usr/local/lib/scripts -type f -name '*.sh' -exec chmod 0755 {} \\;",
      "chown -R root:root /usr/local/lib/scripts"
    ]
    execute_command = local.execute_command
    except          = local.provisioner_except
  }

  // ===========================================================================
  // System Updates and Preparation
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
    except            = local.provisioner_except
  }

  provisioner "shell" {
    inline = [
      "echo 'Waiting after reboot'"
    ]
    pause_after = "10s"
    except      = local.provisioner_except
  }

  // ===========================================================================
  // Base Configuration and Provider Integration
  // ===========================================================================
  // Runs common scripts (vagrant, sshd) + provider-specific guest tools
  // Guest tools script uses PACKER_BUILDER_TYPE to detect provider at runtime
  provisioner "shell" {
    scripts = local.provider_provisioning_scripts
    environment_vars = [
      "LIB_DIR=/usr/local/lib/scripts",
      "LIB_CORE_SH=${local.lib_core_sh}",
      "LIB_OS_SH=${local.lib_os_sh[var.os_name]}",
      "HOME_DIR=/home/vagrant",
      "VBOX_GUEST_ADDITIONS_MODE=${var.vbox_guest_additions_mode}",
      "VMWARE_TOOLS_MODE=${var.vmware_tools_mode}",
    ]
    execute_command   = local.execute_command
    expect_disconnect = true
    pause_before      = "10s"
    except            = local.provisioner_except
  }

  provisioner "shell" {
    inline = [
      "echo 'Waiting after provider tools installation'"
    ]
    pause_after = "10s"
    except      = local.provisioner_except
  }

  // ===========================================================================
  // OS Configuration, Variants, and Cleanup (Provider-Agnostic)
  // ===========================================================================
  provisioner "shell" {
    scripts = local.os_and_variant_scripts
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
    execute_command   = local.execute_command
    expect_disconnect = true
    pause_before      = "10s"
    except            = local.provisioner_except
  }

  // ===========================================================================
  // Final Minimization
  // ===========================================================================
  provisioner "shell" {
    scripts = ["${path.root}/scripts/_common/minimize.sh"]
    environment_vars = [
      "LIB_DIR=/usr/local/lib/scripts",
      "LIB_CORE_SH=${local.lib_core_sh}",
      "LIB_OS_SH=${local.lib_os_sh[var.os_name]}",
    ]
    execute_command   = local.execute_command
    expect_disconnect = true
    pause_after       = "10s"
    except            = local.provisioner_except
  }

  // ===========================================================================
  // Final Cleanup: Remove Build Scripts
  // ===========================================================================
  provisioner "shell" {
    inline = [
      "rm -rf /usr/local/lib/scripts"
    ]
    execute_command = local.execute_command
    except          = local.provisioner_except
  }

  // ===========================================================================
  // Post-Processor: Vagrant Box
  // ===========================================================================
  post-processor "vagrant" {
    compression_level    = 9
    output               = "${path.root}/../builds/build_complete/${local.box_name}.{{ .Provider }}.box"
    vagrantfile_template = null
    keep_input_artifact  = var.keep_input_artifact
  }
}
