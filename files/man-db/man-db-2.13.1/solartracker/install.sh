#!/bin/sh
################################################################################
# install.sh
#
# Setup the runtime environment for portable man-db
#
# Copyright (C) 2025 Richard Elwell
# Licensed under GPLv3 or later
################################################################################
PATH_CMD="$(readlink -f -- "$0")"
SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
PKG_ROOT="mandb"
PORTABLE_DIR="/tmp/portable-${PKG_ROOT}"

main() {
    if [ -n "${PATH_CMD}" ]; then
        echo "ERROR: This script must be sourced:"
        echo "source install.sh"
        echo "    -OR-"
        echo ". install.sh"
        echo ""
        return 1
    fi

    if [ ! -d "${PORTABLE_DIR}" ]; then
        ln -snf "${SCRIPT_DIR}" "${PORTABLE_DIR}"
    fi

    if ! contains_path "${PORTABLE_DIR}/libexec"; then
        export PATH="${PORTABLE_DIR}/libexec:${PATH}"
    fi

    if ! contains_path "${PORTABLE_DIR}/bin"; then
        export PATH="${PORTABLE_DIR}/bin:${PATH}"
    fi

    return 0
}

contains_path() {
    case ":${PATH}:" in
        *":${1}:"*) return 0 ;;
        *)          return 1 ;;
    esac
}

main

