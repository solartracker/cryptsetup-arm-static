#!/bin/sh
################################################################################
# install.sh
#
# Setup the runtime environment for portable man-db.  This script should be
# sourced once inside every shell instance before using the man program.  It
# configures the PATH variable and creates a symbolic link to its own portable
# sysroot.
#
# Copyright (C) 2025 Richard Elwell
# Licensed under GPLv3 or later
################################################################################
SCRIPTNAME="install.sh"
PKG_ROOT="man"

if [ "$(basename -- "$0")" = "$SCRIPTNAME" ]; then
    echo "ERROR: This script must be sourced:"
    echo ""
    echo "source install.sh"
    echo "    -OR-"
    echo ". install.sh"
    echo ""
    echo ""
    exit 1
fi

contains_path() {
    case ":${PATH}:" in
        *":${1}:"*) return 0 ;;
        *)          return 1 ;;
    esac
}

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd -P)"
PORTABLE_DIR="/tmp/portable-${PKG_ROOT}"

if [ ! -d "${PORTABLE_DIR}" ]; then
    ln -snf "${SCRIPT_DIR}" "${PORTABLE_DIR}"
fi

if ! contains_path "${PORTABLE_DIR}/libexec"; then
    export PATH="${PORTABLE_DIR}/libexec:${PATH}"
fi

if ! contains_path "${PORTABLE_DIR}/bin"; then
    export PATH="${PORTABLE_DIR}/bin:${PATH}"
fi

