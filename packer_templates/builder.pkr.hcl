locals {
  box_name         = var.variant == "base" ? "${var.os_name}-${var.os_version}-${var.os_arch}" : "${var.os_name}-${var.os_version}-${var.os_arch}-${var.variant}"
  output_directory = var.output_directory == null ? "${path.root}/../../../builds/build_files/packer-${var.os_name}-${var.os_version}-${var.os_arch}" : var.output_directory
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
  iso_target_path = var.iso_target_path == "build_dir_iso" && var.iso_url != null ? "${path.root}/../../../builds/iso/${var.os_name}-${var.os_version}-${var.os_arch}-${substr(sha256(var.iso_url), 0, 8)}.iso" : var.iso_target_path

  // OS family used to select per-OS variant scripts
  os_family = contains(["debian", "ubuntu"], var.os_name) ? "debian" : (
    contains(["almalinux", "rocky", "rhel"], var.os_name) ? "rhel" : var.os_name
  )

  // Variant script mappings (dynamic for k8s-node)
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

  // Select variant scripts (empty for base variant)
  selected_variant_scripts = var.variant == "base" ? [] : lookup(local.variant_scripts, var.variant, [])
  execute_command          = "echo 'vagrant' | {{ .Vars }} sudo -S -E sh -eux '{{ .Path }}'"

  // Library paths (core + OS-specific)
  lib_core_sh = "/usr/local/lib/k8s/scripts/_common/lib-core.sh"
  lib_os_sh = {
    debian    = "/usr/local/lib/k8s/scripts/_common/lib-debian.sh"
    ubuntu    = "/usr/local/lib/k8s/scripts/_common/lib-debian.sh"
    almalinux = "/usr/local/lib/k8s/scripts/_common/lib-rhel.sh"
    rocky     = "/usr/local/lib/k8s/scripts/_common/lib-rhel.sh"
    rhel      = "/usr/local/lib/k8s/scripts/_common/lib-rhel.sh"
  }

  // Provider (VirtualBox) script paths by OS family
  vbox_install_deps_script    = "providers/virtualbox/${local.os_family}/install_dependencies.sh"
  vbox_guest_additions_script = "providers/virtualbox/${local.os_family}/guest_additions.sh"
  vbox_remove_deps_script     = "providers/virtualbox/${local.os_family}/remove_dependencies.sh"
}

