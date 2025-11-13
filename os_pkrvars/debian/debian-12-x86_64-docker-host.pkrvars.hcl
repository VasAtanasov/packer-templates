// Debian 12 x86_64 Docker Host Variant
// Based on debian-12-x86_64.pkrvars.hcl with Docker-specific configurations

os_name                 = "debian"
os_version              = "12.12"
os_arch                 = "x86_64"
iso_url                 = "https://cdimage.debian.org/cdimage/archive/latest-oldstable/amd64/iso-cd/debian-12.12.0-amd64-netinst.iso"
iso_checksum            = "file:https://cdimage.debian.org/cdimage/archive/latest-oldstable/amd64/iso-cd/SHA256SUMS"
vbox_guest_os_type      = "Debian12_64"
boot_command            = ["<wait><esc><wait>auto preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/debian/preseed.cfg netcfg/get_hostname={{ .Name }}<enter>"]

// Docker hosts need reasonable resources
cpus                    = 2
memory                  = 2048  // 2GB RAM
disk_size               = 40960 // 40GB disk

// Variant configuration
variant                 = "docker-host"
