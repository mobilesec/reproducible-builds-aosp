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

compose_cmds() {
    cat <<EOF | tr '\n' '; '
        bash
EOF
}

main() {
    local -r AOSP_REF="android-10.0.0_r10"
    local -r BUILD_ID="QP1A.191105.003"
    local -r DEVICE_CODENAME="crosshatch"
    local -r GOOGLE_BUILD_TARGET="${DEVICE_CODENAME}-user"
    local -r GOOGLE_BUILD_ENV="Google"
    local -r RB_AOSP_BASE="/root/aosp"
    local -r RB_BUILD_TARGET="aosp_${DEVICE_CODENAME}-user"
    local -r RB_BUILD_ENV="docker"

    docker run -it --rm --device "/dev/fuse" --cap-add "SYS_ADMIN" --security-opt "apparmor:unconfined" \
        --name "${AOSP_REF}_${GOOGLE_BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${AOSP_REF}_${RB_BUILD_TARGET}_${RB_BUILD_ENV}" \
        --mount "type=bind,source=${HOME}/aosp/src/.repo/project-objects,target=/root/aosp/src/.repo/project-objects" \
        --mount "type=bind,source=${HOME}/aosp/src/.repo/project.list,target=/root/aosp/src/.repo/project.list" \
        --mount "type=bind,source=${HOME}/aosp/src/.repo/projects,target=/root/aosp/src/.repo/projects" \
        --mount "type=bind,source=${HOME}/aosp/diff,target=/root/aosp/diff" \
        "mpoell/rb-aosp:latest" /bin/bash -l -c "$(compose_cmds)"
}

main "$@"
