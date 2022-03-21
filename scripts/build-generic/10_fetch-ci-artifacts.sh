#!/bin/bash

# Copyright 2020 Manuel Pöll
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit -o nounset -o pipefail -o xtrace

fetchFromAndroidCI() {
    local -r REMOTE_FILE="$1"
    local -r LOCAL_FILE="${REMOTE_FILE##*/}" # Don't preserve directories locally

    # The actual file content does not have a public link, only a Artifact viewer link is available. Retrieve raw file via some simple web scrapping
    # Actual file link is stored in JS object. Extract JSON literal from JS source via sed, then extract property via jq
    grep "/${REMOTE_FILE}?" \
        <( curl "https://ci.android.com/builds/submitted/${BUILD_NUMBER}/${BUILD_TARGET}/latest/view/${REMOTE_FILE}" -L ) \
        | sed -E -e "s/^[ \t]+var[ \t]+JSVariables[ \t=]+//" -e "s/[ \t]*;[ \t]*$//" \
        | jq -r '."artifactUrl"' \
        > "${LOCAL_FILE}.link"
    curl "$(cat "${LOCAL_FILE}.link")" -L > "${LOCAL_FILE}" # Fetch actual file
}

fetchArtifactList() {
    grep -P 'var[ ]+JSVariables[ =]+\{.*}[ ]*;' \
        <( curl "https://ci.android.com/builds/submitted/${BUILD_NUMBER}/${BUILD_TARGET}/latest" -L ) \
        | sed -E -e "s/^[ \t]+var[ \t]+JSVariables[ \t=]+//" -e "s/[ \t]*;[ \t]*$//" \
        | jq -r '."artifacts"[]."name"' \
        > "$ARTIFACTS_LIST_FILE"
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

    # Allow usage of cached CI images locally
    if [[ -d "${IMAGE_DIR}" ]]; then
        exit 0
    fi

    mkdir -p "${IMAGE_DIR}"
    cd "${IMAGE_DIR}"
    rm -rf ./* # Clean up previously fetched files

    # Create artifact list
    local -r ARTIFACTS_LIST_FILE="artifacts_list"
    fetchArtifactList

    # Iterate all artifacts and download them
    local -a ARTIFACTS
    mapfile -t ARTIFACTS < <(grep --invert-match 'attempts/' "$ARTIFACTS_LIST_FILE" )
    # Some builds of the Android CI take multiple attempts, detect latest attempt
    local ARTIFACT_PREFIX="$(cat "$ARTIFACTS_LIST_FILE" \
        | grep --extended-regexp 'attempts/[0-9]+/' \
        | sort \
        | tail --lines=1 \
        | cut --delimiter=/ --fields=1-2 \
        | xargs -I '%' echo '%/' \
    )"
    # As an exception to the above, an existing attempt may not have the required manifest file, sanity check for this
    if ! grep "${ARTIFACT_PREFIX}manifest_${BUILD_NUMBER}.xml" "$ARTIFACTS_LIST_FILE"; then
        local ARTIFACT_PREFIX=""
    fi

    mapfile -t -O "${#ARTIFACTS[@]}" ARTIFACTS < <(grep "$ARTIFACT_PREFIX" "$ARTIFACTS_LIST_FILE" )
    declare -r ARTIFACTS
    local -r BUILD="${BUILD_TARGET%-*}"
    for ARTIFACT in "${ARTIFACTS[@]}"; do
        # Only fetch files that can be meaningfully compared to local build (+ manifest)
        if [[ "${ARTIFACT}" == "${BUILD}-img-${BUILD_NUMBER}.zip" \
            || "${ARTIFACT}" == "${ARTIFACT_PREFIX}manifest_${BUILD_NUMBER}.xml" \
            || "${ARTIFACT}" == *".img" ]]; then

            echo "${ARTIFACT}"
            fetchFromAndroidCI "${ARTIFACT}"
        fi
    done
    
    # Some images don't exist in artifact list directly, but need to be unzipped
    if [[ -f "${BUILD}-img-${BUILD_NUMBER}.zip" ]]; then
        unzip -o "${BUILD}-img-${BUILD_NUMBER}.zip"
        rm "${BUILD}-img-${BUILD_NUMBER}.zip"
    fi
}

main "$@"
