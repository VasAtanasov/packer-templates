data "external-raw" "host_os" {
  program = ["uname", "-s"]
}

locals {
  build_dir = abspath("${path.root}/../builds/")
  host_os   = chomp(data.external-raw.host_os.result)
  vbox_firmware = var.vbox_firmware == null ? (var.os_arch == "aarch64" ? "efi" : "bios") : var.vbox_firmware
  vbox_gfx_controller = var.vbox_gfx_controller == null ? (var.is_windows ? "vboxsvga" : "vmsvga") : var.vbox_gfx_controller
  vbox_gfx_vram_size = var.vbox_gfx_controller == null ? (var.is_windows ? 128 : 33) : var.vbox_gfx_vram_size
  vbox_guest_additions_mode = var.vbox_guest_additions_mode == null ? (var.is_windows ? "attach" : "upload") : var.vbox_guest_additions_mode
  vbox_hard_drive_interface = var.vbox_hard_drive_interface == null ? (var.os_arch == "aarch64" ? "virtio" : "sata") : var.vbox_hard_drive_interface
  vbox_iso_interface = var.vbox_iso_interface == null ? (var.os_arch == "aarch64" ? "virtio" : "sata") : var.vbox_iso_interface
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
}

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
