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
    if [[ "$#" -ne 1 ]]; then
        echo "Usage: $0 <AOSP_REF>"
        echo "AOSP_REF: Branch or Tag in AOSP, refer to https://source.android.com/setup/start/build-numbers#source-code-tags-and-builds"
        exit 1
    fi
    local -r AOSP_REF="$1"
    # Reproducible base directory
    if [[ -z "${RB_AOSP_BASE+x}" ]]; then
        # Use default location
        local -r RB_AOSP_BASE="${HOME}/aosp"
        mkdir -p "${RB_AOSP_BASE}"
    fi

    # Follow steps from https://source.android.com/setup/build/downloading#initializing-a-repo-client
    local -r SRC_DIR="${RB_AOSP_BASE}/src"
    mkdir -p "${SRC_DIR}"
    cd "${SRC_DIR}"
    rm -rf ./* # Clean up previously checked out files

    # Init repo for a named AOSP Ref, i.e. a branch or Tag
    repo init -u "https://android.googlesource.com/platform/manifest" -b "${AOSP_REF}"
    repo sync -j "$(nproc)"
}

main "$@"
