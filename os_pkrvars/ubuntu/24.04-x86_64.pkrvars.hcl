os_name                 = "ubuntu"
os_version              = "24.04"
os_arch                 = "x86_64"
iso_url                 = "https://releases.ubuntu.com/noble/ubuntu-24.04.3-live-server-amd64.iso"
iso_checksum            = "file:https://releases.ubuntu.com/noble/SHA256SUMS"
vbox_guest_os_type      = "Ubuntu_64"
boot_command = [
  "<wait>e<wait>",
  "<down><down><down><end>",
  " autoinstall ds=nocloud-net\\;s=http://{{.HTTPIP}}:{{.HTTPPort}}/ubuntu/",
  "<wait><f10><wait>",
]
