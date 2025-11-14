os_name                 = "ubuntu"
os_version              = "25.04"
os_arch                 = "aarch64"
iso_url                 = "https://cdimage.ubuntu.com/releases/plucky/release/ubuntu-25.04-live-server-arm64.iso"
iso_checksum            = "file:https://cdimage.ubuntu.com/releases/plucky/release/SHA256SUMS"
vbox_guest_os_type      = "Ubuntu24_LTS_arm64"
boot_command = [
  "<wait>e<wait>",
  "<down><down><down><end>",
  " autoinstall ds=nocloud-net\\;s=http://{{.HTTPIP}}:{{.HTTPPort}}/ubuntu/",
  "<wait><f10><wait>",
]
