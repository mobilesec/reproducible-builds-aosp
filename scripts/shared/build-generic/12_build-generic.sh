#!/bin/bash
set -ex

# Argument sanity check
if [[ "$#" -ne 2 ]]; then
    echo "Usage: $0 <BUILD_NUMBER> <BUILD_TARGET>"
	echo "BUILD_NUMBER: GoogleCI internal incremental build number that identifies each build, see https://android.googlesource.com/platform/build/+/master/Changes.md#BUILD_NUMBER"
	echo "BUILD_TARGET: Tuple of <BUILD>-<BUILDTYPE>, see https://source.android.com/setup/build/building#choose-a-target for details."
    exit 1
fi
BUILD_NUMBER="$1"
BUILD_TARGET="$2"
# Reproducible base directory
if [[ -z "${RB_AOSP_BASE+x}" ]]; then
	# Use default location
	RB_AOSP_BASE="${HOME}/aosp"
	mkdir -p "${RB_AOSP_BASE}"
fi

# Navigate to src dir and init build
SRC_DIR="${RB_AOSP_BASE}/src"
# Communicate custom build dir to soong build system.
#export OUT_DIR_COMMON_BASE="${BUILD_DIR}" # Deactivated on purpose (Shared build dir leeds to build artifact caching)
cd "${SRC_DIR}"
source ./build/envsetup.sh
lunch "${BUILD_TARGET}"
m -j $(nproc)

# Copy relevant build output from BUILD_DIR to TARGET_DIR for further analysis
BUILD_DIR="${SRC_DIR}/out"
BUILD_ENV="$(lsb_release -si)$(lsb_release -sr)"
TARGET_DIR="${RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET}/${BUILD_ENV}"
mkdir -p "${TARGET_DIR}"
cp "${BUILD_DIR}/target/product/generic"/*.img "${TARGET_DIR}"
cp "${BUILD_DIR}/target/product/generic"/installed-files* "${TARGET_DIR}"
cp "${BUILD_DIR}/target/product/generic/android-info.txt" "${TARGET_DIR}"
