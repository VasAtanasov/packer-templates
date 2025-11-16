variable "os_name" {
  type        = string
  description = "OS Brand Name"
}

variable "os_version" {
  type        = string
  description = "OS version number"
}

variable "os_arch" {
  type = string
  validation {
    condition     = var.os_arch == "x86_64" || var.os_arch == "aarch64"
    error_message = "The os_arch must be 'x86_64' or 'aarch64'."
  }
  description = "OS architecture type, x86_64 or aarch64"
}

variable "http_proxy" {
  type        = string
  default = env("http_proxy")
  description = "Http proxy url to connect to the internet"
}

variable "https_proxy" {
  type        = string
  default = env("https_proxy")
  description = "Https proxy url to connect to the internet"
}

variable "no_proxy" {
  type        = string
  default = env("no_proxy")
  description = "No Proxy"
}

variable "sources_enabled" {
  type = list(string)
  default = [
    "source.parallels-iso.vm",
    "source.qemu.vm",
    "source.utm-iso.vm",
    "source.virtualbox-iso.vm",
    "source.vmware-iso.vm",
  ]
  description = "Build Sources to use for building vagrant boxes"
}

variable "boot_command" {
  type = list(string)
  default     = null
  description = "Commands to pass to gui session to initiate automated install"
}

variable "default_boot_wait" {
  type    = string
  default = null
}

variable "cd_content" {
  type = map(string)
  default     = null
  description = "Content to be served by the cdrom"
}

variable "cd_files" {
  type = list(string)
  default = null
}

variable "cd_label" {
  type    = string
  default = "cidata"
}

variable "cpus" {
  type    = number
  default = 2
}

variable "communicator" {
  type    = string
  default = null
}

variable "disk_size" {
  type    = number
  default = null
}

variable "floppy_files" {
  type = list(string)
  default = null
}

variable "headless" {
  type        = bool
  default     = true
  description = "Start GUI window to interact with VM"
}

variable "http_directory" {
  type    = string
  default = null
}

variable "iso_checksum" {
  type        = string
  default     = null
  description = "ISO download checksum"
}

variable "iso_target_path" {
  type        = string
  default     = "build_dir_iso"
  description = "Path to store the ISO file. Null will use packer cache default or build_dir_iso will put it in the local build/iso directory."
}

variable "iso_url" {
  type        = string
  default     = null
  description = "ISO download url"
}

variable "memory" {
  type    = number
  default = null
}

variable "output_directory" {
  type    = string
  default = null
}

variable "shutdown_command" {
  type    = string
  default = null
}

variable "shutdown_timeout" {
  type    = string
  default = "15m"
}

variable "ssh_password" {
  type    = string
  default = "vagrant"
}

variable "ssh_port" {
  type    = number
  default = 22
}

variable "ssh_timeout" {
  type    = string
  default = "15m"
}

variable "ssh_username" {
  type    = string
  default = "vagrant"
}