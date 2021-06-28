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
( cd "${RB_AOSP_BASE}/src/.repo/repo" && git checkout "v1.13.9.4" )
"./scripts/shared/build-device/10_fetch-extract-factory-images.sh" "$AOSP_REF" "$BUILD_ID" "$DEVICE_CODENAME" "$DEVICE_CODENAME_FACTORY_IMAGE"
"./scripts/shared/build-device/11_clone-src-device.sh" "$AOSP_REF"
"./scripts/shared/build-device/12_fetch-extract-vendor.sh" "$BUILD_ID" "$DEVICE_CODENAME"
"./scripts/shared/build-device/13_build-device.sh" "$AOSP_REF" "$RB_BUILD_TARGET" "$GOOGLE_BUILD_TARGET"
"./scripts/shared/analysis/18_build-tools.sh"
( cd "${RB_AOSP_BASE}/src/.repo/repo" && git checkout "default" )
EOF
}

composeCommandsAnalysis() {
    cat <<EOF | tr '\n' '; '
"./scripts/shared/analysis/19_preprocess-imgs.sh" "$AOSP_REF" "$GOOGLE_BUILD_TARGET" "$RB_BUILD_TARGET"
"./scripts/shared/analysis/20_diffoscope-files.sh" \
    "${RB_AOSP_BASE}/build/${AOSP_REF}/${GOOGLE_BUILD_TARGET}/${GOOGLE_BUILD_ENV}" \
    "${RB_AOSP_BASE}/build/${AOSP_REF}/${RB_BUILD_TARGET}/${RB_BUILD_ENV}" \
    "$DIFF_PATH"
"./scripts/shared/analysis/21_generate-diffstat.sh" "$DIFF_PATH"
"./scripts/shared/analysis/22_generate-metrics.sh" "$DIFF_PATH" "device"
"./scripts/shared/analysis/23_generate-visualization.sh" "$DIFF_PATH"
EOF
}

main() {
    local -r RB_AOSP_BASE="${HOME}/aosp"

    local -r AOSP_REF="android-5.1.1_r37"
    local -r BUILD_ID="LMY49J"
    local -r DEVICE_CODENAME="manta"
    local -r DEVICE_CODENAME_FACTORY_IMAGE="mantaray"
    local -r GOOGLE_BUILD_TARGET="${DEVICE_CODENAME}-user"
    local -r GOOGLE_BUILD_ENV="Google"
    local -r RB_BUILD_TARGET="aosp_${DEVICE_CODENAME}-user"
    local -r RB_BUILD_ENV="Ubuntu14.04"
    local -r RB_BUILD_ENV_DOCKER="docker-${RB_BUILD_ENV}"

    local -r DIFF_DIR="${AOSP_REF}_${GOOGLE_BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${AOSP_REF}_${RB_BUILD_TARGET}_${RB_BUILD_ENV_DOCKER}"
    local -r DIFF_PATH="${RB_AOSP_BASE}/diff/${DIFF_DIR}"

    local -r CONTAINER_NAME_BUILD="${DIFF_DIR}--build"
    local -r CONTAINER_NAME_ANALYSIS="${DIFF_DIR}--analysis"

    # Perform legacy AOSP build in docker container
    docker run --device "/dev/fuse" --cap-add "SYS_ADMIN" --security-opt "apparmor:unconfined" \
        --name "$CONTAINER_NAME_BUILD" \
        --user=$(id -un) \
        --mount "type=bind,source=${RB_AOSP_BASE}/src,target=${RB_AOSP_BASE}/src" \
        --mount "type=bind,source=/boot,target=/boot" \
        --mount "type=bind,source=/lib/modules,target=/lib/modules" \
        --entrypoint "/bin/bash" "mobilesec/rb-aosp-build-legacy:latest" -l -c "$(composeCommandsBuild)"
    # Copy reference and RB build output to host
    mkdir -p "${RB_AOSP_BASE}/build/${AOSP_REF}"
    docker cp "${CONTAINER_NAME_BUILD}:${RB_AOSP_BASE}/build/${AOSP_REF}/${GOOGLE_BUILD_TARGET}" "${RB_AOSP_BASE}/build/${AOSP_REF}/"
    docker cp "${CONTAINER_NAME_BUILD}:${RB_AOSP_BASE}/build/${AOSP_REF}/${RB_BUILD_TARGET}" "${RB_AOSP_BASE}/build/${AOSP_REF}/"
    docker rm "$CONTAINER_NAME_BUILD"

    # Run SOAP analysis via new container based on dedicated image
    docker run --device "/dev/fuse" --cap-add "SYS_ADMIN" --security-opt "apparmor:unconfined" \
        --name "$CONTAINER_NAME_ANALYSIS" \
        --user=$(id -un) \
        --mount "type=bind,source=${RB_AOSP_BASE}/build/${AOSP_REF}/${GOOGLE_BUILD_TARGET},target=${RB_AOSP_BASE}/build/${AOSP_REF}/${GOOGLE_BUILD_TARGET}" \
        --mount "type=bind,source=${RB_AOSP_BASE}/build/${AOSP_REF}/${RB_BUILD_TARGET},target=${RB_AOSP_BASE}/build/${AOSP_REF}/${RB_BUILD_TARGET}" \
        --mount "type=bind,source=${RB_AOSP_BASE}/src/out/host/linux-x86,target=${RB_AOSP_BASE}/src/out/host/linux-x86" \
        --mount "type=bind,source=/boot,target=/boot" \
        --mount "type=bind,source=/lib/modules,target=/lib/modules" \
        "mobilesec/rb-aosp-analysis:latest" "/bin/bash" -l -c "$(composeCommandsAnalysis)"
    # Copy SOAP analysis from container
    mkdir -p "${RB_AOSP_BASE}/diff"
    docker cp "${CONTAINER_NAME_ANALYSIS}:${DIFF_PATH}" "${RB_AOSP_BASE}/diff/"
    docker rm "$CONTAINER_NAME_ANALYSIS"

    # Container never sees the full list of report directories, thus the report overview needs to be generated on the host
    "./scripts/shared/analysis/24_generate-report-overview.sh" "${RB_AOSP_BASE}/diff"
}

main "$@"
