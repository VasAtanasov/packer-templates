// =============================================================================
// Debian VirtualBox Build Configuration
// =============================================================================
// Build orchestration and provisioning for Debian on VirtualBox
// =============================================================================

build {
  sources = [
    "source.virtualbox-iso.debian",
  ]

  // Upload all helper scripts once to /tmp, then install to persistent location
  provisioner "file" {
    source      = "${path.root}/../../scripts"
    destination = "/tmp/packer-scripts"
  }

  // Install scripts to persistent location (survives reboots and /tmp cleanups)
  provisioner "shell" {
    inline = [
      "install -d -m 0755 /usr/local/lib/k8s",
      "cp -r /tmp/packer-scripts /usr/local/lib/k8s/scripts",
      "chmod -R 0755 /usr/local/lib/k8s/scripts",
      "find /usr/local/lib/k8s/scripts -type f -name '*.sh' -exec chmod 0755 {} \\;",
      "chown -R root:root /usr/local/lib/k8s"
    ]
    execute_command = local.execute_command
  }

  // Phase 1: System prep (updates, disable unattended upgrades)
  provisioner "shell" {
    inline = [
      "bash /usr/local/lib/k8s/scripts/_common/update_packages.sh",
    ]
    environment_vars = [
      "LIB_DIR=/usr/local/lib/k8s",
      "LIB_CORE_SH=${local.lib_core_sh}",
      "LIB_OS_SH=${local.lib_os_sh[var.os_name]}",
    ]
    execute_command   = local.execute_command
    expect_disconnect = true // script may reboot
  }

  // Phase 2a: Provider dependencies (kernel headers, build tools for VirtualBox)
  // Skip when Guest Additions are disabled by template var
  provisioner "shell" {
    only = var.vbox_guest_additions_mode != "disable" ? ["virtualbox-iso.debian"] : []
    inline = [
      "bash /usr/local/lib/k8s/scripts/providers/virtualbox/install_dependencies.sh",
    ]
    environment_vars = [
      "LIB_DIR=/usr/local/lib/k8s",
      "LIB_CORE_SH=${local.lib_core_sh}",
      "LIB_OS_SH=${local.lib_os_sh[var.os_name]}",
    ]
    execute_command   = local.execute_command
    expect_disconnect = true // may reboot if kernel packages installed
  }

  // Phase 2b: Provider integration (Guest Additions)
  // Skip when Guest Additions are disabled by template var
  provisioner "shell" {
    only = var.vbox_guest_additions_mode != "disable" ? ["virtualbox-iso.debian"] : []
    inline = [
      "bash /usr/local/lib/k8s/scripts/providers/virtualbox/guest_additions.sh",
    ]
    environment_vars = [
      "LIB_DIR=/usr/local/lib/k8s",
      "LIB_CORE_SH=${local.lib_core_sh}",
      "LIB_OS_SH=${local.lib_os_sh[var.os_name]}",
      "HOME_DIR=/home/vagrant",
    ]
    execute_command   = local.execute_command
    expect_disconnect = true // may reboot after installation
  }

  // Phase 2c: Base config for Vagrant + Debian bits
  provisioner "shell" {
    inline = [
      "bash /usr/local/lib/k8s/scripts/_common/sshd.sh",
      "bash /usr/local/lib/k8s/scripts/_common/vagrant.sh",
      "bash /usr/local/lib/k8s/scripts/debian/systemd.sh",
      "bash /usr/local/lib/k8s/scripts/debian/sudoers.sh",
      "bash /usr/local/lib/k8s/scripts/debian/networking.sh",
    ]
    environment_vars = [
      "LIB_DIR=/usr/local/lib/k8s",
      "LIB_CORE_SH=${local.lib_core_sh}",
      "LIB_OS_SH=${local.lib_os_sh[var.os_name]}",
    ]
    execute_command = local.execute_command
  }

  // Phase 2d: Variant-specific provisioning (dynamic based on variant variable)
  provisioner "shell" {
    // Only run if variant is not "base" (skip for base boxes)
    only = var.variant != "base" ? ["virtualbox-iso.debian"] : []

    // Dynamically build script list based on selected variant
    // If no scripts (base variant), use a harmless no-op to keep Packer validation happy
    inline = length(local.selected_variant_scripts) > 0 ? [
      for script in local.selected_variant_scripts :
      "bash /usr/local/lib/k8s/scripts/${script}"
    ] : ["echo 'No variant scripts to run (base variant)'"]

    environment_vars = concat(
      [
        "LIB_DIR=/usr/local/lib/k8s",
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

  // Phase 3a: Cleanup
  provisioner "shell" {
    inline = [
      "bash /usr/local/lib/k8s/scripts/debian/cleanup.sh",
    ]
    environment_vars = [
      "LIB_DIR=/usr/local/lib/k8s",
      "LIB_CORE_SH=${local.lib_core_sh}",
      "LIB_OS_SH=${local.lib_os_sh[var.os_name]}",
    ]
    execute_command = local.execute_command
  }

  // Phase 3b: Minimize
  provisioner "shell" {
    inline = [
      "bash /usr/local/lib/k8s/scripts/_common/minimize.sh",
    ]
    environment_vars = [
      "LIB_DIR=/usr/local/lib/k8s",
      "LIB_CORE_SH=${local.lib_core_sh}",
      "LIB_OS_SH=${local.lib_os_sh[var.os_name]}",
    ]
    execute_command = local.execute_command
  }

  // Final cleanup: remove all build-only scripts and libraries
  provisioner "shell" {
    inline = [
      "rm -rf /usr/local/lib/k8s"
    ]
    execute_command = local.execute_command
  }

  // Output Vagrant .box
  post-processor "vagrant" {
    compression_level = 9
    output            = "${path.root}/../../../builds/build_complete/${local.box_name}.virtualbox.box"
  }
}
