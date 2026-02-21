#!/bin/bash
################################################################################
# cryptsetup-arm-musl.sh
#
# Copyright (C) 2025 Richard Elwell
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
################################################################################

main() {
PKG_ROOT=cryptsetup
PKG_ROOT_VERSION="2.8.4"
PKG_ROOT_RELEASE=1
PKG_TARGET_CPU=armv7
PKG_TARGET_VARIANT=_musl
#PKG_TARGET_VARIANT=_musl+debug

CROSSBUILD_SUBDIR="cross-arm-linux-musleabi-build"
CROSSBUILD_DIR="${PARENT_DIR}/${CROSSBUILD_SUBDIR}"
export TARGET=arm-linux-musleabi
TARGET_DIR="${CROSSBUILD_DIR}/${TARGET}"

HOST_CPU="$(uname -m)"
SYSROOT="${TARGET_DIR}/sysroot"
export PREFIX="${SYSROOT}"
export HOST=${TARGET}

CROSS_PREFIX=${TARGET}-
export CC=${CROSS_PREFIX}gcc
export CXX=${CROSS_PREFIX}g++
export AR=${CROSS_PREFIX}ar
export LD=${CROSS_PREFIX}ld
export RANLIB=${CROSS_PREFIX}ranlib
export OBJCOPY=${CROSS_PREFIX}objcopy
export STRIP=${CROSS_PREFIX}strip
export READELF=${CROSS_PREFIX}readelf

CFLAGS_COMMON="-O3 -march=armv7-a -mtune=cortex-a9 -marm -mfloat-abi=soft -mabi=aapcs-linux -fomit-frame-pointer -ffunction-sections -fdata-sections -pipe -Wall -fPIC"

#CFLAGS_COMMON="-g3 -ggdb3 -O0 -fno-omit-frame-pointer -fno-inline -march=armv7-a -mtune=cortex-a9 -marm -mfloat-abi=soft -mabi=aapcs-linux -ffunction-sections -fdata-sections -pipe -Wall -fPIC"

export CFLAGS="${CFLAGS_COMMON} -std=gnu99"
export CXXFLAGS="${CFLAGS_COMMON} -std=gnu++17"
export LDFLAGS="-L${PREFIX}/lib -Wl,--gc-sections"
export CPPFLAGS="-I${PREFIX}/include -D_GNU_SOURCE"

case "${HOST_CPU}" in
    armv7l)
        ARCH_NATIVE=true
        ;;
    *)
        ARCH_NATIVE=false
        ;;
esac

SRC_ROOT="${CROSSBUILD_DIR}/src/${PKG_ROOT}"
STAGE_DIR="${CROSSBUILD_DIR}/stage/${PKG_ROOT}"
PACKAGER_NAME="${PKG_ROOT}_${PKG_ROOT_VERSION}-${PKG_ROOT_RELEASE}_${PKG_TARGET_CPU}${PKG_TARGET_VARIANT}"
PACKAGER_ROOT="${CROSSBUILD_DIR}/packager/${PKG_ROOT}/${PACKAGER_NAME}"
PACKAGER_TOPDIR="${PACKAGER_ROOT}/${PKG_ROOT}-${PKG_ROOT_VERSION}"

MAKE="make -j$(grep -c ^processor /proc/cpuinfo)" # parallelism
#MAKE="make -j1"                                  # one job at a time

export PKG_CONFIG="pkg-config"
export PKG_CONFIG_LIBDIR="${PREFIX}/lib/pkgconfig"
unset PKG_CONFIG_PATH

install_build_environment

download_and_compile

create_install_package

return 0
} #END main()

################################################################################
# Create install package
#
create_install_package() {

echo ""
echo "[*] Creating install package..."
rm -rf "${PACKAGER_ROOT}"
exit 1
mkdir -p "${PACKAGER_TOPDIR}/sbin"
mkdir -p "${PACKAGER_TOPDIR}/bin"
mkdir -p "${PACKAGER_TOPDIR}/usr/bin"
cp -p "${SCRIPT_DIR}/files/ntpsec/ntpsec-1.2.4/solartracker/${TARGET}/ntpq.sh" "${PACKAGER_TOPDIR}/"
cp -p "${SCRIPT_DIR}/files/python/python-3.10.19/solartracker/python3.10-wrapper" "${PACKAGER_TOPDIR}/bin/"
cp -p "${SCRIPT_DIR}/files/python/python-3.14.3/solartracker/python3.14-wrapper" "${PACKAGER_TOPDIR}/bin/"
cp -a "${PREFIX}/bin/python3"* "${PACKAGER_TOPDIR}/bin/"
cp -a "${PREFIX}/lib/python3"* "${PACKAGER_TOPDIR}/lib/"
cp -a "${PREFIX}/lib/libntpc.so"* "${PACKAGER_TOPDIR}/lib/"
cp -p "${PREFIX}/lib/libc.so" "${PACKAGER_TOPDIR}/lib/"
cp -p "${PREFIX}/bin/ntpq" "${PACKAGER_TOPDIR}/bin/"
cp -p "${PREFIX}/sbin/ntpd" "${PACKAGER_TOPDIR}/sbin/"
cp -p "${PREFIX}/sbin/capsh" "${PACKAGER_TOPDIR}/sbin/"
cp -p "${PREFIX}/sbin/getcap" "${PACKAGER_TOPDIR}/sbin/"
cp -p "${PREFIX}/sbin/getpcaps" "${PACKAGER_TOPDIR}/sbin/"
cp -p "${PREFIX}/sbin/setcap" "${PACKAGER_TOPDIR}/sbin/"
cp -p "${PREFIX}/usr/bin/ppsfind" "${PACKAGER_TOPDIR}/usr/bin/"
cp -p "${PREFIX}/usr/bin/ppstest" "${PACKAGER_TOPDIR}/usr/bin/"
cp -p "${PREFIX}/usr/bin/ppsctl" "${PACKAGER_TOPDIR}/usr/bin/"
cp -p "${PREFIX}/usr/bin/ppswatch" "${PACKAGER_TOPDIR}/usr/bin/"
cp -p "${PREFIX}/usr/bin/ppsldisc" "${PACKAGER_TOPDIR}/usr/bin/"
cp -p "${PREFIX}/bin/openssl" "${PACKAGER_TOPDIR}/bin/"
add_items_to_install_package "${PREFIX}/sbin/ntpd"

return 0
} #END create_install_package()

################################################################################
# Host dependencies
#
check_dependencies()
( # BEGIN sub-shell
    set +x
    install_dependencies || return 1
    #install_python_dependencies || return 1
    return 0
) # END sub-shell

prompt_install_choice() {
    echo
    echo "Host dependencies are missing or outdated."
    echo "Choose an action:"
    echo "  [y] Install now"
    echo "  [n] Do not install (abort build)"
    echo

    read -r -p "Selection [y/n]: " choice

    case "$choice" in
        y|Y)
            return 0
            ;;
        n|N)
            return 1
            ;;
        *)
            echo "Invalid selection."
            return 1
            ;;
    esac
    return 0
}

install_dependencies() {

    # list each package and optional minimum version
    # example: "build-essential 12.9"
    local dependencies=(
        "build-essential"
        "binutils"
        "bison"
        "flex"
        "texinfo"
        "gawk"
        "perl"
        "patch"
        "file"
        "wget"
        "curl"
        "git"
        "tar"
        "libgmp-dev"
        "libmpfr-dev"
        "libmpc-dev"
        "libisl-dev"
        "zlib1g-dev"
        "cmake"
        "libc6-dev"
        "libbsd-dev"
        "pkg-config"
        "m4"
        "asciidoctor"
    )
    local to_install=()

    echo "[*] Checking dependencies..."
    for entry in "${dependencies[@]}"; do
        local pkg min_version installed_version
        read -r pkg min_version <<< "$entry"

        if installed_version="$(dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null)"; then
            if [ -n "$min_version" ]; then
                if dpkg --compare-versions "$installed_version" ge "$min_version"; then
                    echo "[*] $pkg $installed_version is OK."
                else
                    echo "[*] $pkg $installed_version is too old (min $min_version)."
                    to_install+=("$pkg")
                fi
            else
                echo "[*] $pkg is installed."
            fi
        else
            echo "[*] $pkg is missing."
            to_install+=("$pkg")
        fi
    done

    if [ "${#to_install[@]}" -eq 0 ]; then
        echo "[*] All dependencies satisfied."
        return 0
    fi

    if ! prompt_install_choice; then
        return 1
    fi

    echo "[*] Installing dependencies: ${to_install[*]}"
    sudo apt-get update
    sudo apt-get install -y "${to_install[@]}"

    return 0
}

install_python_dependencies() {

    local missing=0

    echo "[*] Checking Python dependencies..."

    if ! python3 -m cx_Freeze --version >/dev/null 2>&1; then
        echo "[*] cx_Freeze is missing."
        missing=1
    else
        echo "[*] cx_Freeze is installed."
    fi

    if [ "$missing" -eq 0 ]; then
        return 0
    fi

    if ! prompt_install_choice; then
        return 1
    fi

    echo "[*] Installing cx_Freeze via pip..."
    python3 -m pip install --user cx_Freeze || return 1

    return 0
}

