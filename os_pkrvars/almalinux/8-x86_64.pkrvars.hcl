os_name                 = "almalinux"
os_version              = "8.10"
os_arch                 = "x86_64"
iso_url                 = "https://repo.almalinux.org/almalinux/8/isos/x86_64/AlmaLinux-8.10-x86_64-boot.iso"
iso_checksum            = "file:https://repo.almalinux.org/almalinux/8/isos/x86_64/CHECKSUM"
vbox_guest_os_type      = "RedHat_64"
boot_command            = ["<wait><up><wait><tab><wait><end><wait> inst.ks=http://{{ .HTTPIP }}:{{ .HTTPPort }}/rhel/8ks.cfg inst.repo=https://repo.almalinux.org/almalinux/8/BaseOS/x86_64/os/ <wait><enter><wait>"]
