os_name                 = "almalinux"
os_version              = "9.6"
os_arch                 = "aarch64"
iso_url                 = "https://repo.almalinux.org/almalinux/9/isos/aarch64/AlmaLinux-9.6-aarch64-boot.iso"
iso_checksum            = "file:https://repo.almalinux.org/almalinux/9/isos/aarch64/CHECKSUM"
vbox_guest_os_type      = "Oracle9_arm64"
boot_command            = ["<wait><up><wait><tab><wait><end><wait> inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/ks.cfg ip=dhcp rd.neednet=1 inst.repo=https://repo.almalinux.org/almalinux/9/BaseOS/aarch64/os/ <wait><enter><wait>"]
