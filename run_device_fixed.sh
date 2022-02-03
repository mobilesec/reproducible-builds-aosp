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
"./scripts/build-device/10_fetch-extract-factory-images.sh" "$AOSP_REF" "$BUILD_ID" "$DEVICE_CODENAME" "$DEVICE_CODENAME"
"./scripts/build-device/11_clone-src-device.sh" "$AOSP_REF"
"./scripts/build-device/12_fetch-extract-vendor.sh" "$BUILD_ID" "$DEVICE_CODENAME"
"./scripts/build-device/13_build-device.sh" "$AOSP_REF" "$RB_BUILD_TARGET" "$GOOGLE_BUILD_TARGET"
"./scripts/analysis/18_build-tools.sh"
EOF
}

composeCommandsAnalysis() {
    cat <<EOF | tr '\n' '; '
"./scripts/analysis/19_preprocess-imgs.sh" "$AOSP_REF" "$GOOGLE_BUILD_TARGET" "$RB_BUILD_TARGET" "$RB_BUILD_ENV"
"./scripts/analysis/20_diffoscope-files.sh" \
    "${CONTAINER_RB_AOSP_BASE}/build/${AOSP_REF}/${GOOGLE_BUILD_TARGET}/${GOOGLE_BUILD_ENV}" \
    "${CONTAINER_RB_AOSP_BASE}/build/${AOSP_REF}/${RB_BUILD_TARGET}/${RB_BUILD_ENV}" \
    "$CONTAINER_DIFF_PATH" "device"
"./scripts/analysis/21_generate-diffstat.sh" "$CONTAINER_DIFF_PATH" "device"
"./scripts/analysis/22_generate-metrics.sh" "$CONTAINER_DIFF_PATH" "device"
"./scripts/analysis/23_generate-visualization.sh" "$CONTAINER_DIFF_PATH"
EOF
}

