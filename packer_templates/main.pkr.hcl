// =============================================================================
// Packer Template: Universal Multi-OS Multi-Variant (Vagrant box)
// =============================================================================
// Scope: Single template supporting multiple OSes and variants
// Variants: base (minimal), k8s-node (Kubernetes), docker-host (Docker)
// Usage:
//   # Base box
//   packer build -var-file=debian-12-x86_64.pkrvars.hcl packer_templates
//
//   # K8s variant
//   packer build -var-file=debian-12-x86_64-k8s-node.pkrvars.hcl packer_templates
//
//   # Ubuntu K8s variant (future)
//   packer build -var-file=ubuntu-24-x86_64-k8s-node.pkrvars.hcl packer_templates
// =============================================================================

// -----------------------------------------------------------------------------
// Variables (kept minimal and Debian/VirtualBox-focused)
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
  type = list(list(string))
  default = null
}
variable "vbox_guest_additions_path" {
  type = string
  // Default resolves to the VirtualBox version ISO name
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
    condition = contains(["base", "k8s-node", "docker-host"], var.variant)
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
    condition = contains(["containerd", "cri-o"], var.container_runtime)
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
  output_directory = var.output_directory == null ? "${path.root}/../builds/build_files/packer-${var.os_name}-${var.os_version}-${var.os_arch}" : var.output_directory
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
  iso_target_path = var.iso_target_path == "build_dir_iso" && var.iso_url != null ? "${path.root}/../builds/iso/${var.os_name}-${var.os_version}-${var.os_arch}-${substr(sha256(var.iso_url), 0, 8)}.iso" : var.iso_target_path

  // Variant script mappings
  variant_scripts = {
    "k8s-node" = [
      "variants/k8s-node/prepare.sh",
      "variants/k8s-node/configure_kernel.sh",
      "variants/k8s-node/install_container_runtime.sh",
      "variants/k8s-node/install_kubernetes.sh",
      "variants/k8s-node/configure_networking.sh",
    ],
    "docker-host" = [
      "variants/docker-host/install_docker.sh",
      "variants/docker-host/configure_docker.sh",
    ],
  }

  // Select variant scripts (empty for base variant)
  selected_variant_scripts = var.variant == "base" ? [] : lookup(local.variant_scripts, var.variant, [])
  execute_command          = "echo 'vagrant' | {{ .Vars }} sudo -S -E sh -eux '{{ .Path }}'"
}

// -----------------------------------------------------------------------------
// Source (builder): VirtualBox ISO
// -----------------------------------------------------------------------------
source "virtualbox-iso" "vm" {
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

// -----------------------------------------------------------------------------
// Build: 3 logical phases using shell provisioners
// -----------------------------------------------------------------------------
build {
  sources = [
    "source.virtualbox-iso.vm",
  ]

  // Upload all helper scripts once to /tmp, then install to persistent location
  provisioner "file" {
    source      = "${path.root}/scripts"
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
      "LIB_SH=/usr/local/lib/k8s/scripts/_common/lib.sh",
    ]
    execute_command   = local.execute_command
    expect_disconnect = true // script may reboot
  }

  // Phase 2a: Provider dependencies (kernel headers, build tools for VirtualBox)
  // Skip when Guest Additions are disabled by template var
  provisioner "shell" {
    only = var.vbox_guest_additions_mode != "disable" ? ["virtualbox-iso.vm"] : []
    inline = [
      "bash /usr/local/lib/k8s/scripts/providers/virtualbox/install_dependencies.sh",
    ]
    environment_vars = [
      "LIB_DIR=/usr/local/lib/k8s",
      "LIB_SH=/usr/local/lib/k8s/scripts/_common/lib.sh",
    ]
    execute_command   = local.execute_command
    expect_disconnect = true // may reboot if kernel packages installed
  }

  // Phase 2b: Provider integration (Guest Additions)
  // Skip when Guest Additions are disabled by template var
  provisioner "shell" {
    only = var.vbox_guest_additions_mode != "disable" ? ["virtualbox-iso.vm"] : []
    inline = [
      "bash /usr/local/lib/k8s/scripts/providers/virtualbox/guest_additions.sh",
    ]
    environment_vars = [
      "LIB_DIR=/usr/local/lib/k8s",
      "LIB_SH=/usr/local/lib/k8s/scripts/_common/lib.sh",
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
      "LIB_SH=/usr/local/lib/k8s/scripts/_common/lib.sh",
    ]
    execute_command = local.execute_command
  }

  // Phase 2d: Variant-specific provisioning (dynamic based on variant variable)
  provisioner "shell" {
    // Only run if variant is not "base" (skip for base boxes)
    only = var.variant != "base" ? ["virtualbox-iso.vm"] : []

    // Dynamically build script list based on selected variant
    // If no scripts (base variant), use a harmless no-op to keep Packer validation happy
    inline = length(local.selected_variant_scripts) > 0 ? [
      for script in local.selected_variant_scripts :
      "bash /usr/local/lib/k8s/scripts/${script}"
    ] : ["echo 'No variant scripts to run (base variant)'"]

    environment_vars = concat(
      [
        "LIB_DIR=/usr/local/lib/k8s",
        "LIB_SH=/usr/local/lib/k8s/scripts/_common/lib.sh",
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
      "LIB_SH=/usr/local/lib/k8s/scripts/_common/lib.sh",
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
      "LIB_SH=/usr/local/lib/k8s/scripts/_common/lib.sh",
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
    output            = "${path.root}/../builds/build_complete/${local.box_name}.virtualbox.box"
  }
}
