#!/bin/bash

# Argument sanity check
if [ "$#" -ne 3 ]; then
    echo "Usage: $0 <aosp-ref> <build-target> <device>"
	echo "aosp-ref: Branch or Tag in AOSP, refer to https://source.android.com/setup/start/build-numbers#source-code-tags-and-builds"
	echo "build-target: Tuple of <BUILD>-<BUILDTYPE>, see https://source.android.com/setup/build/building#choose-a-target for details."
	echo "device: Simply the codename for the target device, see https://source.android.com/setup/build/running#booting-into-fastboot-mode"
    exit 1
fi
AOSP_REF="$1"
BUILD_TARGET="$2"
DEVICE="$3"
# Reproducible base directory
if [ -z "${RB_AOSP_BASE+x}" ]; then
	# Use default location
	RB_AOSP_BASE="${HOME}/aosp"
	mkdir -p "${RB_AOSP_BASE}"
fi

# Navigate to src dir and init build
SRC_DIR="${RB_AOSP_BASE}/src"
BUILD_DIR="${SRC_DIR}/out"
# Communicate custom build dir to soong build system.
#export OUT_DIR_COMMON_BASE="${BUILD_DIR}" # Deactivated on purpose (Shared build dir leeds to build artifact caching)
cd "${SRC_DIR}"
source ./build/envsetup.sh
lunch "${BUILD_TARGET}"
m -j $(nproc)

# Copy relevant build output from BUILD_DIR to TARGET_DIR for further analysis
BUILD_ENV="$(lsb_release -si)$(lsb_release -sr)"
TARGET_DIR="${RB_AOSP_BASE}/build/${AOSP_REF}/${BUILD_TARGET}/${BUILD_ENV}"
mkdir -p "${TARGET_DIR}"
cp "${BUILD_DIR}/target/product/${DEVICE}"/*.img "${TARGET_DIR}"
cp "${BUILD_DIR}/target/product/${DEVICE}/android-info.txt" "${TARGET_DIR}"

