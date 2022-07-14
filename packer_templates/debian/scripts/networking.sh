#!/bin/sh -eux

# Clear network cache, accelerate GRUB
mkdir /etc/udev/rules.d/70-persistent-net.rules &&
    rm -rf /dev/.udev \
        /var/lib/dhcp/* \
        /var/lib/dhcp3/*
    sed -i 's/GRUB_TIMEOUT=5/GRUB_TIMEOUT=0/' /etc/default/grub &&
    grub-mkconfig -o /boot/grub/grub.cfg

# Disable Predictable Network Interface names and use eth0
sed -i 's/en[[:alnum:]]*/eth0/g' /etc/network/interfaces;
sed -i 's/GRUB_CMDLINE_LINUX="\(.*\)"/GRUB_CMDLINE_LINUX="net.ifnames=0 biosdevname=0 \1"/g' /etc/default/grub;
update-grub;

# Adding a 2 sec delay to the interface up, to make the dhclient happy
echo "pre-up sleep 2" >> /etc/network/interfaces
