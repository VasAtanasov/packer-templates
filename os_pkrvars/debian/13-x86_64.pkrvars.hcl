// Debian 13 x86_64 Configuration
// Use with: packer build -var-file=os_pkrvars/debian/13-x86_64.pkrvars.hcl packer_templates/virtualbox/debian/
//
// Variants (pass via -var flags):
//   Base:        (default)
//   K8s node:    -var='variant=k8s-node' -var='kubernetes_version=1.33' -var='cpus=2' -var='memory=4096' -var='disk_size=61440'
//   Docker host: -var='variant=docker-host'

os_name    = "debian"
os_version = "13.1"
os_arch    = "x86_64"

iso_url      = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.1.0-amd64-netinst.iso"
iso_checksum = "file:https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA256SUMS"

vbox_guest_os_type = "Debian12_64"
boot_command       = ["<wait><esc><wait>auto preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg netcfg/get_hostname={{ .Name }}<enter>"]

// Default resources (override via -var flags for variants)
cpus      = 2
memory    = 2048
disk_size = 40960

// Default to base variant (override via -var='variant=k8s-node')
variant = "base"