################################################################################
# CMake toolchain file
#
create_cmake_toolchain_file() {
mkdir -p "${SRC_ROOT}"

# CMAKE options
CMAKE_BUILD_TYPE="RelWithDebInfo"
CMAKE_VERBOSE_MAKEFILE="YES"
CMAKE_C_FLAGS="${CFLAGS}"
CMAKE_CXX_FLAGS="${CXXFLAGS}"
CMAKE_LD_FLAGS="${LDFLAGS}"
CMAKE_CPP_FLAGS="${CPPFLAGS}"

{
    printf '%s\n' "# toolchain.cmake"
    printf '%s\n' "set(CMAKE_SYSTEM_NAME Linux)"
    printf '%s\n' "set(CMAKE_SYSTEM_PROCESSOR arm)"
    printf '%s\n' ""
    printf '%s\n' "# Cross-compiler"
    printf '%s\n' "set(CMAKE_C_COMPILER \"${CC}\")"
    printf '%s\n' "set(CMAKE_CXX_COMPILER \"${CXX}\")"
    printf '%s\n' "set(CMAKE_AR \"${AR}\")"
    printf '%s\n' "set(CMAKE_RANLIB \"${RANLIB}\")"
    printf '%s\n' "set(CMAKE_STRIP \"${STRIP}\")"
    printf '%s\n' ""
#    printf '%s\n' "# Optional: sysroot"
#    printf '%s\n' "set(CMAKE_SYSROOT \"${SYSROOT}\")"
    printf '%s\n' ""
#    printf '%s\n' "# Avoid picking host libraries"
#    printf '%s\n' "set(CMAKE_FIND_ROOT_PATH \"${PREFIX}\")"
    printf '%s\n' ""
#    printf '%s\n' "# Tell CMake to search only in sysroot"
#    printf '%s\n' "set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)"
#    printf '%s\n' "set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)"
#    printf '%s\n' "set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)"
    printf '%s\n' ""
#    printf '%s\n' "set(CMAKE_TRY_COMPILE_TARGET_TYPE STATIC_LIBRARY) # critical for skipping warning probes"
#    printf '%s\n' ""
    printf '%s\n' "set(CMAKE_C_STANDARD 11)"
    printf '%s\n' "set(CMAKE_CXX_STANDARD 17)"
    printf '%s\n' ""
} >"${SRC_ROOT}/arm-musl.toolchain.cmake"

return 0
} #END create_cmake_toolchain_file()

################################################################################
# Helpers

# If autoconf/configure fails due to missing libraries or undefined symbols, you
# immediately see all undefined references without having to manually search config.log
handle_configure_error()
( # BEGIN sub-shell
    set +x
    local rc=$1
    local config_log_file="$2"

    if [ -z "${config_log_file}" ] || [ ! -f "${config_log_file}" ]; then
        config_log_file="config.log"
    fi

    #grep -R --include="config.log" --color=always "undefined reference" .
    #find . -name "config.log" -exec grep -H "undefined reference" {} \;
    #find . -name "config.log" -exec grep -H -E "undefined reference|can't load library|unrecognized command-line option|No such file or directory" {} \;
    find . -name "config.log" -exec grep -H -E "undefined reference|can't load library|unrecognized command-line option" {} \;

    # Force failure if rc is zero, since error was detected
    [ "${rc}" -eq 0 ] && return 1

    return ${rc}
) # END sub-shell

################################################################################
# Package management

# new files:       rw-r--r-- (644)
# new directories: rwxr-xr-x (755)
umask 022

sign_file()
( # BEGIN sub-shell
    [ -n "$1" ]            || return 1

    local target_path="$1"
    local option="$2"
    local sum_path="$(readlink -f "${target_path}").sum"
    local target_file="$(basename -- "${target_path}")"
    local target_file_hash=""
    local temp_path=""
    local now_localtime=""

    if [ ! -f "${target_path}" ]; then
        echo "ERROR: File not found: ${target_path}"
        return 1
    fi

    if [ -z "${option}" ]; then
        target_file_hash="$(sha256sum "${target_path}" | awk '{print $1}')"
    elif [ "${option}" = "full_extract" ]; then
        target_file_hash="$(hash_archive "${target_path}")"
    elif [ "${option}" = "xz_extract" ]; then
        target_file_hash="$(xz -dc "${target_path}" | sha256sum | awk '{print $1}')"
    else
        return 1
    fi

    now_localtime="$(date '+%Y-%m-%d %H:%M:%S %Z %z')"

    cleanup() { rm -f "${temp_path}"; }
    trap 'cleanup; exit 130' INT
    trap 'cleanup; exit 143' TERM
    trap 'cleanup' EXIT
    temp_path=$(mktemp "${sum_path}.XXXXXX")
    {
        #printf '%s released %s\n' "${target_file}" "${now_localtime}"
        #printf '\n'
        #printf 'SHA256: %s\n' "${target_file_hash}"
        #printf '\n'
        printf '%s  %s\n' "${target_file_hash}" "${target_file}"
    } >"${temp_path}" || return 1
    chmod --reference="${target_path}" "${temp_path}" || return 1
    touch -r "${target_path}" "${temp_path}" || return 1
    mv -f "${temp_path}" "${sum_path}" || return 1
    trap - EXIT INT TERM

    return 0
) # END sub-shell

hash_dir()
( # BEGIN sub-shell
    [ -n "$1" ] || return 1

    dir_path="$1"

    cleanup() { :; }
    trap 'cleanup; exit 130' INT
    trap 'cleanup; exit 143' TERM
    trap 'cleanup' EXIT
    cd "${dir_path}" || return 1
    (
        find ./ -type f | sort | while IFS= read -r f; do
            set +x
            echo "${f}"        # include the path
            cat "${f}"         # include the contents
        done
    ) | sha256sum | awk '{print $1}'

    return 0
) # END sub-shell

hash_archive()
( # BEGIN sub-shell
    [ -n "$1" ] || return 1

    source_path="$1"
    target_dir="$(dirname "${source_path}")"
    target_file="$(basename "${source_path}")"

    cd "${target_dir}" || return 1

    cleanup() { rm -rf "${dir_tmp}"; }
    trap 'cleanup; exit 130' INT
    trap 'cleanup; exit 143' TERM
    trap 'cleanup' EXIT
    dir_tmp=$(mktemp -d "${target_file}.XXXXXX")
    mkdir -p "${dir_tmp}"
    if ! extract_package "${source_path}" "${dir_tmp}" >/dev/null 2>&1; then
        return 1
    else
        hash_dir "${dir_tmp}"
    fi

    return 0
) # END sub-shell

# Checksum verification for downloaded file
verify_hash() {
    [ -n "$1" ] || return 1

    local source_path="$1"
    local expected="$2"
    local option="$3"
    local actual=""
    local sum_path="$(readlink -f "${source_path}").sum"
    local line=""

    if [ ! -f "${source_path}" ]; then
        echo "ERROR: File not found: ${source_path}"
        return 1
    fi

    if [ -z "${option}" ]; then
        # hash the compressed binary archive itself
        actual="$(sha256sum "${source_path}" | awk '{print $1}')"
    elif [ "${option}" = "full_extract" ]; then
        # hash the data inside the compressed binary archive
        actual="$(hash_archive "${source_path}")"
    elif [ "${option}" = "xz_extract" ]; then
        # hash the data, file names, directory names, timestamps, permissions, and
        # tar internal structures. this method is not as "future-proof" for archiving
        # Github repos because it is possible that the tar internal structures
        # could change over time as the tar implementations evolve.
        actual="$(xz -dc "${source_path}" | sha256sum | awk '{print $1}')"
    else
        return 1
    fi

    if [ -z "${expected}" ]; then
        if [ ! -f "${sum_path}" ]; then
            echo "ERROR: Signature file not found: ${sum_path}"
            return 1
        else
            IFS= read -r line <"${sum_path}" || return 1
            expected=${line%%[[:space:]]*}
            if [ -z "${expected}" ]; then
                echo "ERROR: Bad signature file: ${sum_path}"
                return 1
            fi
        fi
    fi

    if [ "${actual}" != "${expected}" ]; then
        echo "ERROR: SHA256 mismatch for ${source_path}"
        echo "Expected: ${expected}"
        echo "Actual:   ${actual}"
        return 1
    fi

    echo "SHA256 OK: ${source_path}"
    return 0
}

# the signature file is just a checksum hash
signature_file_exists() {
    [ -n "$1" ] || return 1
    local source_path="$1"
    local sum_path="$(readlink -f "${source_path}").sum"
    if [ -f "${sum_path}" ]; then
        return 0
    else
        return 1
    fi
}

retry() {
    local max=$1
    shift
    local i=1
    while :; do
        if ! "$@"; then
            if [ "${i}" -ge "${max}" ]; then
                return 1
            fi
            i=$((i + 1))
            sleep 10
        else
            return 0
        fi
    done
}

invoke_download_command() {
    [ -n "$1" ]                   || return 1
    [ -n "$2" ]                   || return 1

    local temp_path="$1"
    local source_url="$2"
    case "${FILE_DOWNLOADER}" in
        use_wget)
            if ! wget -O "${temp_path}" \
                      --tries=1 --retry-connrefused --waitretry=5 \
                      "${source_url}"; then
                return 1
            fi
            ;;
        use_curl)
            if ! curl --fail --retry 1 --retry-connrefused --retry-delay 5 \
                      --output "$temp_path" \
                      --remote-time \
                      "$source_url"; then
                return 1
            fi
            ;;
        use_curl_socks5_proxy)
            if [ -z "${CURL_SOCKS5_PROXY}" ]; then
                echo "You must specify a SOCKS5 proxy for download command: ${FILE_DOWNLOADER}" >&2
                return 1
            fi
            if ! curl --socks5-hostname ${CURL_SOCKS5_PROXY} \
                      --fail --retry 1 --retry-connrefused --retry-delay 5 \
                      --output "$temp_path" \
                      --remote-time \
                      "$source_url"; then
                return 1
            fi
            ;;
        *)
            echo "Unsupported file download command: '${FILE_DOWNLOADER}'" >&2
            return 1
            ;;
    esac
    return 0
}

download_clean() {
    [ -n "$1" ]          || return 1
    [ -n "$2" ]          || return 1
    [ -n "$3" ]          || return 1

    local temp_path="$1"
    local source_url="$2"
    local target_path="$3"

    rm -f "${temp_path}"
    if ! invoke_download_command "${temp_path}" "${source_url}"; then
        rm -f "${temp_path}"
        if [ -f "${target_path}" ]; then
            return 0
        else
            return 1
        fi
    else
        if [ -f "${target_path}" ]; then
            rm -f "${temp_path}"
            return 0
        else
            if ! mv -f "${temp_path}" "${target_path}"; then
                rm -f "${temp_path}" "${target_path}"
                return 1
            fi
        fi
    fi

    return 0
}

