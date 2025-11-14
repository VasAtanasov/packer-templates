#!/usr/bin/env bash
set -o pipefail
# Wrapper for OpenSUSE to run common implementation (placeholder; will be specialized later)
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$DIR/../common/guest_additions.sh" "$@"

