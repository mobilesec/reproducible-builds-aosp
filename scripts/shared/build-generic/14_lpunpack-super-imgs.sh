#!/bin/bash
set -o errexit -o nounset -o pipefail -o xtrace

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

    # lpunpack binary from previously built target
    local -r AOSP_HOST_BIN="${RB_AOSP_BASE}/src/out/host/linux-x86/bin"

    # Unpack super.img from GoogleCI build
    local -r BUILD_ENV="GoogleCI"
    local -r TARGET_DIR="${RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET}/${BUILD_ENV}"
    "${AOSP_HOST_BIN}/lpunpack" "${TARGET_DIR}/super.img" "${TARGET_DIR}"
}

main "$@"
