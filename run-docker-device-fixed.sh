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

composeCommands() {
    cat <<EOF | tr '\n' '; '
"./scripts/shared/build-device/10_fetch-extract-factory-images.sh" "$AOSP_REF" "$BUILD_ID" "$DEVICE_CODENAME" "$DEVICE_CODENAME"
"./scripts/shared/build-device/11_clone-src-device.sh" "$AOSP_REF"
"./scripts/shared/build-device/12_fetch-extract-vendor.sh" "$BUILD_ID" "$DEVICE_CODENAME"
"./scripts/shared/build-device/13_build-device.sh" "$AOSP_REF" "$RB_BUILD_TARGET" "$GOOGLE_BUILD_TARGET"
"./scripts/shared/analysis/18_build-lpunpack.sh" "$RB_BUILD_TARGET"
"./scripts/shared/analysis/19_preprocess-imgs.sh" "$AOSP_REF" "$GOOGLE_BUILD_TARGET" "$RB_BUILD_TARGET"
declare -r DIFF_DIR="${RB_AOSP_BASE}/diff/${AOSP_REF}_${GOOGLE_BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${AOSP_REF}_${RB_BUILD_TARGET}_\$(lsb_release -si)\$(lsb_release -sr)"
"./scripts/shared/analysis/20_diffoscope-files.sh" \
    "${RB_AOSP_BASE}/build/${AOSP_REF}/${GOOGLE_BUILD_TARGET}/${GOOGLE_BUILD_ENV}" \
    "${RB_AOSP_BASE}/build/${AOSP_REF}/${RB_BUILD_TARGET}/\$(lsb_release -si)\$(lsb_release -sr)" \
    "\$DIFF_DIR"
"./scripts/shared/analysis/21_generate-diffstat.sh" "\$DIFF_DIR"
"./scripts/shared/analysis/22_generate-metrics.sh" "\$DIFF_DIR" "device"
"./scripts/shared/analysis/23_generate-visualization.sh" "\$DIFF_DIR"
"./scripts/shared/analysis/24_generate-report-overview.sh" "${RB_AOSP_BASE}/diff"
EOF
}

main() {
    local -r AOSP_REF="android-10.0.0_r30"
    local -r BUILD_ID="QQ2A.200305.002"
    local -r DEVICE_CODENAME="crosshatch"
    local -r GOOGLE_BUILD_TARGET="${DEVICE_CODENAME}-user"
    local -r GOOGLE_BUILD_ENV="Google"
    local -r RB_AOSP_BASE="/root/aosp"
    local -r RB_BUILD_TARGET="aosp_${DEVICE_CODENAME}-user"
    local -r RB_BUILD_ENV="docker"

    docker run --rm --device "/dev/fuse" --cap-add "SYS_ADMIN" --security-opt "apparmor:unconfined" \
        --name "${AOSP_REF}_${GOOGLE_BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${AOSP_REF}_${RB_BUILD_TARGET}_${RB_BUILD_ENV}" \
        --mount "type=bind,source=${HOME}/aosp/src/.repo/project-objects,target=/root/aosp/src/.repo/project-objects" \
        --mount "type=bind,source=${HOME}/aosp/src/.repo/project.list,target=/root/aosp/src/.repo/project.list" \
        --mount "type=bind,source=${HOME}/aosp/src/.repo/projects,target=/root/aosp/src/.repo/projects" \
        --mount "type=bind,source=${HOME}/aosp/diff,target=/root/aosp/diff" \
        "mobilesec/rb-aosp:latest" /bin/bash -l -c "$(composeCommands)"
}

main "$@"
