#!/bin/sh -eux

# Only add the secure path line if it is not already present
grep -q 'secure_path' /etc/sudoers \
  || sed -i -e '/Defaults\s\+env_reset/a Defaults\tsecure_path="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"' /etc/sudoers

# Canonical sudoers file for the vagrant user
sudoers_file="/etc/sudoers.d/vagrant"

# Write NOPASSWD rule idempotently
printf '%s\n' 'vagrant ALL=(ALL) NOPASSWD:ALL' >"${sudoers_file}"
chmod 0440 "${sudoers_file}"
chown root:root "${sudoers_file}"

# Cleanup legacy file if present
rm -f /etc/sudoers.d/99_vagrant
