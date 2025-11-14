os_name                 = "ubuntu"
os_version              = "22.04"
os_arch                 = "x86_64"
iso_url                 = "https://releases.ubuntu.com/jammy/ubuntu-22.04.5-live-server-amd64.iso"
iso_checksum            = "file:https://releases.ubuntu.com/jammy/SHA256SUMS"
vbox_guest_os_type      = "Ubuntu_64"
boot_command = [
  "<wait>c<wait>",
  "set gfxpayload=keep",
  "<enter><wait>",
  "linux /casper/vmlinuz quiet autoinstall ds=nocloud-net\\;s=http://{{.HTTPIP}}:{{.HTTPPort}}/ubuntu/ ---",
  "<enter><wait>",
  "initrd /casper/initrd",
  "<wait><enter><wait>",
  "boot",
  "<enter><wait>",
]