main() {
    # Argument sanity check
    if [[ "$#" -ne 5 ]]; then
        echo "Usage: $0 <AOSP_REF> <BUILD_ID> <DEVICE_CODENAME> <RB_BUILD_TARGET> <GOOGLE_BUILD_TARGET>"
        echo "AOSP_REF: Branch or Tag in AOSP, refer to https://source.android.com/setup/start/build-numbers#source-code-tags-and-builds , e.g. android-12.0.0_r4"
        echo "BUILD_ID: version of AOSP, corresponds to a tag, refer to https://source.android.com/setup/start/build-numbers#source-code-tags-and-builds , e.g. SD1A.210817.015.A4"
        echo "DEVICE_CODENAME: Internal code name for device, see https://source.android.com/setup/build/running#booting-into-fastboot-mode for details, e.g. raven"
        echo "RB_BUILD_TARGET: Tuple of <BUILD>-<BUILDTYPE>, see https://source.android.com/setup/build/building#choose-a-target for details, e.g. raven-user"
        echo "GOOGLE_BUILD_TARGET: Tuple of <BUILD>-<BUILDTYPE>, see https://source.android.com/setup/build/building#choose-a-target for details, e.g. aosp_raven-user"
        exit 1
    fi
    local -r AOSP_REF="$1"
    local -r BUILD_ID="$2"
    local -r DEVICE_CODENAME="$3"
    local -r GOOGLE_BUILD_TARGET="$4"
    local -r RB_BUILD_TARGET="$5"
    # Reproducible base directory
    if [[ -z "${RB_AOSP_BASE+x}" ]]; then
        # Use default location
        local -r RB_AOSP_BASE="${HOME}/aosp"
        mkdir -p "${RB_AOSP_BASE}"
    fi

    local -r GOOGLE_BUILD_ENV="Google"
    local -r RB_BUILD_ENV="Ubuntu18.04"
    local -r RB_BUILD_ENV_DOCKER="docker-${RB_BUILD_ENV}"

    local -r SOAP_ID="${AOSP_REF}_${GOOGLE_BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${AOSP_REF}_${RB_BUILD_TARGET}_${RB_BUILD_ENV_DOCKER}"

    local -r CONTAINER_RB_AOSP_BASE="${HOME}/aosp"
    local -r CONTAINER_BUILD_IMAGE="mobilesec/rb-aosp-build:latest"
    local -r CONTAINER_BUILD_NAME="${SOAP_ID}--build"
    local -r CONTAINER_ANALYSIS_IMAGE="mobilesec/rb-aosp-analysis:latest"
    local -r CONTAINER_ANALYSIS_NAME="${SOAP_ID}--analysis"
    local -r CONTAINER_DIFF_PATH="${CONTAINER_RB_AOSP_BASE}/diff/${SOAP_ID}"

    # Setup: Guard against usage of different user and ensure subdirectories exist since they are Docker bind mount points
    local -r CONTAINER_BUILD_IMAGE_HOME="$( docker inspect --format "{{ index (index .Config.Env) 1 }}" "$CONTAINER_BUILD_IMAGE" | cut '--delimiter==' --fields=2 )"
    local -r CONTAINER_ANALYSIS_IMAGE_HOME="$( docker inspect --format "{{ index (index .Config.Env) 1 }}" "$CONTAINER_ANALYSIS_IMAGE" | cut '--delimiter==' --fields=2 )"
    if [[ "$CONTAINER_BUILD_IMAGE_HOME" != "$HOME" ]] || [[ "$CONTAINER_ANALYSIS_IMAGE_HOME" != "$HOME" ]]; then
        echo "At least one container was built with a different user, use the same user for docker image builds and runs!"
        exit 2
    fi
    mkdir -p "${RB_AOSP_BASE}/src"
    mkdir -p "${RB_AOSP_BASE}/build"
    mkdir -p "${RB_AOSP_BASE}/diff"

    # Build: Perform AOSP build in docker container
    docker run --device "/dev/fuse" --cap-add "SYS_ADMIN" --security-opt "apparmor:unconfined" \
        --name "$CONTAINER_BUILD_NAME" \
        --user=$(id -un) \
        --mount "type=bind,source=${RB_AOSP_BASE}/src,target=${CONTAINER_RB_AOSP_BASE}/src" \
        --mount "type=bind,source=${RB_AOSP_BASE}/build,target=${CONTAINER_RB_AOSP_BASE}/build" \
        --mount "type=bind,source=/boot,target=/boot" \
        --mount "type=bind,source=/lib/modules,target=/lib/modules" \
        "$CONTAINER_BUILD_IMAGE" "/bin/bash" -l -c "$(composeCommandsBuild)"
    docker rm "$CONTAINER_BUILD_NAME"

    # Analysis: Run SOAP analysis via new container based on dedicated image
    docker run --device "/dev/fuse" --cap-add "SYS_ADMIN" --security-opt "apparmor:unconfined" \
        --name "$CONTAINER_ANALYSIS_NAME" \
        --user=$(id -un) \
        --mount "type=bind,source=${RB_AOSP_BASE}/build/${AOSP_REF}/${GOOGLE_BUILD_TARGET},target=${CONTAINER_RB_AOSP_BASE}/build/${AOSP_REF}/${GOOGLE_BUILD_TARGET}" \
        --mount "type=bind,source=${RB_AOSP_BASE}/build/${AOSP_REF}/${RB_BUILD_TARGET},target=${CONTAINER_RB_AOSP_BASE}/build/${AOSP_REF}/${RB_BUILD_TARGET}" \
        --mount "type=bind,source=${RB_AOSP_BASE}/src,target=${CONTAINER_RB_AOSP_BASE}/src" \
        --mount "type=bind,source=${RB_AOSP_BASE}/diff,target=${CONTAINER_RB_AOSP_BASE}/diff" \
        --mount "type=bind,source=/boot,target=/boot" \
        --mount "type=bind,source=/lib/modules,target=/lib/modules" \
        "$CONTAINER_ANALYSIS_IMAGE" "/bin/bash" -l -c "$(composeCommandsAnalysis)"
    docker rm "$CONTAINER_ANALYSIS_NAME"

    # Generate report overview on the host
    "./scripts/analysis/24_generate-report-overview.sh" "${RB_AOSP_BASE}/diff"
}

main "$@"
