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
. "./scripts/common/jenkins-utils.sh"

main() {
    # Jenkins Build Parameters
    local -r AOSP_REF="android-10.0.0_r30"
    local -r BUILD_ID="QQ2A.200305.002"
    local -r DEVICE_CODENAME="crosshatch"
    local -r GOOGLE_BUILD_TARGET="${DEVICE_CODENAME}-user"
    local -r RB_BUILD_TARGET="aosp_${DEVICE_CODENAME}-user"

    # Jenkins Setup
    local JENKINS_USER=""
    local JENKINS_API_TOKEN=""
    setJenkinsAuthCredentials "JENKINS_USER" "JENKINS_API_TOKEN"
    local JENKINS_CRUMB_HEADER=""
    local JENKINS_CRUMB=""
    generateAndSetJenkinsCrumb "$JENKINS_USER" "$JENKINS_API_TOKEN" "JENKINS_CRUMB_HEADER" "JENKINS_CRUMB"

    # Perform request
    local -r BUILD_URL="http://localhost:8080/job/rb-aosp_device/buildWithParameters"
    curl -X POST "$BUILD_URL" \
        --user "${JENKINS_USER}:${JENKINS_API_TOKEN}" \
        -H "${JENKINS_CRUMB_HEADER}:${JENKINS_CRUMB}" \
        --data-urlencode "AOSP_REF=${AOSP_REF}" \
        --data-urlencode "BUILD_ID=${BUILD_ID}" \
        --data-urlencode "DEVICE_CODENAME=${DEVICE_CODENAME}" \
        --data-urlencode "GOOGLE_BUILD_TARGET=${GOOGLE_BUILD_TARGET}" \
        --data-urlencode "RB_BUILD_TARGET=${RB_BUILD_TARGET}"
}

main "$@"
