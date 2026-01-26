#!/usr/bin/env bats

# Tests for APT-related helpers in packer_templates/scripts/_common/lib-debian.sh

setup() {
  # Ensure libraries are available and source them
  [ -n "$LIB_CORE_SH" ]
  [ -n "$LIB_OS_SH" ]
  source "$LIB_CORE_SH"
  source "$LIB_OS_SH"

  # Fake tools to avoid real network/system changes
  export _APT_TEST_DIR=/tmp/apt-test
  rm -rf "${_APT_TEST_DIR}" && mkdir -p "${_APT_TEST_DIR}"/bin
  export PATH="${_APT_TEST_DIR}/bin:${PATH}"

  # Fake apt-get that logs invocations
  cat > "${_APT_TEST_DIR}/bin/apt-get" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "apt-get $*" >> /tmp/apt-test/log
# Simulate success regardless of subcommand
exit 0
EOF
  chmod +x "${_APT_TEST_DIR}/bin/apt-get"

  # Fake curl that outputs dummy content
  cat > "${_APT_TEST_DIR}/bin/curl" <<'EOF'
#!/usr/bin/env bash
cat <<DUMMY
dummykeydata
DUMMY
EOF
  chmod +x "${_APT_TEST_DIR}/bin/curl"

  # Fake gpg that writes stdin to -o <dest>
  cat > "${_APT_TEST_DIR}/bin/gpg" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
out=""
while [ $# -gt 0 ]; do
  case "$1" in
    -o)
      out="$2"; shift 2 ;;
    --dearmor)
      shift ;;
    *) shift ;;
  esac
done
cat > "$out"
EOF
  chmod +x "${_APT_TEST_DIR}/bin/gpg"

  # Reset log and env flags used by lib
  : > /tmp/apt-test/log
  unset APT_UPDATED_TS || true
  export APT_CACHE_INVALIDATED=0
  export APT_UPDATE_TTL=9999
}

teardown() {
  rm -rf "${_APT_TEST_DIR}" || true
}

count_updates() {
  local count
  count=$(grep -c "^apt-get update" /tmp/apt-test/log 2>/dev/null) || count=0
  echo "$count"
}

count_installs() {
  local count
  count=$(grep -c "^apt-get install" /tmp/apt-test/log 2>/dev/null) || count=0
  echo "$count"
}

last_install_line() {
  grep "^apt-get install" /tmp/apt-test/log | tail -n1
}

@test "ensure_apt_updated runs update once and respects TTL" {
  run bash -lc 'source "$LIB_CORE_SH"; source "$LIB_OS_SH"; lib::ensure_apt_updated; lib::ensure_apt_updated'
  [ "$status" -eq 0 ]
  [ "$(count_updates)" -eq 1 ]
}

@test "ensure_apt_source_file invalidates cache and forces next update" {
  # Pretend we just updated recently
  export APT_UPDATED_TS="$(date +%s)"
  export APT_CACHE_INVALIDATED=0
  : > /tmp/apt-test/log

  run bash -lc 'source "$LIB_CORE_SH"; source "$LIB_OS_SH"; lib::ensure_apt_source_file \
    "/etc/apt/sources.list.d/test-bats.list" \
    "deb [arch=amd64] http://example.invalid stable main"; lib::ensure_apt_updated'
  [ "$status" -eq 0 ]
  # Should have forced one update regardless of TTL
  [ "$(count_updates)" -ge 1 ]
}

@test "ensure_apt_key_from_url installs key and invalidates cache" {
  : > /tmp/apt-test/log
  run bash -lc 'source "$LIB_CORE_SH"; source "$LIB_OS_SH"; lib::ensure_apt_key_from_url \
    "https://example.invalid/key" \
    "/etc/apt/keyrings/test-bats.gpg"'
  [ "$status" -eq 0 ]
  [ -f /etc/apt/keyrings/test-bats.gpg ]

  run bash -lc 'source "$LIB_CORE_SH"; source "$LIB_OS_SH"; lib::ensure_apt_updated'
  [ "$status" -eq 0 ]
  [ "$(count_updates)" -ge 1 ]
}

@test "ensure_packages does one update and one bulk install" {
  : > /tmp/apt-test/log
  run bash -lc 'source "$LIB_CORE_SH"; source "$LIB_OS_SH"; lib::ensure_packages foo-bar-baz foo-bar-baz2 foo-bar-baz3'
  [ "$status" -eq 0 ]
  # Exactly one update and one install
  [ "$(count_updates)" -eq 1 ]
  [ "$(count_installs)" -eq 1 ]
  # All package names present in the single install line
  line="$(last_install_line)"
  [[ "$line" == *"foo-bar-baz"* ]]
  [[ "$line" == *"foo-bar-baz2"* ]]
  [[ "$line" == *"foo-bar-baz3"* ]]
}
