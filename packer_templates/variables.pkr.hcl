// =============================================================================
// Consolidated Packer Variables
// =============================================================================
// All common variables for building boxes across providers and operating systems
// =============================================================================

// -----------------------------------------------------------------------------
// Provider Selection
// -----------------------------------------------------------------------------
variable "provider" {
  type    = string
  default = "virtualbox"
  validation {
    condition     = contains(["virtualbox"], var.provider)
    error_message = "The provider must be 'virtualbox'."
  }
  description = "Provider to use for building: virtualbox"
}

// -----------------------------------------------------------------------------
// Operating System Identification
// -----------------------------------------------------------------------------
variable "os_name" {
  type        = string
  description = "OS name (debian, ubuntu, almalinux, rocky, rhel)"
}

variable "os_version" {
  type        = string
  description = "OS version number"
}

variable "os_arch" {
  type = string
  validation {
    condition     = contains(["x86_64", "aarch64"], var.os_arch)
    error_message = "The os_arch must be 'x86_64' or 'aarch64'."
  }
  description = "OS architecture: x86_64 or aarch64"
}

// -----------------------------------------------------------------------------
// ISO Configuration
// -----------------------------------------------------------------------------
variable "iso_url" {
  type        = string
  description = "ISO download URL"
}

variable "iso_checksum" {
  type        = string
  description = "ISO checksum (algorithm:value format)"
}

variable "iso_target_path" {
  type        = string
  default     = "build_dir_iso"
  description = "Path to store the ISO file. 'build_dir_iso' uses local builds/iso/, null uses Packer cache."
}

// -----------------------------------------------------------------------------
// VM Hardware Configuration
// -----------------------------------------------------------------------------
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

variable "headless" {
  type        = bool
  default     = true
  description = "Run VM in headless mode (no GUI)"
}

// -----------------------------------------------------------------------------
// Boot Configuration
// -----------------------------------------------------------------------------
variable "boot_command" {
  type        = list(string)
  description = "Commands to initiate automated installation"
}

variable "boot_wait" {
  type    = string
  default = "15s"
}

// -----------------------------------------------------------------------------
// SSH Configuration
// -----------------------------------------------------------------------------
variable "ssh_username" {
  type    = string
  default = "vagrant"
}

variable "ssh_password" {
  type    = string
  default = "vagrant"
}

variable "ssh_timeout" {
  type    = string
  default = "30m"
}

variable "ssh_handshake_attempts" {
  type    = number
  default = 100
}

// -----------------------------------------------------------------------------
// Output Configuration
// -----------------------------------------------------------------------------
variable "output_directory" {
  type    = string
  default = null
}

variable "shutdown_command" {
  type    = string
  default = "echo 'vagrant' | sudo -S shutdown -P now"
}

variable "shutdown_timeout" {
  type    = string
  default = "15m"
}

variable "keep_input_artifact" {
  type        = bool
  default     = false
  description = "Keep intermediate build artifacts (VM files) after creating .box file"
}

// -----------------------------------------------------------------------------
// HTTP Server (for preseed/kickstart files)
// -----------------------------------------------------------------------------
variable "http_directory" {
  type    = string
  default = null
}

// -----------------------------------------------------------------------------
// Proxy Configuration
// -----------------------------------------------------------------------------
variable "http_proxy" {
  type    = string
  default = env("http_proxy")
}

variable "https_proxy" {
  type    = string
  default = env("https_proxy")
}

variable "no_proxy" {
  type    = string
  default = env("no_proxy")
}

// -----------------------------------------------------------------------------
// Advanced Options
// -----------------------------------------------------------------------------
variable "sources_enabled" {
  type        = list(string)
  default     = null
  description = "Optional explicit list of sources (e.g., [\"source.virtualbox-iso.vm\"]). When null, derived from primary_source."
}

variable "primary_source" {
  type    = string
  default = "virtualbox-iso"
  validation {
    condition     = contains(["virtualbox-iso", "virtualbox-ovf"], var.primary_source)
    error_message = "Primary source must be one of: virtualbox-iso, virtualbox-ovf."
  }
  description = "Primary builder source to use when sources_enabled is not explicitly set."
}

