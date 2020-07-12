#!/bin/bash
set -o errexit -o nounset -o pipefail -o xtrace

unpackSuper() {
    local -r BUILD_ENV="$1"
    local -r TARGET_DIR="${RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET}/${BUILD_ENV}"

    # Only perform unpacking if either system or vendor are missing and we do have super image
    if [[ ! -f "${TARGET_DIR}/system.img" ]] || [[ ! -f "${TARGET_DIR}/vendor.img" ]]; then
        if [[ -f "${TARGET_DIR}/super.img" ]]; then
            "${AOSP_HOST_BIN}/lpunpack" "${TARGET_DIR}/super.img" "${TARGET_DIR}"   
        fi
    fi
}

main() {
    # Argument sanity check
    if [[ "$#" -ne 2 ]]; then
        echo "Usage: $0 <BUILD_NUMBER> <BUILD_TARGET>"
        echo "BUILD_NUMBER: Google internal incremental build number that identifies each build, see https://android.googlesource.com/platform/build/+/master/Changes.md#BUILD_NUMBER"
        echo "BUILD_TARGET: Build target as choosen in lunch (consist of <TARGET_PRODUCT>-<TARGET_BUILD_VARIANT>"
        exit 1
    fi
    local -r BUILD_NUMBER="$1"
    local -r BUILD_TARGET="$2"
    # Reproducible base directory
    if [[ -z "${RB_AOSP_BASE+x}" ]]; then
        # Use default location
        local -r RB_AOSP_BASE="${HOME}/aosp"
        mkdir -p "${RB_AOSP_BASE}"
    fi

    # General location of host binaries
    local -r AOSP_HOST_BIN="${RB_AOSP_BASE}/src/out/host/linux-x86/bin"
    # Environment names used for build paths
    local -r GOOGLE_BUILD_ENV="Google"
    local -r RB_BUILD_ENV="$(lsb_release -si)$(lsb_release -sr)"
    
    unpackSuper "${GOOGLE_BUILD_ENV}"
    unpackSuper "${RB_BUILD_ENV}"
}

main "$@"
