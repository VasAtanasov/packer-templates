os_name                 = "centos-stream"
os_version              = "9"
os_arch                 = "x86_64"
iso_url                 = "https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-latest-x86_64-boot.iso"
iso_checksum            = "file:https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/iso/CentOS-Stream-9-latest-x86_64-boot.iso.SHA256SUM"
vbox_guest_os_type      = "RedHat_64"
boot_command = [
  "<wait>",
  "<up><wait><tab><wait><end><wait>",
  " inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/rhel/ks.cfg",
  " inst.repo=https://mirror.stream.centos.org/9-stream/BaseOS/x86_64/os/ ",
  "<wait><enter><wait>",
]
