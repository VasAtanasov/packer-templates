#!/usr/bin/env bats

setup() {
  export LIB_SH="/usr/local/lib/k8s/lib.sh"
}

@test "sshd configures cleanly (first run)" {
  run sudo env LIB_SH="$LIB_SH" bash /vagrant/packer_templates/scripts/_common/sshd.sh
  [ "$status" -eq 0 ]
}

@test "sshd is idempotent (second run)" {
  run sudo env LIB_SH="$LIB_SH" bash /vagrant/packer_templates/scripts/_common/sshd.sh
  [ "$status" -eq 0 ]
}

@test "ssh service is enabled and active" {
  run sudo systemctl is-enabled ssh
  [ "$status" -eq 0 ]
  run sudo systemctl is-active ssh
  [ "$status" -eq 0 ]
}

