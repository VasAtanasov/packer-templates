// Debian 12 x86_64 Kubernetes Node Variant
// Based on debian-12-x86_64.pkrvars.hcl with K8s-specific configurations

os_name                 = "debian"
os_version              = "12.12"
os_arch                 = "x86_64"
iso_url                 = "https://cdimage.debian.org/cdimage/archive/latest-oldstable/amd64/iso-cd/debian-12.12.0-amd64-netinst.iso"
iso_checksum            = "file:https://cdimage.debian.org/cdimage/archive/latest-oldstable/amd64/iso-cd/SHA256SUMS"
vbox_guest_os_type      = "Debian12_64"
boot_command            = ["<wait><esc><wait>auto preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/debian/preseed.cfg netcfg/get_hostname={{ .Name }}<enter>"]

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
