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
( cd "${HOME}/aosp/src/.repo/repo" && git checkout "v1.13.9.4" )
"./scripts/shared/build-device/10_fetch-extract-factory-images.sh" "$AOSP_REF" "$BUILD_ID" "$DEVICE_CODENAME" "$DEVICE_CODENAME_FACTORY_IMAGE"
"./scripts/shared/build-device/11_clone-src-device.sh" "$AOSP_REF"
"./scripts/shared/build-device/12_fetch-extract-vendor.sh" "$BUILD_ID" "$DEVICE_CODENAME"
"./scripts/shared/build-device/13_build-device.sh" "$AOSP_REF" "$RB_BUILD_TARGET" "$GOOGLE_BUILD_TARGET"
bash
( cd "${HOME}/aosp/src/.repo/repo" && git checkout "default" )
EOF
}

main() {
    local -r AOSP_REF="android-5.1.1_r37"
    local -r BUILD_ID="LMY49J"
    local -r DEVICE_CODENAME="manta"
    local -r DEVICE_CODENAME_FACTORY_IMAGE="mantaray"
    local -r GOOGLE_BUILD_TARGET="${DEVICE_CODENAME}-user"
    local -r GOOGLE_BUILD_ENV="Google"
    #local -r RB_AOSP_BASE="${HOME}/aosp"
    local -r RB_BUILD_TARGET="aosp_${DEVICE_CODENAME}-user"
    local -r RB_BUILD_ENV="docker"
    local -r CONTAINER_NAME="${AOSP_REF}_${GOOGLE_BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${AOSP_REF}_${RB_BUILD_TARGET}_${RB_BUILD_ENV}"

    docker run --device "/dev/fuse" --cap-add "SYS_ADMIN" --security-opt "apparmor:unconfined" \
        --name "$CONTAINER_NAME" \
        --mount "type=bind,source=${HOME}/aosp/src,target=${HOME}/aosp/src" \
        --mount "type=bind,source=/boot,target=/boot" \
        --mount "type=bind,source=/lib/modules,target=/lib/modules" \
        --entrypoint /bin/bash \
        "mobilesec/rb-aosp-legacy:latest" -l -c "$(composeCommands)"

    # docker rm "$CONTAINER_NAME"
}

main "$@"
