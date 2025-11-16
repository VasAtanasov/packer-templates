os_name                 = "almalinux"
os_version              = "10.0"
os_arch                 = "x86_64"
iso_url                 = "https://repo.almalinux.org/almalinux/10/isos/x86_64/AlmaLinux-10.0-x86_64-dvd.iso"
iso_checksum            = "file:https://repo.almalinux.org/almalinux/10/isos/x86_64/CHECKSUM"
vbox_guest_os_type      = "RedHat_64"
boot_command = [
  "<wait10>",
  "<up><wait>",
  "e<wait3>",
  "<down><down><end>",
  "<bs><bs><bs><bs><bs>",
  " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg",
  " ip=dhcp rd.neednet=1",
  "<f10><wait>",
]
