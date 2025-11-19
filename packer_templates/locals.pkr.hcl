// =============================================================================
// Consolidated Locals
// =============================================================================
// Computed values and logic shared across all builds
// =============================================================================

locals {
  // -----------------------------------------------------------------------------
  // Provider Detection
  // -----------------------------------------------------------------------------
  enabled_sources = var.sources_enabled != null ? var.sources_enabled : [
    "source.${var.primary_source}.vm"
  ]

  source_names = [for source in local.enabled_sources : trimprefix(source, "source.")]

  // Extract provider type from enabled sources (e.g., "virtualbox-iso" from "source.virtualbox-iso.vm")
  active_providers = [for source in local.enabled_sources : split(".", source)[1]]

  // Provider family normalization for multi-source builds
  provider_family_map = {
    "virtualbox-iso" = "virtualbox"
    "virtualbox-ovf" = "virtualbox"
    "vmware-iso"     = "vmware"
    "qemu"           = "qemu"
  }
  active_provider_families = distinct([
    for p in local.active_providers : lookup(local.provider_family_map, p, p)
  ])

  // -----------------------------------------------------------------------------
  // OS Family Detection
  // -----------------------------------------------------------------------------
  os_family = contains(["debian", "ubuntu"], var.os_name) ? "debian" : (
    contains(["almalinux", "rocky", "rhel"], var.os_name) ? "rhel" : var.os_name
  )

  // -----------------------------------------------------------------------------
  // Box Naming
  // -----------------------------------------------------------------------------
  // Base box name (OS + full version + arch)
  base_box_name = "${var.os_name}-${var.os_version}-${var.os_arch}"

  // Full box name:
  // - base:       <os_name>-<os_version>-<os_arch>
  // - k8s-node:   <os_name>-<os_version>-<os_arch>-k8s-node-<kubernetes_version>
  // - other vars: <os_name>-<os_version>-<os_arch>-<variant>
  box_name = var.variant == "base" ? local.base_box_name : (
    var.variant == "k8s-node"
    ? "${local.base_box_name}-${var.variant}-${var.kubernetes_version}"
    : "${local.base_box_name}-${var.variant}"
  )

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
        "${path.root}/scripts/variants/k8s-node/common/prepull_cni_images.sh",
        "${path.root}/scripts/variants/k8s-node/common/write_cni_manifests.sh",
      ],
      [
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
  // Support three levels with precedence: variant → provider → OS family
  // Only include files matching two-digit prefix pattern (??-*.sh)
  custom_scripts_dir_base    = "${path.root}/scripts/custom/${local.os_family}"
  custom_scripts_variant_dir = "${local.custom_scripts_dir_base}/${var.variant}"

  custom_scripts_os = fileexists(local.custom_scripts_dir_base) ? [
    for f in sort(fileset(local.custom_scripts_dir_base, "??-*.sh")) :
    "${local.custom_scripts_dir_base}/${f}"
  ] : []

  custom_scripts_variant = fileexists(local.custom_scripts_variant_dir) ? [
    for f in sort(fileset(local.custom_scripts_variant_dir, "??-*.sh")) :
    "${local.custom_scripts_variant_dir}/${f}"
  ] : []

  custom_scripts_provider = flatten([
    for family in local.active_provider_families : (
      fileexists("${local.custom_scripts_dir_base}/${family}") ? [
        for f in sort(fileset("${local.custom_scripts_dir_base}/${family}", "??-*.sh")) :
        "${local.custom_scripts_dir_base}/${family}/${f}"
      ] : []
    )
  ])

  // Final list with precedence and duplicates removed
  custom_scripts = distinct(concat(
    local.custom_scripts_variant,
    local.custom_scripts_provider,
    local.custom_scripts_os,
  ))

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
  // Provisioner Controls
  // -----------------------------------------------------------------------------
  // When skip_provisioners is true, except all enabled sources (skip provisioners)
  // When false, except nothing (run provisioners normally)
  provisioner_except = var.skip_provisioners ? local.source_names : null

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
