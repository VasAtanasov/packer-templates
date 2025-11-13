#!/usr/bin/env bats

setup() {
  export SCRIPTS_DIR="${SCRIPTS_DIR:-/scripts}"
  export LIB_SH="${LIB_SH:-/usr/local/lib/k8s/lib.sh}"
  export LIB_DIR="${LIB_DIR:-/usr/local/lib/k8s}"
}

@test "sshd configures cleanly (first run)" {
  run sudo env LIB_SH="$LIB_SH" LIB_DIR="$LIB_DIR" bash "$SCRIPTS_DIR/_common/sshd.sh"
  [ "$status" -eq 0 ]
}

@test "sshd is idempotent (second run)" {
  run sudo env LIB_SH="$LIB_SH" LIB_DIR="$LIB_DIR" bash "$SCRIPTS_DIR/_common/sshd.sh"
  [ "$status" -eq 0 ]
}

@test "ssh service is enabled and active" {
  run sudo systemctl is-enabled ssh
  [ "$status" -eq 0 ]
  run sudo systemctl is-active ssh
  [ "$status" -eq 0 ]
}

