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
        echo "Usage: $0 <BUILD_TARGET>"
        echo "BUILD_TARGET: Tuple of <BUILD>-<BUILDTYPE>, see https://source.android.com/setup/build/building#choose-a-target for details."
        exit 1
    fi
    local -r BUILD_TARGET="$1"
    # Reproducible base directory
    if [[ -z "${RB_AOSP_BASE+x}" ]]; then
        # Use default location
        local -r RB_AOSP_BASE="${HOME}/aosp"
        mkdir -p "${RB_AOSP_BASE}"
    fi

    # Navigate to src dir and init build
    local -r SRC_DIR="${RB_AOSP_BASE}/src"
    # Build lpunpack tool that enables us to decompress dynamic partitions (i.e. super.img)
    cd "${SRC_DIR}"
    # Unfortunately envsetup doesn't work with nounset flag, specifically fails with:
    # ./build/envsetup.sh: line 361: ZSH_VERSION: unbound variable
    set +o nounset
    source ./build/envsetup.sh
    lunch "${BUILD_TARGET}" # Might not be needed (see sample from https://android.googlesource.com/platform/system/extras/+/1f0277a%5E%21/)
    mm -j $(nproc) lpunpack
    set -o nounset
}

main "$@"
