os_name            = "debian"
os_version         = "13.3"
os_arch            = "x86_64"
iso_url            = "https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.3.0-amd64-netinst.iso"
iso_checksum       = "file:https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/SHA256SUMS"
variant            = "base"
vbox_guest_os_type = "Debian_64"
boot_command = [
  "<wait>",
  "<esc><wait>",
  "auto preseed/url=http://{{ .HTTPIP }}:{{ .HTTPPort }}/preseed.cfg netcfg/get_hostname={{ .Name }}",
  "<enter>",
]
