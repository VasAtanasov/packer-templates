// =============================================================================
// Consolidated Locals
// =============================================================================
// Computed values and logic shared across all builds
// =============================================================================

locals {
  // -----------------------------------------------------------------------------
  // Provider Detection
  // -----------------------------------------------------------------------------
  // Extract provider type from enabled sources (e.g., "virtualbox" from "source.virtualbox-iso.vm")
  active_providers = [for source in var.sources_enabled : split(".", source)[1]]

  // Determine if each provider is enabled
  is_virtualbox_enabled = contains(local.active_providers, "virtualbox-iso")
  is_vmware_enabled     = contains(local.active_providers, "vmware-iso")
  is_qemu_enabled       = contains(local.active_providers, "qemu")

  // -----------------------------------------------------------------------------
  // OS Family Detection
  // -----------------------------------------------------------------------------
  os_family = contains(["debian", "ubuntu"], var.os_name) ? "debian" : (
    contains(["almalinux", "rocky", "rhel"], var.os_name) ? "rhel" : var.os_name
  )

  // -----------------------------------------------------------------------------
  // Box Naming
  // -----------------------------------------------------------------------------
  box_name = var.variant == "base" ? "${var.os_name}-${var.os_version}-${var.os_arch}" : "${var.os_name}-${var.os_version}-${var.os_arch}-${var.variant}"

  // -----------------------------------------------------------------------------
  // Paths
  // -----------------------------------------------------------------------------
  output_directory = var.output_directory == null ? "${path.root}/../builds/build_files/packer-${var.os_name}-${var.os_version}-${var.os_arch}" : var.output_directory

  iso_target_path = var.iso_target_path == "build_dir_iso" && var.iso_url != null ? "${path.root}/../builds/iso/${var.os_name}-${var.os_version}-${var.os_arch}-${substr(sha256(var.iso_url), 0, 8)}.iso" : var.iso_target_path

  // HTTP directory: use OS family-specific directory
  http_directory = var.http_directory == null ? "${path.root}/http/${local.os_family}" : var.http_directory

  // -----------------------------------------------------------------------------
  // Library Paths (persistent during build)
  // -----------------------------------------------------------------------------
  lib_core_sh = "/usr/local/lib/scripts/_common/lib-core.sh"

  lib_os_sh = {
    debian    = "/usr/local/lib/scripts/_common/lib-debian.sh"
    ubuntu    = "/usr/local/lib/scripts/_common/lib-debian.sh"
    almalinux = "/usr/local/lib/scripts/_common/lib-rhel.sh"
  }

  // -----------------------------------------------------------------------------
  // Provisioning Scripts by OS Family
  // -----------------------------------------------------------------------------

  // Common scripts (OS-agnostic)
  common_scripts = [
    "${path.root}/scripts/_common/vagrant.sh",
    "${path.root}/scripts/_common/sshd.sh",
  ]

  // OS-specific scripts
  os_scripts = {
    debian = [
      "${path.root}/scripts/debian/systemd.sh",
      "${path.root}/scripts/debian/sudoers.sh",
      "${path.root}/scripts/debian/networking.sh"
    ]
  }

  cleanup_scripts = {
    debian = ["${path.root}/scripts/debian/cleanup.sh"]
    rhel   = ["${path.root}/scripts/rhel/cleanup.sh"]
  }

  // -----------------------------------------------------------------------------
  // Variant Scripts (Dynamic Selection)
  // -----------------------------------------------------------------------------
  variant_scripts = {
    "k8s-node" = concat(
      [
        "variants/k8s-node/common/prepare.sh",
        "variants/k8s-node/common/configure_kernel.sh",
      ],
      [
        "variants/k8s-node/${local.os_family}/install_container_runtime.sh",
        "variants/k8s-node/${local.os_family}/install_kubernetes.sh",
      ],
      [
        "variants/k8s-node/common/configure_networking.sh",
      ],
    )
    "docker-host" = [
      "variants/docker-host/${local.os_family}/install_docker.sh",
      "variants/docker-host/${local.os_family}/configure_docker.sh",
    ]
  }

  selected_variant_scripts = var.variant == "base" ? [] : lookup(local.variant_scripts, var.variant, [])

  // -----------------------------------------------------------------------------
  // Provisioner Execute Command
  // -----------------------------------------------------------------------------
  execute_command = "echo 'vagrant' | {{ .Vars }} sudo -S -E bash -eux '{{ .Path }}'"

  // -----------------------------------------------------------------------------
  // Provider Guest Tools Configuration (Provider-Agnostic)
  // -----------------------------------------------------------------------------
  provider_guest_tools = {
    virtualbox = {
      script   = "${path.root}/scripts/providers/virtualbox/guest_tools_virtualbox.sh"
      mode_var = var.vbox_guest_additions_mode
      enabled  = local.is_virtualbox_enabled
    }
    vmware = {
      script   = "${path.root}/scripts/providers/vmware/guest_tools_vmware.sh" # Future
      mode_var = null                                                          # Future: var.vmware_tools_mode
      enabled  = local.is_vmware_enabled
    }
  }

  // Get list of providers that need guest tools installed
  providers_with_tools = [
    for provider, config in local.provider_guest_tools :
    provider if config.script != null && config.enabled && (config.mode_var == null || config.mode_var != "disable")
  ]

  // Build list of guest tool scripts to run
  guest_tools_scripts = [
    for provider in local.providers_with_tools :
    local.provider_guest_tools[provider].script
  ]

  // -----------------------------------------------------------------------------
  // VirtualBox-specific Locals
  // -----------------------------------------------------------------------------
  vboxmanage = var.vboxmanage == null ? (
    var.os_arch == "aarch64" ? [
      ["modifyvm", "{{.Name}}", "--chipset", "armv8virtual"],
      ["modifyvm", "{{.Name}}", "--audio-enabled", "off"],
      ["modifyvm", "{{.Name}}", "--nat-localhostreachable1", "on"],
      ["modifyvm", "{{.Name}}", "--cableconnected1", "on"],
      ["modifyvm", "{{.Name}}", "--usb-xhci", "on"],
      ["modifyvm", "{{.Name}}", "--graphicscontroller", "qemuramfb"],
      ["modifyvm", "{{.Name}}", "--mouse", "usb"],
      ["modifyvm", "{{.Name}}", "--keyboard", "usb"],
      ["storagectl", "{{.Name}}", "--name", "IDE Controller", "--remove"],
      ] : [
      ["modifyvm", "{{.Name}}", "--chipset", "ich9"],
      ["modifyvm", "{{.Name}}", "--audio-enabled", "off"],
      ["modifyvm", "{{.Name}}", "--nat-localhostreachable1", "on"],
      ["modifyvm", "{{.Name}}", "--cableconnected1", "on"],
    ]
  ) : var.vboxmanage

  vbox_firmware             = var.os_arch == "aarch64" ? "efi" : "bios"
  vbox_hard_drive_interface = var.os_arch == "aarch64" ? "virtio" : "sata"
  vbox_iso_interface        = var.os_arch == "aarch64" ? "virtio" : "sata"
}
