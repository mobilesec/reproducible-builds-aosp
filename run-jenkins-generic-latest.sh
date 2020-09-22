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
. "./scripts/common/jenkins-utils.sh"

main() {
    # Reproducible base directory
    if [[ -z "${RB_AOSP_BASE+x}" ]]; then
        # Use default location
        RB_AOSP_BASE="${HOME}/aosp"
        mkdir -p "${RB_AOSP_BASE}"
    fi

    # Jenkins build params
    local -r BUILD_TARGET="aosp_x86_64-eng"
    local -r BUILD_NUMBER="$(getLatestCIBuildNumber "$BUILD_TARGET")"

    local -r GOOGLE_BUILD_ENV="Google"
    local -r RB_BUILD_ENV="$(lsb_release -si)$(lsb_release -sr)"
    local -r DIFF_DIR="${RB_AOSP_BASE}/diff/${BUILD_NUMBER}_${BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${BUILD_NUMBER}_${BUILD_TARGET}_${RB_BUILD_ENV}"
    if [[ -z "${DIFF_DIR+x}" ]]; then
        # Use default location
        echo "Build already exists, not triggering Jenkins"
        exit 1
    fi

    # Jenkins Setup
    local JENKINS_USER=""
    local JENKINS_API_TOKEN=""
    setJenkinsAuthCredentials "JENKINS_USER" "JENKINS_API_TOKEN"
    local JENKINS_CRUMB_HEADER=""
    local JENKINS_CRUMB=""
    generateAndSetJenkinsCrumb "$JENKINS_USER" "$JENKINS_API_TOKEN" "JENKINS_CRUMB_HEADER" "JENKINS_CRUMB"

    # Trigger Jenkins build
    local -r JENKINS_PIPELINE="rb-aosp_generic"
    local -r BUILD_URL="http://localhost:8080/job/${JENKINS_PIPELINE}/buildWithParameters"
    curl -X POST "${BUILD_URL}" \
        --user "${JENKINS_USER}:${JENKINS_API_TOKEN}" \
        -H "${JENKINS_CRUMB_HEADER}:${JENKINS_CRUMB}" \
        --data-urlencode "BUILD_NUMBER=${BUILD_NUMBER}" \
        --data-urlencode "BUILD_TARGET=${BUILD_TARGET}"
}

main "$@"
