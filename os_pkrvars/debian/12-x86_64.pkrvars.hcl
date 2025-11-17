os_name            = "debian"
os_version         = "12.12"
os_arch            = "x86_64"
iso_url            = "https://cdimage.debian.org/cdimage/archive/latest-oldstable/amd64/iso-cd/debian-12.12.0-amd64-netinst.iso"
iso_checksum       = "file:https://cdimage.debian.org/cdimage/archive/latest-oldstable/amd64/iso-cd/SHA256SUMS"
variant            = "base"
vbox_guest_os_type = "Debian12_64"
boot_command = [
  "<wait>",
  "<esc><wait>",
  "auto preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg netcfg/get_hostname={{ .Name }}",
  "<enter>",
]
