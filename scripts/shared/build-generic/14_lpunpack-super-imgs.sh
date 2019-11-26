#!/bin/bash
set -ex

# Argument sanity check
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <BUILD_NUMBER> <BUILD_TARGET>"
	echo "BUILD_NUMBER: Google internal incremental build number that identifies each build, see https://android.googlesource.com/platform/build/+/master/Changes.md#BUILD_NUMBER"
	echo "BUILD_TARGET: Build target as choosen in lunch (consist of <TARGET_PRODUCT>-<TARGET_BUILD_VARIANT>"
    exit 1
fi
BUILD_NUMBER="$1"
BUILD_TARGET="$2"
# Reproducible base directory
if [ -z "${RB_AOSP_BASE+x}" ]; then
    # Use default location
    RB_AOSP_BASE="${HOME}/aosp"
	mkdir -p "${RB_AOSP_BASE}"
fi

# lpunpack binary from previously built target
BUILD_DIR="${RB_AOSP_BASE}/src/out"
LPUNPACK_BIN="${BUILD_DIR}/host/linux-x86/bin/lpunpack"

# Unpack super.img from GoogleCI build
BUILD_ENV="GoogleCI"
TARGET_DIR="${RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET}/${BUILD_ENV}"
"${LPUNPACK_BIN}" "${TARGET_DIR}/super.img" "${TARGET_DIR}"
