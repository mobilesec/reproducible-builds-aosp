#!/bin/bash
set -o errexit -o nounset -o pipefail -o xtrace

fetchFromAndroidCI() {
    local -r FILE="$1"

    # The actual file content does not have a public link, only a Artifact viewer link is available. Retrieve raw file via some simple web scrapping
    # Actual file link is stored in JS object. Extract JSON literal from JS source via sed, then extract property via jq
    grep "artifacts/${FILE}" \
        <( curl "https://ci.android.com/builds/submitted/${BUILD_NUMBER}/${BUILD_TARGET}/latest/view/${FILE}" -L ) \
        | sed -E -e "s/^[ \t]+var[ \t]+JSVariables[ \t=]+//" -e "s/[ \t]*;[ \t]*$//" \
        | jq -r '."artifactUrl"' \
        > "${IMAGE_DIR}/${FILE}.link"
    curl "$(cat "${IMAGE_DIR}/${FILE}.link")" -L > "${IMAGE_DIR}/${FILE}" # Fetch actual ${FILE}
}

fetchArtifactList() {
    grep -P 'var[ ]+JSVariables[ =]+\{.*}[ ]*;' \
        <( curl "https://ci.android.com/builds/submitted/${BUILD_NUMBER}/${BUILD_TARGET}/latest" -L ) \
        | sed -E -e "s/^[ \t]+var[ \t]+JSVariables[ \t=]+//" -e "s/[ \t]*;[ \t]*$//" \
        | jq -r '."artifacts"[]."name"' \
        > "${IMAGE_DIR}/artifacts_list"
}

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

    # Fetch manifest from Google CI build
    local -r BUILD_ENV="Google"
    local -r IMAGE_DIR="${RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET}/${BUILD_ENV}"
    mkdir -p "${IMAGE_DIR}"
    rm -rf "${IMAGE_DIR}/"* # Clean up previously fetched files

    # Create artifact list
    fetchArtifactList

    # Iterate all artifacts and download them
    local -ar ARTIFACTS=($(cat "${IMAGE_DIR}/artifacts_list"))
    for ARTIFACT in "${ARTIFACTS[@]}"; do
        # Only fetch files that can be meaningfully compared to local build
        if [[ "${ARTIFACT}" == "manifest_"*".xml" ]] || [[ "${ARTIFACT}" == "android-info.txt" ]] || [[ "${ARTIFACT}" == "installed-files"* ]] || [[ "${ARTIFACT}" == *".img" ]]; then
            if [[ "${ARTIFACT}" == *"/"* ]]; then
                local DIR="${ARTIFACT%%/*}"
                mkdir -p "${IMAGE_DIR}/${DIR}"
            fi

            echo "${ARTIFACT}"
            fetchFromAndroidCI ${ARTIFACT}
        fi
    done
}

main "$@"
