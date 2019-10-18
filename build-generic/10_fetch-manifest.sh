#!/bin/bash

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
    RB_AOSP_BASE="/home/${USER}/aosp"
	mkdir -p "${RB_AOSP_BASE}"
fi

function fetchFromGoogleCI {
    FILE="$1"

    # The actual file content does not have a public link, only a Artifact viewer link is available. Retrieve raw file via some simple web scrapping
    # Actual file link is stored in JS object. Extract JSON literal from JS source via sed, then extract property via jq
    curl "https://ci.android.com/builds/submitted/${BUILD_NUMBER}/${BUILD_TARGET}/latest/view/${FILE}" -L \
        | grep "artifacts/${FILE}" \
        | sed -n "s/^[^{]*\([^}]*\}\).*$/\1/p" \
        | jq -r '."artifactUrl"' \
        > "${IMAGE_DIR}/${FILE}.link"
    curl "$(cat "${IMAGE_DIR}/${FILE}.link")" -L > "${IMAGE_DIR}/${FILE}" # Fetch actual ${FILE}
}

# Fetch manifest from Google CI build
BUILD_ENV="GoogleCI"
IMAGE_DIR="${RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET}/${BUILD_ENV}"
mkdir -p "${IMAGE_DIR}"
fetchFromGoogleCI "manifest_${BUILD_NUMBER}.xml"