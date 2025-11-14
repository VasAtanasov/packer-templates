#!/usr/bin/env bash
set -o pipefail
# Wrapper for Debian/Ubuntu to run common implementation
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$DIR/../common/install_dependencies.sh" "$@"

