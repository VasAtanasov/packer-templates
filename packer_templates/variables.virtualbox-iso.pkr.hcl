variable "vbox_boot_command" {
  type = list(string)
  default     = null
  description = "Commands to pass to gui session to initiate automated install"
}

variable "vbox_boot_wait" {
  type    = string
  default = null
}

variable "vbox_firmware" {
  type        = string
  default     = null
  description = "Firmware type, takes bios or efi"
}

variable "vbox_gfx_controller" {
  type    = string
  default = null
}

variable "vbox_gfx_vram_size" {
  type    = number
  default = null
}

variable "vbox_guest_additions_interface" {
  type    = string
  default = null
}

variable "vbox_guest_additions_mode" {
  type    = string
  default = null
}

variable "vbox_guest_additions_path" {
  type    = string
  default = "VBoxGuestAdditions_{{ .Version }}.iso"
}

variable "vbox_guest_os_type" {
  type        = string
  default     = null
  description = "OS type for virtualization optimization"
}

variable "vbox_hard_drive_interface" {
  type    = string
  default = null
}

variable "vbox_iso_interface" {
  type    = string
  default = null
}
variable "vboxmanage" {
  type = list(list(string))
  default = null
}

variable "vbox_nic_type" {
  type    = string
  default = null
}

variable "virtualbox_version_file" {
  type    = string
  default = ".vbox_version"
}

variable "vbox_rtc_time_base" {
  type        = string
  default     = "UTC"
  description = "RTC time base"
}