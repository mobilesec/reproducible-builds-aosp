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

unpackSuper() {
    local -r BUILD_TARGET="$1"
    local -r BUILD_ENV="$2"
    local -r TARGET_DIR="${RB_AOSP_BASE}/build/${AOSP_REF_OR_BUILD_NUMBER}/${BUILD_TARGET}/${BUILD_ENV}"

    # Only perform unpacking a super image exists
    if [[ -f "${TARGET_DIR}/super.img" ]]; then
        local SUPER_IMG="${TARGET_DIR}/super.img"

        # Detect sparse image
        set +o errexit # Disable early exit
        file "${SUPER_IMG}" | grep 'Android sparse image'
        if [[ "$?" -eq 0 ]]; then
            set -o errexit # Re-enable early exit
            # Decompress into raw image
            "${AOSP_HOST_BIN}/simg2img" "${TARGET_DIR}/super.img" "${TARGET_DIR}/super.img.raw"
            SUPER_IMG="${TARGET_DIR}/super.img.raw"
        fi
        set -o errexit # Re-enable early exit

        "${AOSP_HOST_BIN}/lpunpack" "${SUPER_IMG}" "${TARGET_DIR}"   
    fi
}

main() {
    # Argument sanity check
    if [[ "$#" -ne 3 ]]; then
        echo "Usage: $0 [ <AOSP_REF> | <BUILD_NUMBER> ] <GOOGLE_BUILD_TARGET> <RB_BUILD_TARGET>"
        echo "AOSP_REF or BUILD_NUMBER: Tag/Branch reference or Google internal build number"
        echo "GOOGLE_BUILD_TARGET: Google build target as choosen in lunch (consist of <TARGET_PRODUCT>-<TARGET_BUILD_VARIANT>"
        echo "RB_BUILD_TARGET: Our build target as choosen in lunch (consist of <TARGET_PRODUCT>-<TARGET_BUILD_VARIANT>"
        exit 1
    fi
    local -r AOSP_REF_OR_BUILD_NUMBER="$1"
    local -r GOOGLE_BUILD_TARGET="$2"
    local -r RB_BUILD_TARGET="$3"
    # Reproducible base directory
    if [[ -z "${RB_AOSP_BASE+x}" ]]; then
        # Use default location
        local -r RB_AOSP_BASE="${HOME}/aosp"
        mkdir -p "${RB_AOSP_BASE}"
    fi

    # General location of host binaries
    local -r AOSP_HOST_BIN="${RB_AOSP_BASE}/src/out/host/linux-x86/bin"
    # Environment names used for build paths
    local -r GOOGLE_BUILD_ENV="Google"
    local -r RB_BUILD_ENV="$(lsb_release -si)$(lsb_release -sr)"
    
    unpackSuper "${GOOGLE_BUILD_TARGET}" "${GOOGLE_BUILD_ENV}"
    unpackSuper "${RB_BUILD_TARGET}" "${RB_BUILD_ENV}"
}

main "$@"
