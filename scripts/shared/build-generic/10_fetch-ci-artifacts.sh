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

function fetchFromAndroidCI {
    FILE="$1"

    # The actual file content does not have a public link, only a Artifact viewer link is available. Retrieve raw file via some simple web scrapping
    # Actual file link is stored in JS object. Extract JSON literal from JS source via sed, then extract property via jq
    curl "https://ci.android.com/builds/submitted/${BUILD_NUMBER}/${BUILD_TARGET}/latest/view/${FILE}" -L \
        | grep "artifacts/${FILE}" \
        | sed -E -e "s/^[ \t]+var[ \t]+JSVariables[ \t=]+//" -e "s/[ \t]*;[ \t]*$//" \
        | jq -r '."artifactUrl"' \
        > "${IMAGE_DIR}/${FILE}.link"
    curl "$(cat "${IMAGE_DIR}/${FILE}.link")" -L > "${IMAGE_DIR}/${FILE}" # Fetch actual ${FILE}
}

function fetchArtifactList {
   	curl "https://ci.android.com/builds/submitted/${BUILD_NUMBER}/${BUILD_TARGET}/latest" -L \
	| grep -P 'var[ ]+JSVariables[ =]+\{.*}[ ]*;' \
	| sed -E -e "s/^[ \t]+var[ \t]+JSVariables[ \t=]+//" -e "s/[ \t]*;[ \t]*$//" \
	| jq -r '."artifacts"[]."name"' \
	> "${IMAGE_DIR}/artifacts_list"
}


# Fetch manifest from Google CI build
BUILD_ENV="GoogleCI"
IMAGE_DIR="${RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET}/${BUILD_ENV}"
mkdir -p "${IMAGE_DIR}"

# Create artifact list
fetchArtifactList

# Iterate all artifacts and download them
ARTIFACTS=($(cat "${IMAGE_DIR}/artifacts_list"))
for ARTIFACT in "${ARTIFACTS[@]}"; do
	# Only fetch files that can be meaningfully compared to local build
	if [[ "${ARTIFACT}" == "android-info.txt" ]] || [[ "${ARTIFACT}" == "installed-files"* ]] || [[ "${ARTIFACT}" == *".img" ]]; then
		if [[ "${ARTIFACT}" == *"/"* ]]; then
			DIR="${ARTIFACT%%/*}"
			mkdir -p "${IMAGE_DIR}/${DIR}"
		fi

		echo "${ARTIFACT}"
		fetchFromAndroidCI ${ARTIFACT}
	fi
done

