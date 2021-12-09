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

main() {
    # Argument sanity check
    if [[ "$#" -ne 2 ]]; then
        echo "Usage: $0 <BUILD_NUMBER> <BUILD_TARGET>"
        echo "BUILD_NUMBER: GoogleCI internal incremental build number that identifies each build, see https://android.googlesource.com/platform/build/+/master/Changes.md#BUILD_NUMBER"
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

    # See https://source.android.com/setup/build/downloading#initializing-a-repo-client for the general concept
    # Init src repo for the current master (create .repo folder structure, registers manifest git)
    local -r SRC_DIR="${RB_AOSP_BASE}/src"
    mkdir -p "${SRC_DIR}"
    cd "${SRC_DIR}"
    rm -rf ./* # Clean up previously checked out files
    repo init -u "https://android.googlesource.com/platform/manifest"

    # Copy custom and manifest
    local -r BUILD_ENV="Google"
    local -r IMAGE_DIR="${RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET}/${BUILD_ENV}"
    local -r MANIFESTS_DIR="${SRC_DIR}/.repo/manifests"
    local -r CUSTOM_MANIFEST="manifest_${BUILD_NUMBER}.xml"
    cp "${IMAGE_DIR}/${CUSTOM_MANIFEST}" "${MANIFESTS_DIR}/"

    # Inform repo about custom manifest and sync it
    repo init -m "${CUSTOM_MANIFEST}" --depth=1
    repo sync -c -j "$(nproc)"
}

main "$@"
