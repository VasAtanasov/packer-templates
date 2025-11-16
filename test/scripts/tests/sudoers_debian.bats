#!/usr/bin/env bats

setup() {
  export SCRIPTS_DIR="${SCRIPTS_DIR:-/scripts}"
  export LIB_CORE_SH="${LIB_CORE_SH:-/usr/local/lib/scripts/_common/lib-core.sh}"
  export LIB_OS_SH="${LIB_OS_SH:-/usr/local/lib/scripts/_common/lib-debian.sh}"
  export LIB_DIR="${LIB_DIR:-/usr/local/lib/scripts}"
}

@test "sudoers.sh applies settings (first run)" {
  run sudo env LIB_CORE_SH="$LIB_CORE_SH" LIB_OS_SH="$LIB_OS_SH" LIB_DIR="$LIB_DIR" bash "$SCRIPTS_DIR/debian/sudoers.sh"
  [ "$status" -eq 0 ]
}

@test "sudoers.sh is idempotent (second run)" {
  run sudo env LIB_CORE_SH="$LIB_CORE_SH" LIB_OS_SH="$LIB_OS_SH" LIB_DIR="$LIB_DIR" bash "$SCRIPTS_DIR/debian/sudoers.sh"
  [ "$status" -eq 0 ]
}

@test "sudoers has secure_path and vagrant sudoers file" {
  run sudo grep -q 'secure_path' /etc/sudoers
  [ "$status" -eq 0 ]
  run sudo test -f /etc/sudoers.d/vagrant
  [ "$status" -eq 0 ]
  # Ensure permissions are 0440
  run sudo bash -c '[ "$(stat -c %a /etc/sudoers.d/vagrant)" = "440" ]'
  [ "$status" -eq 0 ]
}

@test "legacy 99_vagrant file is absent" {
  run sudo test ! -e /etc/sudoers.d/99_vagrant
  [ "$status" -eq 0 ]
}

@test "sudoers vagrant entry is canonical" {
  # File contains exactly one canonical line
  run sudo bash -c 'wc -l < /etc/sudoers.d/vagrant'
  [ "$status" -eq 0 ]
  [ "$output" -eq 1 ]
  run sudo grep -qxF 'vagrant ALL=(ALL) NOPASSWD:ALL' /etc/sudoers.d/vagrant
  [ "$status" -eq 0 ]
  # Ownership root:root
  run sudo bash -c 'test "$(stat -c %U:%G /etc/sudoers.d/vagrant)" = "root:root"'
  [ "$status" -eq 0 ]
}
