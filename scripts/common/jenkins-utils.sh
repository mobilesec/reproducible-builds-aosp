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

setJenkinsAuthCredentials() {
    if [[ "$#" -ne 2 ]]; then
        echo "Invalid call of setJenkinsAuthCredentials util function, usage:"
        echo "JENKINS_USER_META: Name of the Jenkins user variable"
        echo "JENKINS_API_TOKEN_META: Name of the Jenkins API token variable"
        exit 1
    fi
    local -r JENKINS_USER_META="$1"
    local -r JENKINS_API_TOKEN_META="$2"

    # Jenkins API token generated via <jenkins-server-origin>/user/<username>/configure while being logged in as <username>
    eval "$JENKINS_USER_META=YOUR_JENKINS_USER_HERE"
    eval "$JENKINS_API_TOKEN_META=YOUR_API_TOKEN_HERE"
}

generateAndSetJenkinsCrumb() {
    if [[ "$#" -ne 4 ]]; then
        echo "Invalid call of generateAndSetJenkinsCrumb util function, usage:"
        echo "JENKINS_USER: Jenkins user"
        echo "JENKINS_API_TOKEN: Jenkins API token"
        echo "JENKINS_CRUMB_HEADER_META: Name of the Jenkins Crumb Header Name"
        echo "JENKINS_CRUMB_META: Name of the Jenkins Crumb Header Value"
        exit 1
    fi
    local -r JENKINS_USER="$1"
    local -r JENKINS_API_TOKEN="$2"
    local -r JENKINS_CRUMB_HEADER_META="$3"
    local -r JENKINS_CRUMB_META="$4"

    # Generate Jenkins Crumb, a CSRF token (see https://wiki.jenkins.io/display/JENKINS/Remote+access+API#RemoteaccessAPI-CSRFProtection for details)
    local -r JENKINS_SERVER_ORIGIN="http://localhost:8080"
    local -r GEN_CRUMB_RES=$(curl --user "${JENKINS_USER}:${JENKINS_API_TOKEN}" "${JENKINS_SERVER_ORIGIN}/crumbIssuer/api/json")
    eval "$JENKINS_CRUMB_HEADER_META"="$(echo "${GEN_CRUMB_RES}" | jq -r '.crumbRequestField' )"
    eval "$JENKINS_CRUMB_META"="$(echo "${GEN_CRUMB_RES}" | jq -r '.crumb' )"
}
