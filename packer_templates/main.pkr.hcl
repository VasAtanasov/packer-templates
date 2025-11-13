// =============================================================================
// Packer Template: Debian 12/13 on VirtualBox (Vagrant box)
// =============================================================================
// Scope: Minimal, focused on Debian and VirtualBox. Easy to extend later.
// Usage:
//   cd os_pkrvars/debian
//   packer build -var-file=debian-12-x86_64.pkrvars.hcl ../../packer_templates
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
}

variable "iso_url" { type = string }
variable "iso_checksum" { type = string }

// VirtualBox specifics
variable "vbox_guest_os_type" { type = string }
variable "boot_command" { type = list(string) }
variable "vboxmanage" {
  type    = list(list(string))
  default = []
}
variable "vbox_guest_additions_path" {
  type    = string
  // Default resolves to the VirtualBox version ISO name
  default = "VBoxGuestAdditions_{{ .Version }}.iso"
}
variable "vbox_guest_additions_mode" {
  type    = string
  default = "disable" // keep disabled by default for reliability on WSL2
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

// -----------------------------------------------------------------------------
// Locals
// -----------------------------------------------------------------------------
locals {
  box_name = "${var.os_name}-${var.os_version}-${var.os_arch}"
}

// -----------------------------------------------------------------------------
// Source (builder): VirtualBox ISO
// -----------------------------------------------------------------------------
source "virtualbox-iso" "vm" {
  vm_name               = local.box_name
  guest_os_type         = var.vbox_guest_os_type

  iso_url               = var.iso_url
  iso_checksum          = var.iso_checksum

  http_directory        = "${path.root}/http"
  boot_wait             = "5s"
  boot_command          = var.boot_command

  ssh_username          = "vagrant"
  ssh_password          = "vagrant"
  ssh_timeout           = "30m"
  ssh_handshake_attempts = 100

  shutdown_command      = "echo 'vagrant' | sudo -S shutdown -P now"

  headless              = var.headless
  cpus                  = var.cpus
  memory                = var.memory
  disk_size             = var.disk_size

  // Keep VBox changes explicit and minimal; more can be added via var.vboxmanage
  vboxmanage            = var.vboxmanage

  // We do not auto-install guest additions here; rely on OS packages or manual choice
  guest_additions_mode  = var.vbox_guest_additions_mode
  guest_additions_path  = var.vbox_guest_additions_path
}

// -----------------------------------------------------------------------------
// Build: 3 logical phases using shell provisioners
// -----------------------------------------------------------------------------
build {
  sources = [
    "source.virtualbox-iso.vm",
  ]

  // Upload all helper scripts so relative sourcing (lib.sh) works predictably
  provisioner "file" {
    source      = "${path.root}/scripts"
    destination = "/tmp/packer-scripts"
  }

  provisioner "shell" {
    inline = [
      "install -d -m 0755 /usr/local/lib/k8s",
      "install -m 0644 /tmp/packer-scripts/_common/lib.sh /usr/local/lib/k8s/lib.sh",
      "chown root:root /usr/local/lib/k8s/lib.sh"
    ]
    execute_command = "sudo -S bash -c '{{ .Vars }} {{ .Path }}'"
  }

  // Phase 1: System prep (updates, disable unattended upgrades)
  provisioner "shell" {
    inline = [
      "bash /tmp/packer-scripts/_common/update_packages.sh",
    ]
    environment_vars = [
      "LIB_DIR=/usr/local/lib/k8s",
      "LIB_SH=/usr/local/lib/k8s/lib.sh",
    ]
    execute_command   = "sudo -S bash -c '{{ .Vars }} {{ .Path }}'"
    expect_disconnect = true // script may reboot
  }

  // Phase 2: Base config for Vagrant + Debian bits
  provisioner "shell" {
    inline = [
      "bash /tmp/packer-scripts/_common/sshd.sh",
      "bash /tmp/packer-scripts/_common/vagrant.sh",
      "bash /tmp/packer-scripts/debian/systemd_debian.sh",
      "bash /tmp/packer-scripts/debian/sudoers_debian.sh",
      "bash /tmp/packer-scripts/debian/networking_debian.sh",
    ]
    environment_vars = [
      "LIB_DIR=/usr/local/lib/k8s",
      "LIB_SH=/usr/local/lib/k8s/lib.sh",
    ]
    execute_command = "sudo -S bash -c '{{ .Vars }} {{ .Path }}'"
  }

  // Phase 3: Cleanup & minimize (smaller boxes)
  provisioner "shell" {
    inline = [
      "bash /tmp/packer-scripts/debian/cleanup_debian.sh",
      "bash /tmp/packer-scripts/_common/minimize.sh",
    ]
    environment_vars = [
      "LIB_DIR=/usr/local/lib/k8s",
      "LIB_SH=/usr/local/lib/k8s/lib.sh",
    ]
    execute_command = "sudo -S bash -c '{{ .Vars }} {{ .Path }}'"
  }

  // Final cleanup: remove build-only library
  provisioner "shell" {
    inline = [
      "rm -f /usr/local/lib/k8s/lib.sh",
      "rmdir /usr/local/lib/k8s || true"
    ]
    execute_command = "sudo -S bash -c '{{ .Vars }} {{ .Path }}'"
  }

  // Output Vagrant .box
  post-processor "vagrant" {
    compression_level = 9
    output            = "${path.root}/../builds/build_complete/${local.box_name}.virtualbox.box"
  }
}
