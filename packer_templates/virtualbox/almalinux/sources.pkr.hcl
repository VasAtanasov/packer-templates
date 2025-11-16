// =============================================================================
// AlmaLinux VirtualBox Sources
// =============================================================================
// Variables, locals, and source definitions for building AlmaLinux boxes on VirtualBox
// =============================================================================

// -----------------------------------------------------------------------------
// Variables
// -----------------------------------------------------------------------------

variable "os_name" { type = string }
variable "os_version" { type = string }
variable "os_arch" {
  type = string
  validation {
    condition     = var.os_arch == "x86_64" || var.os_arch == "aarch64"
    error_message = "The os_arch must be 'x86_64' or 'aarch64'."
  }
  description = "OS architecture type, x86_64 or aarch64"
}

variable "iso_url" { type = string }
variable "iso_checksum" { type = string }
variable "output_directory" {
  type    = string
  default = null
}

// VirtualBox specifics
variable "vbox_guest_os_type" { type = string }
variable "boot_command" { type = list(string) }
variable "iso_target_path" {
  type        = string
  default     = "build_dir_iso"
  description = "Path to store the ISO file. Null will use packer cache default or build_dir_iso will put it in the local build/iso directory."
}
variable "vboxmanage" {
  type    = list(list(string))
  default = null
}
variable "vbox_guest_additions_path" {
  type    = string
  default = "VBoxGuestAdditions_{{ .Version }}.iso"
}
variable "vbox_guest_additions_mode" {
  type    = string
  default = "upload"
}
variable "headless" {
  type    = bool
  default = true
}
variable "cpus" {
  type    = number
  default = 2
}
variable "memory" {
  type    = number
  default = 2048
}
variable "disk_size" {
  type    = number
  default = 40960 // 40GB
}
variable "vbox_rtc_time_base" {
  type        = string
  default     = "UTC"
  description = "RTC time base"
}

// Variant-specific variables
variable "variant" {
  type    = string
  default = "base"
  validation {
    condition     = contains(["base", "k8s-node", "docker-host"], var.variant)
    error_message = "The variant must be 'base', 'k8s-node', or 'docker-host'."
  }
  description = "Box variant: base (minimal), k8s-node (Kubernetes), docker-host (Docker)"
}

// K8s-specific variables (only used when variant = "k8s-node")
variable "kubernetes_version" {
  type        = string
  default     = "1.28"
  description = "Kubernetes major.minor version (e.g., 1.28)"
}

variable "container_runtime" {
  type    = string
  default = "containerd"
  validation {
    condition     = contains(["containerd", "cri-o"], var.container_runtime)
    error_message = "The container_runtime must be 'containerd' or 'cri-o'."
  }
  description = "Container runtime: containerd or cri-o"
}

variable "crio_version" {
  type        = string
  default     = "1.28"
  description = "CRI-O version (only used if container_runtime=cri-o)"
}

// -----------------------------------------------------------------------------
// Locals
// -----------------------------------------------------------------------------
locals {
  box_name         = var.variant == "base" ? "${var.os_name}-${var.os_version}-${var.os_arch}" : "${var.os_name}-${var.os_version}-${var.os_arch}-${var.variant}"
  output_directory = var.output_directory == null ? "${path.root}/../../../builds/build_files/packer-${var.os_name}-${var.os_version}-${var.os_arch}" : var.output_directory
  vboxmanage       = var.vboxmanage == null ? (
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

// -----------------------------------------------------------------------------
// Source (builder): VirtualBox ISO
// -----------------------------------------------------------------------------
source "virtualbox-iso" "almalinux" {
  vm_name       = local.box_name
  firmware      = var.os_arch == "aarch64" ? "efi" : "bios"
  guest_os_type = var.vbox_guest_os_type

  iso_url         = var.iso_url
  iso_checksum    = var.iso_checksum
  iso_target_path = local.iso_target_path

  http_directory = "${path.root}/http"
  boot_wait      = "15s"
  boot_command   = var.boot_command

  ssh_username           = "vagrant"
  ssh_password           = "vagrant"
  ssh_timeout            = "30m"
  ssh_handshake_attempts = 100

  shutdown_command = "echo 'vagrant' | sudo -S shutdown -P now"

  headless  = var.headless
  cpus      = var.cpus
  memory    = var.memory
  disk_size = var.disk_size

  vboxmanage = local.vboxmanage

  guest_additions_mode = var.vbox_guest_additions_mode
  guest_additions_path = var.vbox_guest_additions_path

  output_directory = "${local.output_directory}-virtualbox"

  hard_drive_interface = var.os_arch == "aarch64" ? "virtio" : "sata"
  iso_interface        = var.os_arch == "aarch64" ? "virtio" : "sata"
  rtc_time_base        = var.vbox_rtc_time_base
}

