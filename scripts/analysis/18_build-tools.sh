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
    if [[ "$#" -ne 0 ]]; then
        echo "Usage: $0"
        exit 1
    fi
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
    source "./build/envsetup.sh"

    # Build libsparse to ensure we have a simg2img tool available in the host tools
    ( cd "./system/core/libsparse" && mma )

    if [[ -f "./system/extras/partition_tools/lpunpack.cc" ]]; then
        # Build lpunpack, used to decompose super.img into separate images
        # See sample from https://android.googlesource.com/platform/system/extras/+/1f0277a%5E%21/
        #lunch "${BUILD_TARGET}"
        mm -j "$(nproc)" lpunpack
    fi

    set -o nounset
}

main "$@"
