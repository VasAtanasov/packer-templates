os_name            = "almalinux"
os_version         = "9.6"
os_arch            = "x86_64"
iso_url            = "https://repo.almalinux.org/almalinux/9.6/isos/x86_64/AlmaLinux-9.6-x86_64-boot.iso"
iso_checksum       = "file:https://repo.almalinux.org/almalinux/9.6/isos/x86_64/CHECKSUM"
variant            = "base"
vbox_guest_os_type = "RedHat_64"
boot_command = [
  "<wait>",
  "<up><wait><tab><wait><end><wait>",
  " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg",
  " ip=dhcp",
  " rd.neednet=1",
  " inst.repo=https://repo.almalinux.org/almalinux/9/BaseOS/x86_64/os/",
  "<wait><enter><wait>",
]