download()
( # BEGIN sub-shell
    [ -n "$1" ]            || return 1
    [ -n "$2" ]            || return 1
    [ -n "$3" ]            || return 1
    [ -n "${CACHED_DIR}" ] || return 1

    local source_url="$1"
    local source="$2"
    local target_dir="$3"
    local cached_path="${CACHED_DIR}/${source}"
    local target_path="${target_dir}/${source}"
    local temp_path=""

    if [ ! -f "${cached_path}" ]; then
        mkdir -p "${CACHED_DIR}"
        if [ ! -f "${target_path}" ]; then
            cleanup() { rm -f "${cached_path}" "${temp_path}"; }
            trap 'cleanup; exit 130' INT
            trap 'cleanup; exit 143' TERM
            trap 'cleanup' EXIT
            temp_path=$(mktemp "${cached_path}.XXXXXX")
            if ! retry 1000 download_clean "${temp_path}" "${source_url}" "${cached_path}"; then
                return 1
            fi
            trap - EXIT INT TERM
        else
            cleanup() { rm -f "${cached_path}"; }
            trap 'cleanup; exit 130' INT
            trap 'cleanup; exit 143' TERM
            trap 'cleanup' EXIT
            if ! mv -f "${target_path}" "${cached_path}"; then
                return 1
            fi
            trap - EXIT INT TERM
        fi
    fi

    if [ ! -f "${target_path}" ]; then
        if [ -f "${cached_path}" ]; then
            ln -sfn "${cached_path}" "${target_path}"
        fi
    fi

    return 0
) # END sub-shell

clone_github()
( # BEGIN sub-shell
    [ -n "$1" ]            || return 1
    [ -n "$2" ]            || return 1
    [ -n "$3" ]            || return 1
    [ -n "$4" ]            || return 1
    [ -n "$5" ]            || return 1
    [ -n "${CACHED_DIR}" ] || return 1

    local source_url="$1"
    local source_version="$2"
    local source_subdir="$3"
    local source="$4"
    local target_dir="$5"
    local cached_path="${CACHED_DIR}/${source}"
    local target_path="${target_dir}/${source}"
    local temp_path=""
    local temp_dir=""
    local timestamp=""

    if [ ! -f "${cached_path}" ]; then
        umask 022
        mkdir -p "${CACHED_DIR}"
        if [ ! -f "${target_path}" ]; then
            cleanup() { rm -rf "${temp_path}" "${temp_dir}"; }
            trap 'cleanup; exit 130' INT
            trap 'cleanup; exit 143' TERM
            trap 'cleanup' EXIT
            temp_path=$(mktemp "${cached_path}.XXXXXX")
            temp_dir=$(mktemp -d "${target_dir}/temp.XXXXXX")
            mkdir -p "${temp_dir}"
            if ! retry 100 git clone "${source_url}" "${temp_dir}/${source_subdir}"; then
                return 1
            fi
            cd "${temp_dir}/${source_subdir}"
            if ! retry 100 git checkout ${source_version}; then
                return 1
            fi
            if ! retry 100 git submodule update --init --recursive; then
                return 1
            fi
            timestamp="$(git log -1 --format='@%ct')"
            rm -rf .git
            cd ../..
            #chmod -R g-w,o-w "${temp_dir}/${source_subdir}"
            if ! tar --numeric-owner --owner=0 --group=0 --sort=name --mtime="${timestamp}" \
                    -C "${temp_dir}" "${source_subdir}" \
                    -cv | xz -zc -7e -T0 >"${temp_path}"; then
                return 1
            fi
            touch -d "${timestamp}" "${temp_path}" || return 1
            mv -f "${temp_path}" "${cached_path}" || return 1
            rm -rf "${temp_dir}" || return 1
            trap - EXIT INT TERM
            sign_file "${cached_path}" "full_extract"
        else
            cleanup() { rm -f "${cached_path}"; }
            trap 'cleanup; exit 130' INT
            trap 'cleanup; exit 143' TERM
            trap 'cleanup' EXIT
            mv -f "${target_path}" "${cached_path}" || return 1
            trap - EXIT INT TERM
        fi
    fi

    if [ ! -f "${target_path}" ]; then
        if [ -f "${cached_path}" ]; then
            ln -sfn "${cached_path}" "${target_path}"
        fi
    fi

    return 0
) # END sub-shell

download_archive() {
    [ "$#" -eq 3 ] || [ "$#" -eq 5 ] || return 1

    local source_url="$1"
    local source="$2"
    local target_dir="$3"
    local source_version="$4"
    local source_subdir="$5"

    if [ -z "${source_version}" ]; then
        download "${source_url}" "${source}" "${target_dir}"
    else
        clone_github "${source_url}" "${source_version}" "${source_subdir}" "${source}" "${target_dir}"
    fi
}

apply_patch() {
    [ -n "$1" ] || return 1
    [ -n "$2" ] || return 1

    local patch_file="$1"
    local target_dir="$2"

    if [ -f "${patch_file}" ]; then
        echo "Applying patch: ${patch_file}"
        if patch --dry-run --silent -p1 -d "${target_dir}/" -i "${patch_file}"; then
            if ! patch -p1 -d "${target_dir}/" -i "${patch_file}"; then
                echo "The patch failed."
                return 1
            fi
        else
            echo "The patch was not applied. Failed dry run."
            return 1
        fi
    else
        echo "Patch not found: ${patch_file}"
        return 1
    fi

    return 0
}

