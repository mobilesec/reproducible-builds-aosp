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
        echo "BUILD_TARGET: Tuple of <BUILD>-<BUILDTYPE>, see https://source.android.com/setup/build/building#choose-a-target for details."
        exit 1
    fi
    local -r BUILD_NUM="$1"
    local -r BUILD_TARGET="$2"
    # Reproducible base directory
    if [[ -z "${RB_AOSP_BASE+x}" ]]; then
        # Use default location
        local -r RB_AOSP_BASE="${HOME}/aosp"
        mkdir -p "${RB_AOSP_BASE}"
    fi

    local -r SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
    source "${SCRIPT_DIR}/../../scripts/common/utils.sh"

    # Navigate to src dir and init build
    local -r SRC_DIR="${RB_AOSP_BASE}/src"
    cd "${SRC_DIR}"
    rm -rf "./out" # Clean

    # Keep sourcing of envsetup in subshell since we use soong_ui.bash invocation from Android CI directly
    (
        # Unfortunately envsetup doesn't work with nounset flag, specifically fails with:
        # ./build/envsetup.sh: line 361: ZSH_VERSION: unbound variable
        set +o nounset
        source "./build/envsetup.sh"

        # Build libsparse to ensure we have a simg2img tool available in the host tools
        ( cd "./system/core/libsparse" && mma )
        set -o nounset
    )

    # Set BUILD_DATETIME, BUILD_NUMBER, BUILD_USERNAME and BUILD_HOSTNAME
    local -r SYSTEM_IMG="${RB_AOSP_BASE}/build/${BUILD_NUM}/${BUILD_TARGET}/Google/system.img"
    setAdditionalBuildEnvironmentVars "$SYSTEM_IMG"

    rm -rf "./out" # Clean
    # Split into <BUILD> and <BUILDTYPE>
    local -r BUILD="${BUILD_TARGET%-*}"
    local -r BUILDTYPE="${BUILD_TARGET##*-}"
    # Run the same build instruction as the Android CI
    FORCE_BUILD_LLVM_COMPONENTS="true" build/soong/soong_ui.bash \
        "--make-mode" "TARGET_PRODUCT=${BUILD}" "TARGET_BUILD_VARIANT=${BUILDTYPE}" \
        "dist" \
        "installclean"

    FORCE_BUILD_LLVM_COMPONENTS="true" build/soong/soong_ui.bash \
        "--make-mode" "TARGET_PRODUCT=${BUILD}" "TARGET_BUILD_VARIANT=${BUILDTYPE}" \
        "droid" \
        "dist" \
        -j "$(nproc)" # Addition by us, Google uses NINJA_REMOTE_NUM_JOBS="500" variable for this

    # Prepare TARGET_DIR as destination for relevant build output. Used for further analysis
    local -r BUILD_DIR="${SRC_DIR}/out"
    local -r BUILD_ENV="$(lsb_release -si)$(lsb_release -sr)"
    local -r TARGET_DIR="${RB_AOSP_BASE}/build/${BUILD_NUM}/${BUILD_TARGET}/${BUILD_ENV}"
    mkdir -p "${TARGET_DIR}"
    # Copy relevant build output from BUILD_DIR to TARGET_DIR
    cp "${BUILD_DIR}/dist"/*.img "${TARGET_DIR}"
    cp "${BUILD_DIR}/dist/${BUILD}-img-${BUILD_NUM}.zip" "${TARGET_DIR}"
    cd "$TARGET_DIR"
    unzip -o "${BUILD}-img-${BUILD_NUM}.zip"
    rm "${BUILD}-img-${BUILD_NUM}.zip"
}

main "$@"
