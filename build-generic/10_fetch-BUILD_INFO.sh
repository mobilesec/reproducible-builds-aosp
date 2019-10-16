#!/bin/bash

# Argument sanity check
if [ "$#" -ne 1 ]; then
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
    RB_AOSP_BASE="/home/${USER}/aosp"
	mkdir -p "${RB_AOSP_BASE}"
fi

# Unfortunately checking out a specific BUILD_NUMBER is a bit involved. The build number does not exist in any git repo (AFAIK).
# The only source found for associating BUILD_NUMBER to commits is the BUILD_INFO file emmited from Google CI platform builds. Fetch that file and parse it via jq
# The actual file content does not have a public link, only a Artifact viewer link is available. Retrieve raw file via some simple web scrapping
BUILD_ENV="GoogleCI"
IMAGE_DIR="${RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET}/${BUILD_ENV}"
mkdir -p "${IMAGE_DIR}"
curl "https://ci.android.com/builds/submitted/${BUILD_NUMBER}/${BUILD_TARGET}/latest/view/BUILD_INFO" \
    | grep 'BUILD_INFO?' \
    | sed -n "s/^.*artifactUrl\"\s*:\s*\"\s*\([^\"]*\)\".*$/\1/p" \
    > "${IMAGE_DIR}/BUILD_INFO.link"
echo -ne "$(cat "${IMAGE_DIR}/BUILD_INFO.link")" > "${IMAGE_DIR}/BUILD_INFO.link" # Reverse escaping of special characters (e.g. '\u0026' to &)
curl "$(cat "${IMAGE_DIR}/BUILD_INFO.link")" -L > "${IMAGE_DIR}/BUILD_INFO" # Fetch actual BUILD_INFO