// -----------------------------------------------------------------------------
// Build Controls
// -----------------------------------------------------------------------------
variable "skip_provisioners" {
  type        = bool
  default     = false
  description = "When true, skip all provisioners to produce a clean base VM/OVF."
}

// -----------------------------------------------------------------------------
// VirtualBox-specific Variables
// -----------------------------------------------------------------------------
variable "vbox_guest_os_type" {
  type        = string
  default     = null
  description = "VirtualBox guest OS type for optimization"
}

variable "vbox_guest_additions_mode" {
  type    = string
  default = "upload"
  validation {
    condition     = contains(["upload", "attach", "disable"], var.vbox_guest_additions_mode)
    error_message = "The vbox_guest_additions_mode must be 'upload', 'attach', or 'disable'."
  }
}

variable "vbox_guest_additions_path" {
  type    = string
  default = "VBoxGuestAdditions_{{ .Version }}.iso"
}

variable "vbox_rtc_time_base" {
  type    = string
  default = "UTC"
}

variable "vboxmanage" {
  type    = list(list(string))
  default = null
}

variable "vbox_keep_registered" {
  type        = bool
  default     = false
  description = "Keep VirtualBox VMs registered after build (enables manual export)."
}

// -----------------------------------------------------------------------------
// VirtualBox OVF Import Configuration
// -----------------------------------------------------------------------------
variable "ovf_source_path" {
  type        = string
  default     = null
  description = "Path to OVF/OVA file for virtualbox-ovf builder"
}

variable "ovf_checksum" {
  type        = string
  default     = null
  description = "Checksum for OVF/OVA file (algorithm:value format, e.g., sha256:abc123...)"
}

// -----------------------------------------------------------------------------
// VMware-specific Variables
// -----------------------------------------------------------------------------
variable "vmware_tools_mode" {
  type    = string
  default = "auto"
  validation {
    condition     = contains(["auto", "disable"], var.vmware_tools_mode)
    error_message = "The vmware_tools_mode must be 'auto' or 'disable'."
  }
  description = "VMware Tools installation mode: 'auto' to install, 'disable' to skip"
}

// -----------------------------------------------------------------------------
// Variant Configuration
// -----------------------------------------------------------------------------
variable "variant" {
  type    = string
  default = "base"
  validation {
    condition     = contains(["base", "k8s-node", "docker-host"], var.variant)
    error_message = "The variant must be 'base', 'k8s-node', or 'docker-host'."
  }
  description = "Box variant: base (minimal), k8s-node (Kubernetes), docker-host (Docker)"
}

// -----------------------------------------------------------------------------
// Kubernetes-specific (only used when variant = "k8s-node")
// -----------------------------------------------------------------------------
variable "kubernetes_version" {
  type        = string
  default     = "1.33.3"
  description = "Kubernetes version: major.minor (e.g., 1.33) installs latest patch, or major.minor.patch (e.g., 1.33.1) for specific version"
}

variable "container_runtime" {
  type    = string
  default = "containerd"
  validation {
    condition     = contains(["containerd", "cri-o", "docker"], var.container_runtime)
    error_message = "The container_runtime must be 'containerd', 'cri-o', or 'docker'."
  }
  description = "Container runtime: containerd or cri-o"
}

variable "crio_version" {
  type        = string
  default     = "1.33"
  description = "CRI-O version (only used if container_runtime=cri-o)"
}

// -----------------------------------------------------------------------------
// CNI-specific (used with k8s-node variant)
// -----------------------------------------------------------------------------
variable "cni_plugins_to_prepull" {
  type        = list(string)
  default     = ["calico", "flannel"]
  description = "A list of CNI plugins whose images will be pre-pulled (e.g., [\"calico\", \"flannel\"])."
}

variable "cni_registry_mirror" {
  type        = string
  default     = ""
  description = "Optional registry mirror to use for CNI images (e.g., 'myregistry.com')."
}

variable "cni_calico_version" {
  type        = string
  default     = "v3.27.3"
  description = "Version of Calico images to pre-pull."
}

variable "cni_flannel_version" {
  type        = string
  default     = "v0.25.1"
  description = "Version of the main Flannel image to pre-pull."
}

variable "cni_flannel_plugin_version" {
  type        = string
  default     = "v1.4.0-flannel1"
  description = "Version of the Flannel CNI plugin image to pre-pull."
}
