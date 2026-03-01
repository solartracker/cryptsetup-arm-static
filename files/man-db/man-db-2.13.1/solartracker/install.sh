#!/bin/sh
################################################################################
# install.sh
#
# Setup the runtime environment for portable man-db
#
# Copyright (C) 2025 Richard Elwell
# Licensed under GPLv3 or later
################################################################################
SCRIPT_DIR="$(dirname -- "$(readlink -f -- "$0")")"
PKG_ROOT="mandb"
PORTABLE_DIR="/tmp/portable-${PKG_ROOT}"
set -e
set -x

main() {
    if [ ! -d "${PORTABLE_DIR}" ]; then
        ln -snf "${SCRIPT_DIR}" "${PORTABLE_DIR}"
    fi

    if ! contains "${PATH}" "${PORTABLE_DIR}/libexec"; then
        export PATH="${PORTABLE_DIR}/libexec:${PATH}"
    fi

    if ! contains "${PATH}" "${PORTABLE_DIR}/bin"; then
        export PATH="${PORTABLE_DIR}/bin:${PATH}"
    fi

    return 0
}

contains() {
    case "$1" in
        *"$2"*) return 0 ;;
        *)      return 1 ;;
    esac
}

main

