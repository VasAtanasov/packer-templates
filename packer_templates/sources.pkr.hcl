// =============================================================================
// Consolidated Source Definitions
// =============================================================================
// Builder source configurations for all supported providers
// =============================================================================

// -----------------------------------------------------------------------------
// VirtualBox ISO Source
// -----------------------------------------------------------------------------
source "virtualbox-iso" "vm" {
  vm_name       = local.box_name
  firmware      = local.vbox_firmware
  guest_os_type = var.vbox_guest_os_type

  iso_url         = var.iso_url
  iso_checksum    = var.iso_checksum
  iso_target_path = local.iso_target_path

  http_directory = local.http_directory
  boot_wait      = var.boot_wait
  boot_command   = var.boot_command

  ssh_username           = var.ssh_username
  ssh_password           = var.ssh_password
  ssh_timeout            = var.ssh_timeout
  ssh_handshake_attempts = var.ssh_handshake_attempts

  shutdown_command = var.shutdown_command
  shutdown_timeout = var.shutdown_timeout

  headless  = var.headless
  cpus      = var.cpus
  memory    = var.memory
  disk_size = var.disk_size

  vboxmanage = local.vboxmanage

  guest_additions_mode = var.vbox_guest_additions_mode
  guest_additions_path = var.vbox_guest_additions_path

  output_directory = "${local.output_directory}-virtualbox"

  hard_drive_interface = local.vbox_hard_drive_interface
  iso_interface        = local.vbox_iso_interface
  rtc_time_base        = var.vbox_rtc_time_base
}

// -----------------------------------------------------------------------------
// VirtualBox OVF Source
// -----------------------------------------------------------------------------
source "virtualbox-ovf" "vm" {
  vm_name = local.box_name

  source_path = var.ovf_source_path
  checksum    = var.ovf_checksum

  ssh_username           = var.ssh_username
  ssh_password           = var.ssh_password
  ssh_timeout            = var.ssh_timeout
  ssh_handshake_attempts = var.ssh_handshake_attempts

  shutdown_command = var.shutdown_command
  shutdown_timeout = var.shutdown_timeout

  headless = var.headless

  vboxmanage = local.vboxmanage

  guest_additions_path = var.vbox_guest_additions_path

  output_directory = "${local.output_directory}-virtualbox-ovf"
}