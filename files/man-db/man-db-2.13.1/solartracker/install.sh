#!/bin/sh
################################################################################
# install.sh
#
# Setup the runtime environment for portable man-db
#
# Must be sourced:
#   . install.sh
#        -OR-
#   source install.sh
#
# Copyright (C) 2025 Richard Elwell
# Licensed under GPLv3 or later
################################################################################
(return 0 2>/dev/null) || {
    echo "ERROR: This script must be sourced:"
    echo "  . install.sh"
    echo "  source install.sh"
    exit 1
}

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
PKG_ROOT="mandb"
PORTABLE_DIR="/tmp/portable-${PKG_ROOT}"

contains_path() {
    case ":${PATH}:" in
        *":${1}:"*) return 0 ;;
        *)          return 1 ;;
    esac
}

if [ ! -d "${PORTABLE_DIR}" ]; then
    ln -snf "${SCRIPT_DIR}" "${PORTABLE_DIR}"
fi

if ! contains_path "${PORTABLE_DIR}/libexec"; then
    PATH="${PORTABLE_DIR}/libexec:${PATH}"
fi

if ! contains_path "${PORTABLE_DIR}/bin"; then
    PATH="${PORTABLE_DIR}/bin:${PATH}"
fi

export PATH

