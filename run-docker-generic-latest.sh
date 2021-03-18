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

# Source utils
. "./scripts/common/utils.sh"

compose_cmds() {
    cat <<EOF | tr '\n' '; '
        bash "./scripts/shared/build-generic/10_fetch-ci-artifacts.sh" "${BUILD_NUMBER}" "${BUILD_TARGET}"
        bash "./scripts/shared/build-generic/11_clone-src-via-manifest.sh" "${BUILD_NUMBER}" "${BUILD_TARGET}"
        bash "./scripts/shared/build-generic/12_build-generic.sh" "${BUILD_NUMBER}" "${BUILD_TARGET}"
        bash "./scripts/shared/analysis/18_build-lpunpack.sh" "${BUILD_TARGET}"
        bash "./scripts/shared/analysis/19_preprocess-imgs.sh" "${BUILD_NUMBER}" "${BUILD_TARGET}" "${BUILD_TARGET}"
        bash "./scripts/shared/analysis/20_diffoscope-files.sh" \
            "${RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET}/${GOOGLE_BUILD_ENV}" \
            "${RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET}/\$(lsb_release -si)\$(lsb_release -sr)" \
            "${RB_AOSP_BASE}/diff/${BUILD_NUMBER}_${BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${BUILD_NUMBER}_${BUILD_TARGET}_\$(lsb_release -si)\$(lsb_release -sr)"
        bash "./scripts/shared/analysis/21_generate-diffstat.sh" "${RB_AOSP_BASE}/diff/${BUILD_NUMBER}_${BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${BUILD_NUMBER}_${BUILD_TARGET}_\$(lsb_release -si)\$(lsb_release -sr)"
        bash "./scripts/shared/analysis/21_generate-metrics.sh" "${RB_AOSP_BASE}/diff/${BUILD_NUMBER}_${BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${BUILD_NUMBER}_${BUILD_TARGET}_\$(lsb_release -si)\$(lsb_release -sr)"
        bash "./scripts/shared/analysis/23_generate-html.sh" "${RB_AOSP_BASE}/diff/${BUILD_NUMBER}_${BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${BUILD_NUMBER}_${BUILD_TARGET}_\$(lsb_release -si)\$(lsb_release -sr)"
        bash "./scripts/shared/analysis/24_generate-index-html.sh" "${RB_AOSP_BASE}/diff"
EOF
}

main() {
    local -r BUILD_TARGET="aosp_x86_64-eng"
    local -r BUILD_NUMBER="$(getLatestCIBuildNumber "$BUILD_TARGET")"
    local -r GOOGLE_BUILD_ENV="Google"
    local -r RB_AOSP_BASE="/root/aosp"
    local -r RB_BUILD_ENV="docker"

    docker run --rm --device "/dev/fuse" --cap-add "SYS_ADMIN" --security-opt "apparmor:unconfined" \
        --name "${BUILD_NUMBER}_${BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${BUILD_NUMBER}_${BUILD_TARGET}_${RB_BUILD_ENV}" \
        --mount "type=bind,source=${HOME}/aosp/src/.repo/project-objects,target=/root/aosp/src/.repo/project-objects" \
        --mount "type=bind,source=${HOME}/aosp/src/.repo/project.list,target=/root/aosp/src/.repo/project.list" \
        --mount "type=bind,source=${HOME}/aosp/src/.repo/projects,target=/root/aosp/src/.repo/projects" \
        --mount "type=bind,source=${HOME}/aosp/diff,target=/root/aosp/diff" \
        "mobilesec/rb-aosp:latest" /bin/bash -l -c "$(compose_cmds)"
}

main "$@"
