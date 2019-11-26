#!/bin/bash
set -ex

# Argument sanity check
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <BUILD_TARGET>"
	echo "BUILD_TARGET: Tuple of <BUILD>-<BUILDTYPE>, see https://source.android.com/setup/build/building#choose-a-target for details."
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

# Navigate to src dir and init build
SRC_DIR="${RB_AOSP_BASE}/src"
# Build lpunpack tool that enables us to decompress dynamic partitions (i.e. super.img)
cd "${SRC_DIR}"
source ./build/envsetup.sh
lunch "${BUILD_TARGET}" # Might not be needed (see sample from https://android.googlesource.com/platform/system/extras/+/1f0277a%5E%21/)
mm -j $(nproc) lpunpack
