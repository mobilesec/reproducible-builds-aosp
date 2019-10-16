#!/bin/bash

# Argument sanity check
if [ "$#" -ne 1 ]; then
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
    RB_AOSP_BASE="/home/${USER}/aosp"
	mkdir -p "${RB_AOSP_BASE}"
fi

# Start with the usual repo init/sync (implicitly checks out master)
# Follow steps from https://source.android.com/setup/build/downloading#initializing-a-repo-client
SRC_DIR="${RB_AOSP_BASE}/aosp/src"
mkdir -p "${SRC_DIR}"
cd "${SRC_DIR}"

# Init repo for the desired version
repo init -u "https://android.googlesource.com/platform/manifest"
repo sync -j $(nproc)

# Checkout proper manifest version
BUILD_ENV="GoogleCI"
IMAGE_DIR="${RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET}/${BUILD_ENV}"
# TODO: Perform checkout via jq
