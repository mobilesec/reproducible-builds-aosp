#!/bin/bash

# Argument sanity check
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <BUILD_NUMBER> <BUILD_TARGET>"
	echo "BUILD_NUMBER: Googlei internal incremental build number that identifies each build, see https://android.googlesource.com/platform/build/+/master/Changes.md#BUILD_NUMBER"
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

# See https://source.android.com/setup/build/downloading#initializing-a-repo-client for the general concept
# Init src repo for the current master (create .repo folder structure, registers manifest git)
SRC_DIR="${RB_AOSP_BASE}/src"
mkdir -p "${SRC_DIR}"
cd "${SRC_DIR}"
repo init -u "https://android.googlesource.com/platform/manifest"

# Copy custom and manifest
BUILD_ENV="GoogleCI"
IMAGE_DIR="${RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET}/${BUILD_ENV}"
MANIFESTS_DIR="${SRC_DIR}/.repo/manifests"
CUSTOM_MANIFEST="manifest_${BUILD_NUMBER}.xml"
cp "${IMAGE_DIR}/${CUSTOM_MANIFEST}" "${MANIFESTS_DIR}/"

# Inform repo about custom manifest and sync it
repo init -m "${CUSTOM_MANIFEST}"
repo sync -j $(nproc)
