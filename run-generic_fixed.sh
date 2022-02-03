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

composeCommandsBuild() {
    cat <<EOF | tr '\n' '; '
"./scripts/build-generic/10_fetch-ci-artifacts.sh" "$BUILD_NUMBER" "$BUILD_TARGET"
"./scripts/build-generic/11_clone-src-via-manifest.sh" "$BUILD_NUMBER" "$BUILD_TARGET"
"./scripts/build-generic/12_build-generic.sh" "$BUILD_NUMBER" "$BUILD_TARGET"
"./scripts/analysis/18_build-tools.sh"
EOF
}

composeCommandsAnalysis() {
    cat <<EOF | tr '\n' '; '
"./scripts/analysis/19_preprocess-imgs.sh" "$BUILD_NUMBER" "$BUILD_TARGET" "$BUILD_TARGET" "$RB_BUILD_ENV"
"./scripts/analysis/20_diffoscope-files.sh" \
    "${CONTAINER_RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET}/${GOOGLE_BUILD_ENV}" \
    "${CONTAINER_RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET}/${RB_BUILD_ENV}" \
    "$DIFF_PATH" "generic"
"./scripts/analysis/21_generate-diffstat.sh" "$DIFF_PATH" "generic"
"./scripts/analysis/22_generate-metrics.sh" "$DIFF_PATH" "generic"
"./scripts/analysis/23_generate-visualization.sh" "$DIFF_PATH"
EOF
}

main() {
    # Argument sanity check
    if [[ "$#" -ne 2 ]]; then
        echo "Usage: $0 <BUILD_NUMBER> <BUILD_TARGET>"
        echo "BUILD_NUMBER: GoogleCI internal incremental build number that identifies each build, see https://android.googlesource.com/platform/build/+/master/Changes.md#BUILD_NUMBER , e.g. 7963114"
        echo "BUILD_TARGET: Tuple of <BUILD>-<BUILDTYPE>, see https://source.android.com/setup/build/building#choose-a-target for details, e.g. aosp_x86_64-userdebug"
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

    local -r GOOGLE_BUILD_ENV="Google"
    local -r RB_BUILD_ENV="Ubuntu18.04"
    local -r RB_BUILD_ENV_DOCKER="docker-${RB_BUILD_ENV}"

    local -r DIFF_DIR="${BUILD_NUMBER}_${BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${BUILD_NUMBER}_${BUILD_TARGET}_${RB_BUILD_ENV_DOCKER}"
    local -r DIFF_PATH="${RB_AOSP_BASE}/diff/${DIFF_DIR}"

    local -r CONTAINER_RB_AOSP_BASE="${HOME}/aosp"
    local -r CONTAINER_NAME_BUILD="${DIFF_DIR}--build"
    local -r CONTAINER_NAME_ANALYSIS="${DIFF_DIR}--analysis"

    # Perform AOSP build in docker container
    docker run --device "/dev/fuse" --cap-add "SYS_ADMIN" --security-opt "apparmor:unconfined" \
        --name "$CONTAINER_NAME_BUILD" \
        --user=$(id -un) \
        --mount "type=bind,source=${RB_AOSP_BASE}/src,target=${CONTAINER_RB_AOSP_BASE}/src" \
        --mount "type=bind,source=${RB_AOSP_BASE}/build,target=${CONTAINER_RB_AOSP_BASE}/build" \
        --mount "type=bind,source=/boot,target=/boot" \
        --mount "type=bind,source=/lib/modules,target=/lib/modules" \
        "mobilesec/rb-aosp-build:latest" "/bin/bash" -l -c "$(composeCommandsBuild)"
    docker rm "$CONTAINER_NAME_BUILD"

    # Run SOAP analysis via new container based on dedicated image
    docker run --device "/dev/fuse" --cap-add "SYS_ADMIN" --security-opt "apparmor:unconfined" \
        --name "$CONTAINER_NAME_ANALYSIS" \
        --user=$(id -un) \
        --mount "type=bind,source=${RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET},target=${CONTAINER_RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET}" \
        --mount "type=bind,source=${RB_AOSP_BASE}/src,target=${CONTAINER_RB_AOSP_BASE}/src" \
        --mount "type=bind,source=${RB_AOSP_BASE}/diff,target=${CONTAINER_RB_AOSP_BASE}/diff" \
        --mount "type=bind,source=/boot,target=/boot" \
        --mount "type=bind,source=/lib/modules,target=/lib/modules" \
        "mobilesec/rb-aosp-analysis:latest" "/bin/bash" -l -c "$(composeCommandsAnalysis)"
    docker rm "$CONTAINER_NAME_ANALYSIS"

    # Generate report overview on the host
    "./scripts/analysis/24_generate-report-overview.sh" "${RB_AOSP_BASE}/diff"
}

main "$@"
