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
"./scripts/shared/build-device/10_fetch-extract-factory-images.sh" "$AOSP_REF" "$BUILD_ID" "$DEVICE_CODENAME" "$DEVICE_CODENAME"
"./scripts/shared/build-device/11_clone-src-device.sh" "$AOSP_REF"
"./scripts/shared/build-device/12_fetch-extract-vendor.sh" "$BUILD_ID" "$DEVICE_CODENAME"
"./scripts/shared/build-device/13_build-device.sh" "$AOSP_REF" "$RB_BUILD_TARGET" "$GOOGLE_BUILD_TARGET"
"./scripts/shared/analysis/18_build-tools.sh"
EOF
}

composeCommandsAnalysis() {
    cat <<EOF | tr '\n' '; '
"./scripts/shared/analysis/19_preprocess-imgs.sh" "$AOSP_REF" "$GOOGLE_BUILD_TARGET" "$RB_BUILD_TARGET"
"./scripts/shared/analysis/20_diffoscope-files.sh" \
    "${RB_AOSP_BASE_CONTAINER}/build/${AOSP_REF}/${GOOGLE_BUILD_TARGET}/${GOOGLE_BUILD_ENV}" \
    "${RB_AOSP_BASE_CONTAINER}/build/${AOSP_REF}/${RB_BUILD_TARGET}/\$(lsb_release -si)\$(lsb_release -sr)" \
    "$DIFF_PATH"
"./scripts/shared/analysis/21_generate-diffstat.sh" "$DIFF_PATH"
"./scripts/shared/analysis/22_generate-metrics.sh" "$DIFF_PATH" "device"
"./scripts/shared/analysis/23_generate-visualization.sh" "$DIFF_PATH"
EOF
}

main() {
    local -r RB_AOSP_BASE_HOST="${HOME}/aosp"
    local -r RB_AOSP_BASE_CONTAINER="/root/aosp"

    local -r AOSP_REF="android-10.0.0_r30"
    local -r BUILD_ID="QQ2A.200305.002"
    local -r DEVICE_CODENAME="crosshatch"
    local -r GOOGLE_BUILD_TARGET="${DEVICE_CODENAME}-user"
    local -r GOOGLE_BUILD_ENV="Google"
    local -r RB_BUILD_TARGET="aosp_${DEVICE_CODENAME}-user"
    local -r RB_BUILD_ENV="docker-Ubuntu18.04"

    local -r DIFF_DIR="${AOSP_REF}_${GOOGLE_BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${AOSP_REF}_${RB_BUILD_TARGET}_${RB_BUILD_ENV}"
    local -r DIFF_PATH="${RB_AOSP_BASE_CONTAINER}/diff/${DIFF_DIR}"

    local -r CONTAINER_NAME_BUILD="${DIFF_DIR}--build"
    local -r CONTAINER_NAME_ANALYSIS="${DIFF_DIR}--analysis"

    # Perform AOSP build in docker container
    docker run --device "/dev/fuse" --cap-add "SYS_ADMIN" --security-opt "apparmor:unconfined" \
        --name "$CONTAINER_NAME_BUILD" \
        --mount "type=bind,source=${RB_AOSP_BASE_HOST}/src,target=${RB_AOSP_BASE_CONTAINER}/src" \
        --mount "type=bind,source=/boot,target=/boot" \
        --mount "type=bind,source=/lib/modules,target=/lib/modules" \
        "mobilesec/rb-aosp-build:latest" /bin/bash -l -c "$(composeCommandsBuild)"
    # Copy reference and RB build output to host
    mkdir -p "${RB_AOSP_BASE_HOST}/build/${AOSP_REF}"
    docker cp "${CONTAINER_NAME_BUILD}:${RB_AOSP_BASE_CONTAINER}/build/${AOSP_REF}/${GOOGLE_BUILD_TARGET}" "${RB_AOSP_BASE_HOST}/build/${AOSP_REF}/"
    docker cp "${CONTAINER_NAME_BUILD}:${RB_AOSP_BASE_CONTAINER}/build/${AOSP_REF}/${RB_BUILD_TARGET}" "${RB_AOSP_BASE_HOST}/build/${AOSP_REF}/"
    docker rm "$CONTAINER_NAME_BUILD"

    # Run analysis in via new container based on dedicated image
    docker run --device "/dev/fuse" --cap-add "SYS_ADMIN" --security-opt "apparmor:unconfined" \
        --name "$CONTAINER_NAME_ANALYSIS" \
        --mount "type=bind,source=${RB_AOSP_BASE_HOST}/build/${AOSP_REF}/${GOOGLE_BUILD_TARGET},target=${RB_AOSP_BASE_CONTAINER}/build/${AOSP_REF}/${GOOGLE_BUILD_TARGET}" \
        --mount "type=bind,source=${RB_AOSP_BASE_HOST}/build/${AOSP_REF}/${RB_BUILD_TARGET},target=${RB_AOSP_BASE_CONTAINER}/build/${AOSP_REF}/${RB_BUILD_TARGET}" \
        --mount "type=bind,source=${RB_AOSP_BASE_HOST}/src/out/host/linux-x86,target=${RB_AOSP_BASE_CONTAINER}/src/out/host/linux-x86" \
        --mount "type=bind,source=/boot,target=/boot" \
        --mount "type=bind,source=/lib/modules,target=/lib/modules" \
        "mobilesec/rb-aosp-analysis:latest" /bin/bash -l -c "$(composeCommandsAnalysis)"
    mkdir -p "${RB_AOSP_BASE_HOST}/diff"
    docker cp "${CONTAINER_NAME_ANALYSIS}:${RB_AOSP_BASE_CONTAINER}/diff/${DIFF_DIR}" "${RB_AOSP_BASE_HOST}/diff/"
    docker rm "$CONTAINER_NAME_ANALYSIS"

    # Container never sees the full list of report directories, thus the report overview needs to be generated on the host
    "./scripts/shared/analysis/24_generate-report-overview.sh" "${RB_AOSP_BASE_HOST}/diff"
}

main "$@"