apply_patch_folder() {
    [ -n "$1" ] || return 1
    [ -n "$2" ] || return 1

    local patch_dir="$1"
    local target_dir="$2"
    local patch_file=""
    local rc=0

    if [ -d "${patch_dir}" ]; then
        for patch_file in ${patch_dir}/*.patch; do
            if [ -f "${patch_file}" ]; then
                if ! apply_patch "${patch_file}" "${target_dir}"; then
                    rc=1
                fi
            fi
        done
    fi

    return ${rc}
}

apply_patches() {
    [ -n "$1" ] || return 1
    [ -n "$2" ] || return 1

    local patch_file_or_dir="$1"
    local target_dir="$2"

    if [ -f "${patch_file_or_dir}" ]; then
        if ! apply_patch "${patch_file_or_dir}" "${target_dir}"; then
            return 1
        fi
    elif [ -d "${patch_file_or_dir}" ]; then
        if ! apply_patch_folder "${patch_file_or_dir}" "${target_dir}"; then
            return 1
        fi
    fi

    return 0
}

extract_package() {
    [ -n "$1" ] || return 1
    [ -n "$2" ] || return 1

    local source_path="$1"
    local target_dir="$2"

    case "${source_path}" in
        *.tar.gz|*.tgz)
            tar xzvf "${source_path}" -C "${target_dir}" || return 1
            ;;
        *.tar.bz2|*.tbz)
            tar xjvf "${source_path}" -C "${target_dir}" || return 1
            ;;
        *.tar.xz|*.txz)
            tar xJvf "${source_path}" -C "${target_dir}" || return 1
            ;;
        *.tar.lz|*.tlz)
            tar xlvf "${source_path}" -C "${target_dir}" || return 1
            ;;
        *.tar.zst)
            tar xvf "${source_path}" -C "${target_dir}" || return 1
            ;;
        *.tar)
            tar xvf "${source_path}" -C "${target_dir}" || return 1
            ;;
        *)
            echo "Unsupported archive type: ${source_path}" >&2
            return 1
            ;;
    esac

    return 0
}

unpack_archive()
( # BEGIN sub-shell
    [ -n "$1" ] || return 1
    [ -n "$2" ] || return 1

    local source_path="$1"
    local target_dir="$2"
    local top_dir="${target_dir%%/*}"
    local dir_tmp=""

    if [ ! -d "${target_dir}" ]; then
        cleanup() { rm -rf "${dir_tmp}" "${target_dir}"; }
        trap 'cleanup; exit 130' INT
        trap 'cleanup; exit 143' TERM
        trap 'cleanup' EXIT
        dir_tmp=$(mktemp -d "${top_dir}.XXXXXX")
        mkdir -p "${dir_tmp}"
        if ! extract_package "${source_path}" "${dir_tmp}"; then
            return 1
        else
            # try to rename single sub-directory
            if ! mv -f "${dir_tmp}"/* "${target_dir}"/; then
                # otherwise, move multiple files and sub-directories
                mkdir -p "${target_dir}" || return 1
                mv -f "${dir_tmp}"/* "${target_dir}"/ || return 1
            fi
        fi
        rm -rf "${dir_tmp}" || return 1
        trap - EXIT INT TERM
    fi

    return 0
) # END sub-shell

unpack_and_verify()
( # BEGIN sub-shell
    [ -n "$1" ] || return 1
    [ -n "$2" ] || return 1

    local source_path="$1"
    local target_dir="$2"
    local expected="$3"
    local actual=""
    local sum_path="$(readlink -f "${source_path}").sum"
    local line=""
    local top_dir="${target_dir%%/*}"
    local dir_tmp=""

    if [ ! -d "${target_dir}" ]; then
        cleanup() { rm -rf "${dir_tmp}" "${target_dir}"; }
        trap 'cleanup; exit 130' INT
        trap 'cleanup; exit 143' TERM
        trap 'cleanup' EXIT
        dir_tmp=$(mktemp -d "${top_dir}.XXXXXX")
        mkdir -p "${dir_tmp}"
        if ! extract_package "${source_path}" "${dir_tmp}"; then
            return 1
        else
            actual="$(hash_dir "${dir_tmp}")"

            if [ -z "${expected}" ]; then
                if [ ! -f "${sum_path}" ]; then
                    echo "ERROR: Signature file not found: ${sum_path}"
                    return 1
                else
                    IFS= read -r line <"${sum_path}" || return 1
                    expected=${line%%[[:space:]]*}
                    if [ -z "${expected}" ]; then
                        echo "ERROR: Bad signature file: ${sum_path}"
                        return 1
                    fi
                fi
            fi

            if [ "${actual}" != "${expected}" ]; then
                echo "ERROR: SHA256 mismatch for ${source_path}"
                echo "Expected: ${expected}"
                echo "Actual:   ${actual}"
                return 1
            fi

            echo "SHA256 OK: ${source_path}"

            # try to rename single sub-directory
            if ! mv -f "${dir_tmp}"/* "${target_dir}"/; then
                # otherwise, move multiple files and sub-directories
                mkdir -p "${target_dir}" || return 1
                mv -f "${dir_tmp}"/* "${target_dir}"/ || return 1
            fi
        fi
        rm -rf "${dir_tmp}" || return 1
        trap - EXIT INT TERM
    fi

    return 0
) # END sub-shell

get_latest_package() {
    [ "$#" -eq 3 ] || return 1

    local prefix=$1
    local middle=$2
    local suffix=$3
    local pattern=${prefix}${middle}${suffix}
    local latest=""
    local version=""

    (
        cd "$CACHED_DIR" || return 1

        set -- $pattern
        [ "$1" != "$pattern" ] || return 1   # no matches

        latest=$1
        for f do
            latest=$f
        done

        version=${latest#"$prefix"}
        version=${version%"$suffix"}
        printf '%s\n' "$version"
    )
    return 0
}

enable_options() {
    [ -n "$1" ] || return 1
    [ -n "$2" ] || return 1
    local p n
    $2 && p=enable || p=disable
    for n in $1; do printf -- "--%s-%s " "$p" "$n"; done
    return 0
}

contains() {
    case "$1" in
        *"$2"*) return 0 ;;
        *)      return 1 ;;
    esac
}

ends_with() {
    case "$1" in
        *"$2") return 0 ;;
        *)     return 1 ;;
    esac
}

system_name() {
    [ -n "$1" ] || return 1

    local config_guess="$1"
    [ -f "${config_guess}" ] || return 1

    export CC_FOR_BUILD="$(which gcc)"
    local system_name="$(${config_guess})"
    unset CC_FOR_BUILD
    echo "${system_name}"
    return 0
}

is_version_git() {
    case "$1" in
        *+git*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

update_patch_library() {
    [ -n "$1" ]            || return 1
    [ -n "$2" ]            || return 1
    [ -n "$3" ]            || return 1
    [ -n "$4" ]            || return 1
    [ -n "${PARENT_DIR}" ] || return 1
    [ -n "${SCRIPT_DIR}" ] || return 1

    local git_commit="$1"
    local patches_dir="$2"
    local pkg_name="$3"
    local pkg_subdir="$4"
    local entware_packages_dir="${PARENT_DIR}/entware-packages"

    if [ ! -d "${entware_packages_dir}" ]; then
        cd "${PARENT_DIR}"
        git clone https://github.com/Entware/entware-packages
    fi

    cd "${entware_packages_dir}"
    git fetch origin
    git reset --hard "${git_commit}"
    [ -d "${patches_dir}" ] || return 1
    mkdir -p "${SCRIPT_DIR}/patches/${pkg_name}/${pkg_subdir}/entware"
    cp -pf "${patches_dir}"/* "${SCRIPT_DIR}/patches/${pkg_name}/${pkg_subdir}/entware/"
    cd ..

    return 0
}

check_static() {
    ldd() {
        if ${ARCH_NATIVE}; then
            "${PREFIX}/lib/libc.so" --list "$@"
        else
            true
        fi
    }

    local rc=0
    for bin in "$@"; do
        echo "Checking ${bin}"
        file "${bin}" || true
        if ${READELF} -d "${bin}" 2>/dev/null | grep NEEDED; then
            rc=1
        fi || true
        ldd "${bin}" 2>&1 || true
    done

    if [ ${rc} -eq 1 ]; then
        echo "*** NOT STATICALLY LINKED ***"
        echo "*** NOT STATICALLY LINKED ***"
        echo "*** NOT STATICALLY LINKED ***"
    fi

    return ${rc}
}

finalize_build() {
    set +x
    echo ""
    echo "Stripping symbols and sections from files..."
    ${STRIP} -v "$@"

    # Exit here, if the programs are not statically linked.
    # If any binaries are not static, check_static() returns 1
    # set -e will cause the shell to exit here, so renaming won't happen below.
    echo ""
    echo "Checking statically linked programs..."
    check_static "$@"

    # Append ".static" to the program names
    echo ""
    echo "Create symbolic link with .static suffix..."
    for bin in "$@"; do
        case "$bin" in
            *.static) : ;;   # do nothing
            *) ln -sfn "$(basename "${bin}")" "${bin}.static" ;;
        esac
    done
    set -x

    return 0
}

# temporarily hide shared libraries (.so) to force cmake to use the static ones (.a)
hide_shared_libraries() {
    if [ -d "${PREFIX}/lib_hidden" ]; then
        mv -f "${PREFIX}/lib_hidden/"* "${PREFIX}/lib/" || true
        rmdir "${PREFIX}/lib_hidden" || true
    fi
    mkdir -p "${PREFIX}/lib_hidden" || true
    mv -f "${PREFIX}/lib/"*".so"* "${PREFIX}/lib_hidden/" || true
    return 0
}

# restore the hidden shared libraries
restore_shared_libraries() {
    if [ -d "${PREFIX}/lib_hidden" ]; then
        mv -f "${PREFIX}/lib_hidden/"* "${PREFIX}/lib/" || true
        rmdir "${PREFIX}/lib_hidden" || true
    fi
    return 0
}

add_items_to_install_package()
( # BEGIN sub-shell
    [ -n "$1" ] || return 1
    [ -n "$PKG_ROOT" ]            || return 1
    [ -n "$PKG_ROOT_VERSION" ]    || return 1
    [ -n "$PACKAGER_ROOT" ]       || return 1
    [ -n "$PACKAGER_NAME" ]       || return 1
    [ -n "$CACHED_DIR" ]          || return 1

    local timestamp_file="$1"
    local pkg_files=""
    for fmt in gz xz; do
        local pkg_file="${PACKAGER_NAME}.tar.${fmt}"
        local pkg_path="${CACHED_DIR}/${pkg_file}"
        local temp_path=""
        local timestamp=""
        local compressor=""

        case "${fmt}" in
            gz) compressor="gzip -9 -n" ;;
            xz) compressor="xz -zc -7e -T0" ;;
        esac

        echo "[*] Add items to package (.${fmt})..."
        mkdir -p "${CACHED_DIR}"
        rm -f "${pkg_path}"
        rm -f "${pkg_path}.sum"
        cleanup() { rm -f "${temp_path}"; }
        trap 'cleanup; exit 130' INT
        trap 'cleanup; exit 143' TERM
        trap 'cleanup' EXIT
        temp_path=$(mktemp "${pkg_path}.XXXXXX")
        timestamp="@$(stat -c %Y "${timestamp_file}")"
        cd "${PACKAGER_ROOT}" || return 1
        if ! tar --numeric-owner --owner=0 --group=0 --sort=name --mtime="${timestamp}" \
                -C "${PACKAGER_ROOT}" * \
                -cv | ${compressor} >"${temp_path}"; then
            return 1
        fi
        touch -d "${timestamp}" "${temp_path}" || return 1
        chmod 644 "${temp_path}" || return 1
        mv -f "${temp_path}" "${pkg_path}" || return 1
        trap - EXIT INT TERM
        echo ""
        sign_file "${pkg_path}"

        if [ -z "${pkg_files}" ]; then
            pkg_files="${pkg_path}"
        else
            pkg_files="${pkg_files}\n${pkg_path}"
        fi
    done

    echo "[*] Finished creating the install package."
    echo ""
    echo "[*] Install package is here:"
    printf '%b\n' "${pkg_files}"
    echo ""

    return 0
) # END sub-shell

################################################################################
# Install the build environment
# ARM Linux musl Cross-Compiler v0.2.2
#
install_build_environment() {
( #BEGIN sub-shell
PKG_NAME=cross-arm-linux-musleabi
get_latest() { get_latest_package "${PKG_NAME}-${HOST_CPU}-" "??????????????" ".tar.xz"; }
#PKG_VERSION="$(get_latest)" # this line will fail if you did not build a toolchain yourself
PKG_VERSION=0.2.2 # this line will cause a toolchain to be downloaded from Github
PKG_SOURCE="${PKG_NAME}-${HOST_CPU}-${PKG_VERSION}.tar.xz"
PKG_SOURCE_URL="https://github.com/solartracker/${PKG_NAME}/releases/download/${PKG_VERSION}/${PKG_SOURCE}"
PKG_SOURCE_SUBDIR="${PKG_NAME}-${PKG_VERSION}"
PKG_SOURCE_PATH="${CACHED_DIR}/${PKG_SOURCE}"

if signature_file_exists "${PKG_SOURCE_PATH}"; then
    # use an archived toolchain that you built yourself, along with a signature
    # file that was created automatically.  the version number is a 14 digit
    # timestamp and a symbolic link was automatically created for the release
    # asset that would normally have been downloaded. all this is done for you
    # by the toolchain build script: build-arm-linux-musleabi.sh
    #
    # Example of what your sources directory might look like:
    # cross-arm-linux-musleabi-armv7l-20260120150840.tar.xz
    # cross-arm-linux-musleabi-armv7l-20260120150840.tar.xz.sha256
    # cross-arm-linux-musleabi-armv7l-0.2.0.tar.xz -> cross-arm-linux-musleabi-armv7l-20260120150840.tar.xz
    # cross-arm-linux-musleabi-armv7l-0.2.0.tar.xz.sha256 -> cross-arm-linux-musleabi-armv7l-20260120150840.tar.xz.sha256
    #
    PKG_HASH=""
else
    # alternatively, the toolchain can be downloaded from Github. note that the version
    # number is the Github tag, instead of a 14 digit timestamp.
    case "${HOST_CPU}" in
        armv7l)
            # cross-arm-linux-musleabi-armv7l-0.2.2.tar.xz
            PKG_HASH="8ecd47f9212ec26f07c53482fe4e5d08c753f5bc09b21098540dd6063d342f00"
            ;;
        x86_64)
            # cross-arm-linux-musleabi-x86_64-0.2.2.tar.xz
            PKG_HASH="ccdf14e6b0edfb66dd2004cb8fb10e660432ec96ea27b97f8d9471d63f5f4706"
            ;;
        *)
            echo "Unsupported CPU architecture: "${HOST_CPU} >&2
            exit 1
            ;;
    esac
fi

# Check if toolchain exists and install it, if needed
if [ ! -d "${CROSSBUILD_DIR}" ]; then
    echo "Toolchain not found at ${CROSSBUILD_DIR}. Installing..."
    echo ""
    cd ${PARENT_DIR}
    download_archive "${PKG_SOURCE_URL}" "${PKG_SOURCE}" "${CACHED_DIR}"
    verify_hash "${PKG_SOURCE_PATH}" "${PKG_HASH}"
    unpack_archive "${PKG_SOURCE_PATH}" "${CROSSBUILD_DIR}"
fi

# restore the hidden shared libraries, if they were not previously restored
restore_shared_libraries

# Check for required toolchain tools
if [ ! -x "${CROSSBUILD_DIR}/bin/${TARGET}-gcc" ]; then
    echo "ERROR: Toolchain installation appears incomplete."
    echo "Missing ${TARGET}-gcc in ${CROSSBUILD_DIR}/bin"
    echo ""
    exit 1
fi
if [ ! -x "${PREFIX}/lib/libc.so" ]; then
    echo "ERROR: Toolchain installation appears incomplete."
    echo "Missing libc.so in ${PREFIX}/lib"
    echo ""
    exit 1
fi
) #END sub-shell
} #END install_build_environment()


################################################################################
download_and_compile() {
( #BEGIN sub-shell
export PATH="${CROSSBUILD_DIR}/bin:${PATH}"
mkdir -p "${SRC_ROOT}"
mkdir -p "${STAGE_DIR}"
create_cmake_toolchain_file


################################################################################
# libcap-2.77
(
PKG_NAME=libcap
PKG_VERSION=2.77
PKG_SOURCE="${PKG_NAME}-${PKG_VERSION}.tar.xz"
PKG_SOURCE_URL="https://www.kernel.org/pub/linux/libs/security/linux-privs/libcap2/${PKG_SOURCE}"
PKG_SOURCE_SUBDIR="${PKG_NAME}-${PKG_VERSION}"
PKG_HASH="897bc18b44afc26c70e78cead3dbb31e154acc24bee085a5a09079a88dbf6f52"

mkdir -p "${SRC_ROOT}/${PKG_NAME}"
cd "${SRC_ROOT}/${PKG_NAME}"

if [ ! -f "${PKG_SOURCE_SUBDIR}/__package_installed" ]; then
    rm -rf "${PKG_SOURCE_SUBDIR}"
    download_archive "${PKG_SOURCE_URL}" "${PKG_SOURCE}" "."
    verify_hash "${PKG_SOURCE}" "${PKG_HASH}"
    unpack_archive "${PKG_SOURCE}" "${PKG_SOURCE_SUBDIR}"
    cd "${PKG_SOURCE_SUBDIR}"

    export CROSS_COMPILE=${CROSS_PREFIX}
    export BUILD_CC="gcc"
    export BUILD_CPPFLAGS="-I./libcap/include"
    export BUILD_COPTS=
    export BUILD_CFLAGS=
    export BUILD_LDFLAGS=
    export SHARED=no
    export DYNAMIC=no
    export prefix="${PREFIX}"
    export lib="lib"
    export RAISE_SETFCAP="no"

    export LDFLAGS="-static ${LDFLAGS}"

    hide_shared_libraries
    $MAKE LDFLAGS="${LDFLAGS}"
    make install
    restore_shared_libraries

    finalize_build \
        "${PREFIX}/sbin/capsh" \
        "${PREFIX}/sbin/getcap" \
        "${PREFIX}/sbin/getpcaps" \
        "${PREFIX}/sbin/setcap"

    touch __package_installed
fi
)

################################################################################
# argp-standalone-1.4.1
(
PKG_NAME=argp-standalone
#PKG_VERSION=1.3
PKG_VERSION=1.4.1
PKG_SOURCE="${PKG_NAME}-${PKG_VERSION}.tar.gz"
#PKG_SOURCE_URL="https://www.lysator.liu.se/~nisse/misc/${PKG_SOURCE}"
PKG_SOURCE_URL="https://github.com/ericonr/argp-standalone/archive/${PKG_VERSION}.tar.gz"
PKG_SOURCE_SUBDIR="${PKG_NAME}-${PKG_VERSION}"
#PKG_HASH="dec79694da1319acd2238ce95df57f3680fea2482096e483323fddf3d818d8be"
PKG_HASH="879d76374424dce051b812f16f43c6d16de8dbaddd76002f83fd1b6e57d39e0b"

mkdir -p "${SRC_ROOT}/${PKG_NAME}"
cd "${SRC_ROOT}/${PKG_NAME}"

if [ ! -f "${PKG_SOURCE_SUBDIR}/__package_installed" ]; then
    rm -rf "${PKG_SOURCE_SUBDIR}"
    download_archive "${PKG_SOURCE_URL}" "${PKG_SOURCE}" "."
    verify_hash "${PKG_SOURCE}" "${PKG_HASH}"
    unpack_archive "${PKG_SOURCE}" "${PKG_SOURCE_SUBDIR}"
    cd "${PKG_SOURCE_SUBDIR}"

    export PREFIX=

    if [ ! -f "./configure" ]; then
        autoreconf -i
    fi

    ./configure \
        --prefix="${PREFIX}" \
        --host="${HOST}" \
        --build="${SYSTEM}" \
        --disable-dependency-tracking \
    || handle_configure_error $?

    $MAKE

    # install files to staging directory where cryptsetup can find them.
    # don't install to sysroot because it might conflict with GNU/glibc argp.
    mkdir -p "${STAGE_DIR}/lib"
    mkdir -p "${STAGE_DIR}/include"
    cp -p libargp.a "${STAGE_DIR}/lib/"
    cp -p argp.h "${STAGE_DIR}/include/" 
    cp -p argp-fmtstream.h "${STAGE_DIR}/include/" 
    cp -p argp-namefrob.h "${STAGE_DIR}/include/" 

    touch __package_installed
fi
)

################################################################################
# zlib-1.3.1
(
PKG_NAME=zlib
PKG_VERSION=1.3.1
PKG_SOURCE="${PKG_NAME}-${PKG_VERSION}.tar.xz"
PKG_SOURCE_URL="https://github.com/madler/zlib/releases/download/v${PKG_VERSION}/${PKG_SOURCE}"
PKG_SOURCE_SUBDIR="${PKG_NAME}-${PKG_VERSION}"
PKG_HASH="38ef96b8dfe510d42707d9c781877914792541133e1870841463bfa73f883e32"

mkdir -p "${SRC_ROOT}/${PKG_NAME}"
cd "${SRC_ROOT}/${PKG_NAME}"

if [ ! -f "${PKG_SOURCE_SUBDIR}/__package_installed" ]; then
    rm -rf "${PKG_SOURCE_SUBDIR}"
    download_archive "${PKG_SOURCE_URL}" "${PKG_SOURCE}" "."
    verify_hash "${PKG_SOURCE}" "${PKG_HASH}"
    unpack_archive "${PKG_SOURCE}" "${PKG_SOURCE_SUBDIR}"
    cd "${PKG_SOURCE_SUBDIR}"

    ./configure \
        --prefix="${PREFIX}" \
        --static \
    || handle_configure_error $?

    $MAKE
    make install

    touch __package_installed
fi
)

################################################################################
# bzip2-1.0.8
(
PKG_NAME=bzip2
PKG_VERSION=1.0.8
PKG_SOURCE="${PKG_NAME}-${PKG_VERSION}.tar.gz"
PKG_SOURCE_URL="https://sourceware.org/pub/${PKG_NAME}/${PKG_SOURCE}"
PKG_SOURCE_SUBDIR="${PKG_NAME}-${PKG_VERSION}"
PKG_HASH="ab5a03176ee106d3f0fa90e381da478ddae405918153cca248e682cd0c4a2269"

mkdir -p "${SRC_ROOT}/${PKG_NAME}"
cd "${SRC_ROOT}/${PKG_NAME}"

if [ ! -f "${PKG_SOURCE_SUBDIR}/__package_installed" ]; then
    rm -rf "${PKG_SOURCE_SUBDIR}"
    download_archive "${PKG_SOURCE_URL}" "${PKG_SOURCE}" "."
    verify_hash "${PKG_SOURCE}" "${PKG_HASH}"
    unpack_archive "${PKG_SOURCE}" "${PKG_SOURCE_SUBDIR}"
    cd "${PKG_SOURCE_SUBDIR}"

    export CFLAGS="${CFLAGS} -static"

    make distclean || true

    $MAKE \
        CC="$CC" \
        AR="$AR" \
        RANLIB="$RANLIB" \
        CFLAGS="$CFLAGS" \
        bzip2 bzip2recover libbz2.a

    make install PREFIX="${PREFIX}"

    finalize_build \
        "${PREFIX}/bin/bzip2" \
        "${PREFIX}/bin/bunzip2" \
        "${PREFIX}/bin/bzcat" \
        "${PREFIX}/bin/bzip2recover"

    touch __package_installed
fi
)

################################################################################
# lz4-1.10.0
(
PKG_NAME=lz4
PKG_VERSION=1.10.0
PKG_SOURCE="${PKG_NAME}-${PKG_VERSION}.tar.gz"
PKG_SOURCE_URL="https://github.com/lz4/lz4/releases/download/v${PKG_VERSION}/${PKG_SOURCE}"
PKG_SOURCE_SUBDIR="${PKG_NAME}-${PKG_VERSION}"
PKG_HASH="537512904744b35e232912055ccf8ec66d768639ff3abe5788d90d792ec5f48b"

mkdir -p "${SRC_ROOT}/${PKG_NAME}"
cd "${SRC_ROOT}/${PKG_NAME}"

if [ ! -f "${PKG_SOURCE_SUBDIR}/__package_installed" ]; then
    rm -rf "${PKG_SOURCE_SUBDIR}"
    download_archive "${PKG_SOURCE_URL}" "${PKG_SOURCE}" "."
    verify_hash "${PKG_SOURCE}" "${PKG_HASH}"
    unpack_archive "${PKG_SOURCE}" "${PKG_SOURCE_SUBDIR}"
    cd "${PKG_SOURCE_SUBDIR}"

    make clean || true
    $MAKE lib
    make install PREFIX=${PREFIX}

    touch __package_installed
fi
)

################################################################################
# xz-5.8.2
(
PKG_NAME=xz
PKG_VERSION=5.8.2
PKG_SOURCE="${PKG_NAME}-${PKG_VERSION}.tar.xz"
PKG_SOURCE_URL="https://github.com/tukaani-project/xz/releases/download/v${PKG_VERSION}/${PKG_SOURCE}"
PKG_SOURCE_SUBDIR="${PKG_NAME}-${PKG_VERSION}"
PKG_HASH="890966ec3f5d5cc151077879e157c0593500a522f413ac50ba26d22a9a145214"

mkdir -p "${SRC_ROOT}/${PKG_NAME}"
cd "${SRC_ROOT}/${PKG_NAME}"

if [ ! -f "${PKG_SOURCE_SUBDIR}/__package_installed" ]; then
    rm -rf "${PKG_SOURCE_SUBDIR}"
    download_archive "${PKG_SOURCE_URL}" "${PKG_SOURCE}" "."
    verify_hash "${PKG_SOURCE}" "${PKG_HASH}"
    unpack_archive "${PKG_SOURCE}" "${PKG_SOURCE_SUBDIR}"
    cd "${PKG_SOURCE_SUBDIR}"

    ./configure \
        --prefix="${PREFIX}" \
        --host="${HOST}" \
        --build="${SYSTEM}" \
        --enable-year2038 \
        --enable-static \
        --disable-shared \
        --disable-assembler \
        --disable-dependency-tracking \
        --disable-nls \
        --disable-rpath \
        --disable-scripts \
        --disable-doc \
    || handle_configure_error $?

    $MAKE
    make install

    touch __package_installed
fi
)

################################################################################
# zstd-1.5.7
(
PKG_NAME=zstd
PKG_VERSION=1.5.7
PKG_SOURCE="${PKG_NAME}-${PKG_VERSION}.tar.gz"
PKG_SOURCE_URL="https://github.com/facebook/zstd/releases/download/v${PKG_VERSION}/${PKG_SOURCE}"
PKG_SOURCE_SUBDIR="${PKG_NAME}-${PKG_VERSION}"
PKG_HASH="eb33e51f49a15e023950cd7825ca74a4a2b43db8354825ac24fc1b7ee09e6fa3"

mkdir -p "${SRC_ROOT}/${PKG_NAME}"
cd "${SRC_ROOT}/${PKG_NAME}"

if [ ! -f "${PKG_SOURCE_SUBDIR}/__package_installed" ]; then
    rm -rf "${PKG_SOURCE_SUBDIR}"
    download_archive "${PKG_SOURCE_URL}" "${PKG_SOURCE}" "." "${PKG_SOURCE_VERSION}" "${PKG_SOURCE_SUBDIR}"
    verify_hash "${PKG_SOURCE}" "${PKG_HASH}" "${PKG_HASH_VERIFY}"
    unpack_archive "${PKG_SOURCE}" "${PKG_SOURCE_SUBDIR}"
    cd "${PKG_SOURCE_SUBDIR}"

    $MAKE zstd \
        LDFLAGS="-static ${LDFLAGS}" \
        CFLAGS="${CFLAGS}" \
        LIBS="${PREFIX}/lib/libz.a ${PREFIX}/lib/liblzma.a ${PREFIX}/lib/liblz4.a"

    make install

    # strip and verify there are no dependencies for static build
    finalize_build "${PREFIX}/bin/zstd"

    touch __package_installed
fi
)

################################################################################
# popt-1.19
(
PKG_NAME=popt
PKG_VERSION=1.19
PKG_SOURCE="${PKG_NAME}-${PKG_VERSION}.tar.xz"
PKG_SOURCE_URL="https://deb.debian.org/debian/pool/main/p/popt/${PKG_NAME}_${PKG_VERSION}+dfsg.orig.tar.xz"
PKG_SOURCE_SUBDIR="${PKG_NAME}-${PKG_VERSION}"
PKG_HASH="4cd0cd2963d0c4078f65949599d97135c15ee6c09cf3a36a9a1b2753025bb06b"

mkdir -p "${SRC_ROOT}/${PKG_NAME}"
cd "${SRC_ROOT}/${PKG_NAME}"

if [ ! -f "${PKG_SOURCE_SUBDIR}/__package_installed" ]; then
    rm -rf "${PKG_SOURCE_SUBDIR}"
    download_archive "${PKG_SOURCE_URL}" "${PKG_SOURCE}" "."
    verify_hash "${PKG_SOURCE}" "${PKG_HASH}"
    unpack_archive "${PKG_SOURCE}" "${PKG_SOURCE_SUBDIR}"
    cd "${PKG_SOURCE_SUBDIR}"

    ./configure \
        --prefix="${PREFIX}" \
        --host="${HOST}" \
        --build="${SYSTEM}" \
        --enable-static \
        --disable-shared \
        --disable-dependency-tracking \
        --disable-nls \
        --disable-rpath \
    || handle_configure_error $?

    $MAKE
    make install

    touch __package_installed
fi
)

################################################################################
# json-c-0.18
(
PKG_NAME=json-c
PKG_VERSION="0.18"
PKG_SOURCE="${PKG_NAME}-${PKG_VERSION}.tar.gz"
PKG_SOURCE_URL="https://github.com/json-c/json-c/archive/${PKG_NAME}-${PKG_VERSION}-20240915.tar.gz"
PKG_SOURCE_SUBDIR="${PKG_NAME}-${PKG_VERSION}"
PKG_HASH="3112c1f25d39eca661fe3fc663431e130cc6e2f900c081738317fba49d29e298"

mkdir -p "${SRC_ROOT}/${PKG_NAME}"
cd "${SRC_ROOT}/${PKG_NAME}"

if [ ! -f "${PKG_SOURCE_SUBDIR}/__package_installed" ]; then
    rm -rf "${PKG_SOURCE_SUBDIR}"
    download_archive "${PKG_SOURCE_URL}" "${PKG_SOURCE}" "."
    verify_hash "${PKG_SOURCE}" "${PKG_HASH}"
    unpack_archive "${PKG_SOURCE}" "${PKG_SOURCE_SUBDIR}"
    cd "${PKG_SOURCE_SUBDIR}"

    rm -rf build
    mkdir -p build
    cd build

    cmake .. \
        -DCMAKE_TOOLCHAIN_FILE=${SRC_ROOT}/arm-musl.toolchain.cmake \
        -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} \
        -DCMAKE_VERBOSE_MAKEFILE=${CMAKE_VERBOSE_MAKEFILE} \
        -DCMAKE_PREFIX_PATH="${PREFIX}" \
        -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
        -DBUILD_STATIC_LIBS=ON \
        -DBUILD_SHARED_LIBS=OFF \
        -DENABLE_THREADING=ON

    $MAKE
    make install

    cd ..

    touch __package_installed
fi
)

################################################################################
# openssl-3.6.0
(
PKG_NAME=openssl
PKG_VERSION=3.6.0
PKG_SOURCE="${PKG_NAME}-${PKG_VERSION}.tar.gz"
PKG_SOURCE_URL="https://github.com/openssl/openssl/releases/download/openssl-${PKG_VERSION}/${PKG_SOURCE}"
PKG_SOURCE_SUBDIR="${PKG_NAME}-${PKG_VERSION}"
PKG_HASH="b6a5f44b7eb69e3fa35dbf15524405b44837a481d43d81daddde3ff21fcbb8e9"

mkdir -p "${SRC_ROOT}/${PKG_NAME}"
cd "${SRC_ROOT}/${PKG_NAME}"

if [ ! -f "${PKG_SOURCE_SUBDIR}/__package_installed" ]; then
    rm -rf "${PKG_SOURCE_SUBDIR}"
    download_archive "${PKG_SOURCE_URL}" "${PKG_SOURCE}" "."
    verify_hash "${PKG_SOURCE}" "${PKG_HASH}"
    unpack_archive "${PKG_SOURCE}" "${PKG_SOURCE_SUBDIR}"
    cd "${PKG_SOURCE_SUBDIR}"

    export LDFLAGS="-static ${LDFLAGS}"
    export LIBS="-lzstd -lz"
    export CFLAGS="${CFLAGS} -Wno-int-conversion"
    export CPPFLAGS="-DOPENSSL_PREFER_CHACHA_OVER_GCM ${CPPFLAGS}"

    ./Configure linux-armv4 no-asm \
        enable-zlib enable-zstd no-shared \
        no-tests no-fuzz-afl no-fuzz-libfuzzer no-gost no-err no-unit-test no-docs \
        no-err no-async \
        no-aria no-sm2 no-sm3 no-sm4 \
        no-dso no-ssl3 no-comp \
        enable-rc5 \
        --prefix="${PREFIX}" \
        --with-rand-seed=devrandom

    $MAKE
    make install

    # strip and verify there are no dependencies for static build
    finalize_build "${PREFIX}/bin/openssl"

    touch __package_installed
fi
)

if [ ! -f "${SYSROOT}/usr/include/linux/if_alg.h" ]; then
################################################################################
# linux-2.6.38.8
(
PKG_NAME=linux
PKG_VERSION=2.6.38.8
PKG_SOURCE="${PKG_NAME}-${PKG_VERSION}.tar.xz"
PKG_SOURCE_URL="https://www.kernel.org/pub/linux/kernel/v$(echo "$PKG_VERSION" | cut -d. -f1,2)/${PKG_SOURCE}"
PKG_SOURCE_SUBDIR="${PKG_NAME}-${PKG_VERSION}"
PKG_HASH="c300486b30d28ae34c587a4f1aa8e98916a0616dad91a394b0e1352a9c7a8256"

mkdir -p "${SRC_ROOT}/${PKG_NAME}"
cd "${SRC_ROOT}/${PKG_NAME}"

if [ ! -f "${PKG_SOURCE_SUBDIR}/__package_installed" ]; then
    rm -rf "${PKG_SOURCE_SUBDIR}"
    download_archive "${PKG_SOURCE_URL}" "${PKG_SOURCE}" "."
    verify_hash "${PKG_SOURCE}" "${PKG_HASH}"

    tar xJvf "${SRC_ROOT}/${PKG_NAME}/${PKG_SOURCE}" "${PKG_SOURCE_SUBDIR}/include/linux/if_alg.h"
    cd "${PKG_SOURCE_SUBDIR}"

    touch __package_installed
fi
# Cryptsetup needs the Linux kernel header: userspace crypto interface
cp -p "${SRC_ROOT}/${PKG_NAME}/${PKG_SOURCE_SUBDIR}/include/linux/if_alg.h" "${SYSROOT}/usr/include/linux/"
)
fi

################################################################################
# SQLite 3.51.2
(
PKG_NAME=sqlite-autoconf
PKG_VERSION=3510200
PKG_SOURCE="${PKG_NAME}-${PKG_VERSION}.tar.gz"
PKG_SOURCE_URL="https://sqlite.org/2026/${PKG_SOURCE}"
PKG_SOURCE_SUBDIR="${PKG_NAME}-${PKG_VERSION}"
PKG_HASH="fbd89f866b1403bb66a143065440089dd76100f2238314d92274a082d4f2b7bb"

mkdir -p "${SRC_ROOT}/${PKG_NAME}"
cd "${SRC_ROOT}/${PKG_NAME}"

if [ ! -f "${PKG_SOURCE_SUBDIR}/__package_installed" ]; then
    rm -rf "${PKG_SOURCE_SUBDIR}"
    download "${PKG_SOURCE_URL}" "${PKG_SOURCE}" "."
    verify_hash "${PKG_SOURCE}" "${PKG_HASH}"
    unpack_archive "${PKG_SOURCE}" "${PKG_SOURCE_SUBDIR}"
    cd "${PKG_SOURCE_SUBDIR}"

    ./configure \
        --prefix="${PREFIX}" \
        --host="${HOST}" \
        --build="${SYSTEM}" \
        --enable-static \
        --disable-shared \
        --disable-rpath \
    || handle_configure_error $?

    $MAKE
    make install

    touch __package_installed
fi
)

################################################################################
# libaio-0.3.113
(
PKG_NAME=libaio
PKG_VERSION=0.3.113
PKG_SOURCE="${PKG_NAME}-${PKG_VERSION}.tar.gz"
PKG_SOURCE_URL="https://releases.pagure.org/libaio/${PKG_SOURCE}"
PKG_SOURCE_SUBDIR="${PKG_NAME}-${PKG_VERSION}"
PKG_HASH="2c44d1c5fd0d43752287c9ae1eb9c023f04ef848ea8d4aafa46e9aedb678200b"

mkdir -p "${SRC_ROOT}/${PKG_NAME}"
cd "${SRC_ROOT}/${PKG_NAME}"

if [ ! -f "${PKG_SOURCE_SUBDIR}/__package_installed" ]; then
    rm -rf "${PKG_SOURCE_SUBDIR}"
    download_archive "${PKG_SOURCE_URL}" "${PKG_SOURCE}" "."
    verify_hash "${PKG_SOURCE}" "${PKG_HASH}"
    unpack_archive "${PKG_SOURCE}" "${PKG_SOURCE_SUBDIR}"
    cd "${PKG_SOURCE_SUBDIR}"

    export PREFIX=
    export ENABLE_SHARED=0

    $MAKE
    make install DESTDIR="${SYSROOT}"

    touch __package_installed
fi
)

################################################################################
# lvm2-2.03.38
(
PKG_NAME=lvm2
PKG_VERSION=2.03.38
PKG_SOURCE="${PKG_NAME}-${PKG_VERSION}.tgz"
PKG_SOURCE_URL="https://sourceware.org/pub/lvm2/LVM2.${PKG_VERSION}.tgz"
PKG_SOURCE_SUBDIR="${PKG_NAME}-${PKG_VERSION}"
PKG_HASH="322d44bf40de318e6e6b52c56999aaeb86b16c8267187ac2e01a44d4dc526960"

mkdir -p "${SRC_ROOT}/${PKG_NAME}"
cd "${SRC_ROOT}/${PKG_NAME}"

if [ ! -f "${PKG_SOURCE_SUBDIR}/__package_installed" ]; then
    rm -rf "${PKG_SOURCE_SUBDIR}"
    download_archive "${PKG_SOURCE_URL}" "${PKG_SOURCE}" "."
    verify_hash "${PKG_SOURCE}" "${PKG_HASH}"
    unpack_archive "${PKG_SOURCE}" "${PKG_SOURCE_SUBDIR}"
    cd "${PKG_SOURCE_SUBDIR}"

    apply_patches "${SCRIPT_DIR}/patches/lvm2/lvm2-2.03.38/solartracker" "."

    export PREFIX=

    ./configure \
        --prefix="${PREFIX}" \
        --host="${HOST}" \
        --build="${SYSTEM}" \
        --enable-static_link \
        --disable-shared \
        --disable-dependency-tracking \
        --disable-nls \
        --with-default-locking-dir=/tmp/lvm \
    || handle_configure_error $?

    $MAKE
    make install DESTDIR="${SYSROOT}"

    touch __package_installed
fi
)

################################################################################
# argon2-20190702
(
PKG_NAME=argon2
PKG_VERSION=20190702
PKG_SOURCE="${PKG_NAME}-${PKG_VERSION}.tar.gz"
PKG_SOURCE_URL="https://github.com/P-H-C/phc-winner-argon2/archive/${PKG_VERSION}.tar.gz"
PKG_SOURCE_SUBDIR="${PKG_NAME}-${PKG_VERSION}"
PKG_HASH="daf972a89577f8772602bf2eb38b6a3dd3d922bf5724d45e7f9589b5e830442c"

mkdir -p "${SRC_ROOT}/${PKG_NAME}"
cd "${SRC_ROOT}/${PKG_NAME}"

if [ ! -f "${PKG_SOURCE_SUBDIR}/__package_installed" ]; then
    rm -rf "${PKG_SOURCE_SUBDIR}"
    download_archive "${PKG_SOURCE_URL}" "${PKG_SOURCE}" "."
    verify_hash "${PKG_SOURCE}" "${PKG_HASH}"
    unpack_archive "${PKG_SOURCE}" "${PKG_SOURCE_SUBDIR}"
    cd "${PKG_SOURCE_SUBDIR}"

    export PREFIX=
    #export LDFLAGS="-static ${LDFLAGS}"

    $MAKE
    make install DESTDIR="${SYSROOT}"

    touch __package_installed
fi
)

################################################################################
# libgpg-error-1.59
(
PKG_NAME=libgpg-error
PKG_VERSION=1.59
PKG_SOURCE="${PKG_NAME}-${PKG_VERSION}.tar.bz2"
PKG_SOURCE_URL="https://gnupg.org/ftp/gcrypt/libgpg-error/${PKG_SOURCE}"
PKG_SOURCE_SUBDIR="${PKG_NAME}-${PKG_VERSION}"
PKG_HASH="a19bc5087fd97026d93cb4b45d51638d1a25202a5e1fbc3905799f424cfa6134"

mkdir -p "${SRC_ROOT}/${PKG_NAME}"
cd "${SRC_ROOT}/${PKG_NAME}"

if [ ! -f "${PKG_SOURCE_SUBDIR}/__package_installed" ]; then
    rm -rf "${PKG_SOURCE_SUBDIR}"
    download_archive "${PKG_SOURCE_URL}" "${PKG_SOURCE}" "."
    verify_hash "${PKG_SOURCE}" "${PKG_HASH}"
    unpack_archive "${PKG_SOURCE}" "${PKG_SOURCE_SUBDIR}"
    cd "${PKG_SOURCE_SUBDIR}"

    ./configure \
        --prefix="${PREFIX}" \
        --host="${HOST}" \
        --build="${SYSTEM}" \
        --enable-static \
        --disable-shared \
        --disable-dependency-tracking \
        --disable-nls \
        --disable-rpath \
        --disable-doc --disable-tests \
        --enable-threads=posix \
    || handle_configure_error $?

    $MAKE
    make install

    touch __package_installed
fi
)

################################################################################
# libgcrypt-1.12.0
(
PKG_NAME=libgcrypt
PKG_VERSION=1.12.0
PKG_SOURCE="${PKG_NAME}-${PKG_VERSION}.tar.bz2"
PKG_SOURCE_URL="https://gnupg.org/ftp/gcrypt/libgcrypt/${PKG_SOURCE}"
PKG_SOURCE_SUBDIR="${PKG_NAME}-${PKG_VERSION}"
PKG_HASH="0311454e678189bad62a7e9402a9dd793025efff6e7449898616e2fc75e0f4f5"

mkdir -p "${SRC_ROOT}/${PKG_NAME}"
cd "${SRC_ROOT}/${PKG_NAME}"

if [ ! -f "${PKG_SOURCE_SUBDIR}/__package_installed" ]; then
    rm -rf "${PKG_SOURCE_SUBDIR}"
    download_archive "${PKG_SOURCE_URL}" "${PKG_SOURCE}" "."
    verify_hash "${PKG_SOURCE}" "${PKG_HASH}"
    unpack_archive "${PKG_SOURCE}" "${PKG_SOURCE_SUBDIR}"
    cd "${PKG_SOURCE_SUBDIR}"

    ./configure \
        --prefix="${PREFIX}" \
        --host="${HOST}" \
        --build="${SYSTEM}" \
        --enable-static \
        --disable-shared \
        --disable-dependency-tracking \
        --disable-nls \
        --disable-rpath \
        --disable-doc \
    || handle_configure_error $?

    $MAKE
    make install

    touch __package_installed
fi
)

################################################################################
# libssh-0.12.0
(
PKG_NAME=libssh
PKG_VERSION=0.12.0
PKG_SOURCE="${PKG_NAME}-${PKG_VERSION}.tar.xz"
PKG_SOURCE_URL="https://www.libssh.org/files/$(echo "$PKG_VERSION" | cut -d. -f1,2)/${PKG_SOURCE}"
PKG_SOURCE_SUBDIR="${PKG_NAME}-${PKG_VERSION}"
PKG_HASH="1a6af424d8327e5eedef4e5fe7f5b924226dd617ac9f3de80f217d82a36a7121"

mkdir -p "${SRC_ROOT}/${PKG_NAME}"
cd "${SRC_ROOT}/${PKG_NAME}"

if [ ! -f "${PKG_SOURCE_SUBDIR}/__package_installed" ]; then
    rm -rf "${PKG_SOURCE_SUBDIR}"
    download_archive "${PKG_SOURCE_URL}" "${PKG_SOURCE}" "."
    verify_hash "${PKG_SOURCE}" "${PKG_HASH}"
    unpack_archive "${PKG_SOURCE}" "${PKG_SOURCE_SUBDIR}"
    cd "${PKG_SOURCE_SUBDIR}"

    rm -rf build
    mkdir -p build
    cd build

    cmake .. \
        -DCMAKE_TOOLCHAIN_FILE=${SRC_ROOT}/arm-musl.toolchain.cmake \
        -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} \
        -DCMAKE_VERBOSE_MAKEFILE=${CMAKE_VERBOSE_MAKEFILE} \
        -DCMAKE_PREFIX_PATH="${PREFIX}" \
        -DCMAKE_INSTALL_PREFIX="${PREFIX}" \
        -DBUILD_SHARED_LIBS=OFF \
        -DWITH_EXAMPLES=OFF \
        -DWITH_ZLIB=ON \
        -DWITH_SFTP=ON \
        -DWITH_SERVER=ON \
        -DWITH_GCRYPT=ON \
        -DWITH_NACL=ON

    $MAKE
    make install

    cd ..

    touch __package_installed
fi
)

################################################################################
# util-linux-2.41.3 (bootstrap)
#
PKG_VERSION__UTIL_LINUX=2.41.3
(
PKG_NAME=util-linux
PKG_VERSION=${PKG_VERSION__UTIL_LINUX}
PKG_SOURCE="${PKG_NAME}-${PKG_VERSION}.tar.xz"
PKG_SOURCE_URL="https://www.kernel.org/pub/linux/utils/util-linux/v$(echo "$PKG_VERSION" | cut -d. -f1,2)/${PKG_SOURCE}"
PKG_SOURCE_SUBDIR="${PKG_NAME}-${PKG_VERSION}"
PKG_BUILD_SUBDIR="${PKG_SOURCE_SUBDIR}-build-bootstrap"
PKG_HASH="3330d873f0fceb5560b89a7dc14e4f3288bbd880e96903ed9b50ec2b5799e58b"

mkdir -p "${SRC_ROOT}/${PKG_NAME}"
cd "${SRC_ROOT}/${PKG_NAME}"

if [ ! -f "${PKG_BUILD_SUBDIR}/__package_installed" ]; then
    download_archive "${PKG_SOURCE_URL}" "${PKG_SOURCE}" "."
    verify_hash "${PKG_SOURCE}" "${PKG_HASH}"
    unpack_archive "${PKG_SOURCE}" "${PKG_SOURCE_SUBDIR}"

    rm -rf "${PKG_BUILD_SUBDIR}"
    mkdir "${PKG_BUILD_SUBDIR}"
    cd "${PKG_BUILD_SUBDIR}"

    ../${PKG_SOURCE_SUBDIR}/configure \
        --prefix="${PREFIX}" \
        --host="${HOST}" \
        --build="${SYSTEM}" \
        --enable-static \
        --disable-shared \
        --disable-dependency-tracking \
        --disable-nls \
        --disable-rpath \
        --without-python \
        --disable-hwclock \
        --disable-use-tty-group --disable-makeinstall-chown --disable-makeinstall-setuid \
        --without-cryptsetup \
        --disable-all-programs \
        --disable-libfdisk \
        --disable-libmount \
        --disable-libsmartcols \
        --enable-libuuid --enable-uuidgen --enable-libblkid \
    || handle_configure_error $?

    $MAKE
    make install

    touch __package_installed
fi
)

################################################################################
# cryptsetup-2.8.4
(
PKG_NAME=cryptsetup
PKG_VERSION=2.8.4
PKG_SOURCE="${PKG_NAME}-${PKG_VERSION}.tar.xz"
PKG_SOURCE_URL="https://www.kernel.org/pub/linux/utils/cryptsetup/v$(echo "$PKG_VERSION" | cut -d. -f1,2)/${PKG_SOURCE}"
PKG_SOURCE_SUBDIR="${PKG_NAME}-${PKG_VERSION}"
PKG_BUILD_SUBDIR="${PKG_SOURCE_SUBDIR}-build-gcrypt"
PKG_HASH="443e46f8964c9acc780f455afbb8e23aa0e8ed7ec504cfc59e04f406fa1e8a83"

mkdir -p "${SRC_ROOT}/${PKG_NAME}"
cd "${SRC_ROOT}/${PKG_NAME}"

if [ ! -f "${PKG_BUILD_SUBDIR}/__package_installed" ]; then
    download_archive "${PKG_SOURCE_URL}" "${PKG_SOURCE}" "."
    verify_hash "${PKG_SOURCE}" "${PKG_HASH}"
    unpack_archive "${PKG_SOURCE}" "${PKG_SOURCE_SUBDIR}"

    rm -rf "${PKG_BUILD_SUBDIR}"
    mkdir "${PKG_BUILD_SUBDIR}"
    cd "${PKG_BUILD_SUBDIR}"

    export PREFIX=
    export LDFLAGS="-L${STAGE_DIR}/lib ${LDFLAGS}"
    export CPPFLAGS="-I${STAGE_DIR}/include ${CPPFLAGS}"
    export LIBS="-lgcrypt -lgpg-error -ldevmapper -luuid -largon2 -ljson-c -lblkid -lpopt -lpthread -ldl -lm -largp"

    ../${PKG_SOURCE_SUBDIR}/configure \
        --prefix="${PREFIX}" \
        --host="${HOST}" \
        --build="${SYSTEM}" \
        --enable-static-cryptsetup \
        --enable-static \
        --disable-shared \
        --disable-dependency-tracking \
        --disable-nls \
        --disable-rpath \
        --enable-libargon2 \
        --enable-year2038 \
        --with-luks2-lock-path=/tmp/cryptsetup \
        --with-crypto_backend=gcrypt \
    || handle_configure_error $?

    $MAKE
    make install DESTDIR="${SYSROOT}"

    touch __package_installed
fi
)

################################################################################
# util-linux-2.41.3 (final)
(
PKG_NAME=util-linux
PKG_VERSION=${PKG_VERSION__UTIL_LINUX}
PKG_SOURCE_SUBDIR="${PKG_NAME}-${PKG_VERSION}"
PKG_BUILD_SUBDIR="${PKG_SOURCE_SUBDIR}-build-final"

mkdir -p "${SRC_ROOT}/${PKG_NAME}"
cd "${SRC_ROOT}/${PKG_NAME}"

if [ ! -f "${PKG_BUILD_SUBDIR}/__package_installed" ]; then
    rm -rf "${PKG_BUILD_SUBDIR}"
    mkdir "${PKG_BUILD_SUBDIR}"
    cd "${PKG_BUILD_SUBDIR}"

    ../${PKG_SOURCE_SUBDIR}/configure \
        --prefix="${PREFIX}" \
        --host="${HOST}" \
        --build="${SYSTEM}" \
        --enable-static \
        --disable-shared \
        --disable-dependency-tracking \
        --disable-nls \
        --disable-rpath \
        --without-python \
        --with-cryptsetup \
        --disable-hwclock \
        --disable-use-tty-group --disable-makeinstall-chown --disable-makeinstall-setuid \
    || handle_configure_error $?

    $MAKE
    make install

    touch __package_installed
fi
)


) #END sub-shell
set +x
echo ""
echo "[*] Finished compiling ${PKG_ROOT} ${PKG_ROOT_VERSION}"
echo ""

return 0
} #END download_and_compile()

################################################################################
# Initialize
#
PATH_CMD="$(readlink -f -- "$0")"
SCRIPT_DIR="$(dirname -- "$(readlink -f -- "$0")")"
PARENT_DIR="$(dirname -- "$(dirname -- "$(readlink -f -- "$0")")")"
CACHED_DIR="${PARENT_DIR}/solartracker-sources"
FILE_DOWNLOADER='use_wget'
#FILE_DOWNLOADER='use_curl'
#FILE_DOWNLOADER='use_curl_socks5_proxy'; CURL_SOCKS5_PROXY="192.168.1.1:9150"
set -e
set -x
# Workaround for autotools system name detection when cross-compiling
SYSTEM="$(system_name "${SCRIPT_DIR}/files/config.guess")"

################################################################################
# Enter main
#
main
echo ""
echo "[*] Script exited cleanly."
echo ""

