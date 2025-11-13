// Debian 12 aarch64 Kubernetes Node Variant
// Based on debian-12-aarch64.pkrvars.hcl with K8s-specific configurations

os_name                 = "debian"
os_version              = "12.12"
os_arch                 = "aarch64"
iso_url                 = "https://cdimage.debian.org/cdimage/archive/latest-oldstable/arm64/iso-cd/debian-12.12.0-arm64-netinst.iso"
iso_checksum            = "file:https://cdimage.debian.org/cdimage/archive/latest-oldstable/arm64/iso-cd/SHA256SUMS"
vbox_guest_os_type      = "Debian12_arm64"
boot_command            = ["<wait>e<wait><down><down><down><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><right><wait>install <wait> preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/debian/preseed.cfg <wait>debian-installer=en_US.UTF-8 <wait>auto <wait>locale=en_US.UTF-8 <wait>kbd-chooser/method=us <wait>keyboard-configuration/xkb-keymap=us <wait>netcfg/get_hostname={{ .Name }} <wait>netcfg/get_domain=vagrantup.com <wait>fb=false <wait>debconf/frontend=noninteractive <wait>console-setup/ask_detect=false <wait>console-keymaps-at/keymap=us <wait>grub-installer/bootdev=default <wait><f10><wait>"]

// K8s nodes need more resources than base boxes
cpus                    = 2
memory                  = 4096   // 4GB RAM for Kubernetes
disk_size               = 61440  // 60GB disk

// Variant configuration
variant                 = "k8s-node"

// Kubernetes configuration
kubernetes_version      = "1.33"
container_runtime       = "containerd"  // or "cri-o"
crio_version            = "1.33"        // only used if container_runtime=cri-o
