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
    local -r FILE="$1"

    # The actual file content does not have a public link, only a Artifact viewer link is available. Retrieve raw file via some simple web scrapping
    # Actual file link is stored in JS object. Extract JSON literal from JS source via sed, then extract property via jq
    grep "/${FILE}?" \
        <( curl "https://ci.android.com/builds/submitted/${BUILD_NUMBER}/${BUILD_TARGET}/latest/view/${FILE}" -L ) \
        | sed -E -e "s/^[ \t]+var[ \t]+JSVariables[ \t=]+//" -e "s/[ \t]*;[ \t]*$//" \
        | jq -r '."artifactUrl"' \
        > "${FILE}.link"
    curl "$(cat "${FILE}.link")" -L > "${FILE}" # Fetch actual ${FILE}
}

fetchArtifactList() {
    grep -P 'var[ ]+JSVariables[ =]+\{.*}[ ]*;' \
        <( curl "https://ci.android.com/builds/submitted/${BUILD_NUMBER}/${BUILD_TARGET}/latest" -L ) \
        | sed -E -e "s/^[ \t]+var[ \t]+JSVariables[ \t=]+//" -e "s/[ \t]*;[ \t]*$//" \
        | jq -r '."artifacts"[]."name"' \
        > "artifacts_list"
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
    cd "${IMAGE_DIR}"
    rm -rf ./* # Clean up previously fetched files

    # Create artifact list
    fetchArtifactList

    # Iterate all artifacts and download them
    local -a ARTIFACTS
    mapfile -t ARTIFACTS < <(cat "artifacts_list" \
        | grep --invert-match 'attempts/' \
    )
    declare -r ARTIFACTS
    local -r BUILD="${BUILD_TARGET%-*}"
    for ARTIFACT in "${ARTIFACTS[@]}"; do
        # Only fetch files that can be meaningfully compared to local build
        if [[ "${ARTIFACT}" == "manifest_"*".xml" ]] || [[ "${ARTIFACT}" == "${BUILD}-img-${BUILD_NUMBER}.zip" ]] || [[ "${ARTIFACT}" == *".img" ]]; then
            if [[ "${ARTIFACT}" == *"/"* ]]; then
                local DIR="${ARTIFACT%%/*}"
                mkdir -p "${DIR}"
            fi

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
