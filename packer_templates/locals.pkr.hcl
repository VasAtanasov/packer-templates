// =============================================================================
// Consolidated Locals
// =============================================================================
// Computed values and logic shared across all builds
// =============================================================================

locals {
  // -----------------------------------------------------------------------------
  // Platform Detection
  // -----------------------------------------------------------------------------
  is_windows = length(regexall("(?i)windows", lower(var.os_env))) > 0 || length(regexall("(?i)\\.exe$", lower(var.packer_executable))) > 0

  // -----------------------------------------------------------------------------
  // Provider Detection
  // -----------------------------------------------------------------------------
  // Extract provider type from enabled sources (e.g., "virtualbox-iso" from "source.virtualbox-iso.vm")
  active_providers = [for source in var.sources_enabled : split(".", source)[1]]

  // Determine if each provider is enabled
  is_virtualbox_iso_enabled = contains(local.active_providers, "virtualbox-iso")
  is_virtualbox_ovf_enabled = contains(local.active_providers, "virtualbox-ovf")
  is_virtualbox_enabled     = local.is_virtualbox_iso_enabled || local.is_virtualbox_ovf_enabled
  is_vmware_enabled         = contains(local.active_providers, "vmware-iso")
  is_qemu_enabled           = contains(local.active_providers, "qemu")

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
    rhel = []
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
        "${path.root}/scripts/variants/k8s-node/common/prepare.sh",
        "${path.root}/scripts/variants/k8s-node/common/configure_kernel.sh",
      ],
      [
        "${path.root}/scripts/variants/k8s-node/${local.os_family}/install_container_runtime.sh",
        "${path.root}/scripts/variants/k8s-node/${local.os_family}/install_kubernetes.sh",
      ],
      [
        "${path.root}/scripts/variants/k8s-node/common/configure_networking.sh",
        "${path.root}/scripts/variants/k8s-node/${local.os_family}/cleanup_k8s.sh",
      ],
    )
    "docker-host" = [
      "${path.root}/scripts/variants/docker-host/${local.os_family}/install_docker.sh",
      "${path.root}/scripts/variants/docker-host/${local.os_family}/configure_docker.sh",
      "${path.root}/scripts/variants/docker-host/${local.os_family}/cleanup_docker.sh",
    ]
  }

  selected_variant_scripts = var.variant == "base" ? [] : lookup(local.variant_scripts, var.variant, [])

  // -----------------------------------------------------------------------------
  // Custom Scripts Discovery (User Extensibility)
  // -----------------------------------------------------------------------------
  custom_scripts_dir = "${path.root}/scripts/custom/${local.os_family}"
  custom_scripts = fileexists(local.custom_scripts_dir) ? [
    for f in sort(fileset(local.custom_scripts_dir, "*.sh")) :
    "${local.custom_scripts_dir}/${f}"
  ] : []

  // -----------------------------------------------------------------------------
  // Consolidated Provisioning Script Lists (Semantic Names)
  // -----------------------------------------------------------------------------

  // Provider provisioning: common scripts + guest tools entry point
  // Guest tools script uses PACKER_BUILDER_TYPE to detect provider at runtime
  provider_provisioning_scripts = concat(
    local.common_scripts,
    ["${path.root}/scripts/providers/guest_tools.sh"]
  )

  // OS and variant configuration (provider-agnostic)
  os_and_variant_scripts = concat(
    # OS-specific configuration
    lookup(local.os_scripts, local.os_family, []),

    # Variant-specific configuration (includes variant cleanup)
    local.selected_variant_scripts,

    # User extension scripts
    local.custom_scripts,

    # Base OS cleanup (runs after variants clean themselves)
    lookup(local.cleanup_scripts, local.os_family, [])
  )

  // -----------------------------------------------------------------------------
  // Provisioner Execute Command
  // -----------------------------------------------------------------------------
  execute_command = "echo 'vagrant' | {{ .Vars }} sudo -S -E bash -eux '{{ .Path }}'"

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
