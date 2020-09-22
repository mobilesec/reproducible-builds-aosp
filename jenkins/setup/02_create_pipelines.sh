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

main() {
    # Jenkins API token generated via http://<jenkins-server>/user/<username>/configure while being logged in as <username>
    local -r JENKINS_USER="YOUR_JENKINS_USER_HERE"
    local -r JENKINS_API_TOKEN="YOUR_API_TOKEN_HERE"

    # Create Jenkins Pipeline jobs based on config files
    local -ar PIPELINE_NAMES=("rb-aosp_device" "rb-aosp_generic")
    for PIPELINE_NAME in "${PIPELINE_NAMES[@]}"; do
        local PIPELINE_FILE="jenkins/config_${PIPELINE_NAME}.xml"
        local BUILD_URL="http://localhost:8080/createItem?name=${PIPELINE_NAME}"
        curl -X POST "${BUILD_URL}" \
            --user "${JENKINS_USER}:${JENKINS_API_TOKEN}" \
            --data-binary "@${PIPELINE_FILE}" -H "Content-Type:text/xml"    
    done
}

main "$@"
