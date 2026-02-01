#!/usr/bin/env bash

set -o pipefail

source "${LIB_CORE_SH}"
source "${LIB_OS_SH}"

lib::strict
lib::setup_traps
lib::require_root

readonly LAZYDOCKER_VERSION="0.24.4"
readonly LAZYDOCKER_SHA256_AMD64="c47e6f4b61debde5422183c7eb446a704a92c58b4c35bbd128c722d8bf269a86"

get_installed_version() {
    if ! command -v lazydocker >/dev/null 2>&1; then
        return 1
    fi

    local version_output
    version_output="$(lazydocker --version 2>/dev/null || true)"
    if [ -z "$version_output" ]; then
        return 1
    fi

    grep -Eo "[0-9]+\.[0-9]+\.[0-9]+" <<<"$version_output" | head -n1
}

main() {
    lib::header "Installing lazydocker"
    export DEBIAN_FRONTEND=noninteractive

    local installed_version
    installed_version="$(get_installed_version || true)"
    if [ "$installed_version" = "$LAZYDOCKER_VERSION" ]; then
        lib::log "lazydocker ${LAZYDOCKER_VERSION} already installed"
        return 0
    fi

    lib::ensure_apt_updated
    lib::ensure_packages \
        ca-certificates \
        curl \
        tar

    local arch
    arch="$(dpkg --print-architecture)"

    local archive_name
    local archive_sha256
    case "$arch" in
        amd64)
            archive_name="lazydocker_${LAZYDOCKER_VERSION}_Linux_x86_64.tar.gz"
            archive_sha256="$LAZYDOCKER_SHA256_AMD64"
            ;;
        *)
            lib::error "Unsupported architecture for lazydocker: ${arch}"
            return 1
            ;;
    esac

    local tmp_dir
    tmp_dir="/tmp/lazydocker-install"
    lib::ensure_directory "$tmp_dir"

    local archive_path
    archive_path="${tmp_dir}/${archive_name}"

    local download_url
    download_url="https://github.com/jesseduffield/lazydocker/releases/download/v${LAZYDOCKER_VERSION}/${archive_name}"

    lib::ensure_downloaded "$download_url" "$archive_path" "$archive_sha256"

    tar -xzf "$archive_path" -C "$tmp_dir"

    if [ ! -f "${tmp_dir}/lazydocker" ]; then
        lib::error "lazydocker binary not found after extraction"
        return 1
    fi

    install -m 0755 "${tmp_dir}/lazydocker" /usr/local/bin/lazydocker
    rm -rf "$tmp_dir"

    lib::verify_commands lazydocker

    local new_version
    new_version="$(lazydocker --version 2>/dev/null || true)"
    if [ -n "$new_version" ]; then
        lib::success "lazydocker installed: ${new_version}"
    else
        lib::success "lazydocker ${LAZYDOCKER_VERSION} installed"
    fi
}

main "$@"
