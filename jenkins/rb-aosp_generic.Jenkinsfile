/*
Copyright 2020 Manuel Pöll

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/
pipeline {
    agent any
    environment {
        RB_AOSP_BASE="/home/dev/aosp"

        GOOGLE_BUILD_ENV="Google"
        RB_BUILD_ENV="Ubuntu18.04"
        RB_BUILD_ENV_DOCKER="docker-${RB_BUILD_ENV}"
        SOAP_ID="${BUILD_NUMBER}_${BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${BUILD_NUMBER}_${BUILD_TARGET}_${RB_BUILD_ENV_DOCKER}"

        CONTAINER_RB_AOSP_BASE="${env.HOME}/aosp"
        CONTAINER_BUILD_IMAGE="mobilesec/rb-aosp-build:latest"
        CONTAINER_BUILD_NAME="${SOAP_ID}--build"
        CONTAINER_ANALYSIS_IMAGE="mobilesec/rb-aosp-analysis:latest"
        CONTAINER_ANALYSIS_NAME="${SOAP_ID}--analysis"
        CONTAINER_DIFF_PATH="${CONTAINER_RB_AOSP_BASE}/diff/${SOAP_ID}"
    }

    stages {
        stage('Setup') {
            steps {
                script {
                    def containerBuildImageHome = sh (
                        script: """docker inspect --format '{{ index (index .Config.Env) 1 }}' "$CONTAINER_BUILD_IMAGE" | cut '--delimiter==' --fields=2""",
                        returnStdout: true
                    ).trim()
                    assert containerBuildImageHome == env.HOME
                    def containerAnalysisImageHome = sh (
                        script: """docker inspect --format '{{ index (index .Config.Env) 1 }}' "$CONTAINER_ANALYSIS_IMAGE" | cut '--delimiter==' --fields=2""",
                        returnStdout: true
                    ).trim()
                    assert containerAnalysisImageHome == env.HOME
                }
                sh "mkdir -p \"${RB_AOSP_BASE}\""
                sh "mkdir -p \"${RB_AOSP_BASE}/src\""
                sh "mkdir -p \"${RB_AOSP_BASE}/build\""
                sh "mkdir -p \"${RB_AOSP_BASE}/diff\""
            }
        }
        stage('Build') {
            agent {
                docker {
                    image "$CONTAINER_BUILD_IMAGE"
                    args """ --device "/dev/fuse" --cap-add "SYS_ADMIN" --security-opt "apparmor:unconfined" \
                        --name "$CONTAINER_BUILD_NAME" \
                        --mount "type=bind,source=${RB_AOSP_BASE}/src,target=${CONTAINER_RB_AOSP_BASE}/src" \
                        --mount "type=bind,source=${RB_AOSP_BASE}/build,target=${CONTAINER_RB_AOSP_BASE}/build" \
                        --mount "type=bind,source=/boot,target=/boot" \
                        --mount "type=bind,source=/lib/modules,target=/lib/modules"
                    """
                }
            }
            steps {
                sh "/scripts/build-generic/10_fetch-ci-artifacts.sh \"${BUILD_NUMBER}\" \"${BUILD_TARGET}\""
                sh "/scripts/build-generic/11_clone-src-via-manifest.sh \"${BUILD_NUMBER}\" \"${BUILD_TARGET}\""
                sh "/scripts/build-generic/12_build-generic.sh \"${BUILD_NUMBER}\" \"${BUILD_TARGET}\""
                sh "/scripts/analysis/18_build-tools.sh"
            }
        }
        stage('Analysis') {
            agent {
                docker {
                    image "$CONTAINER_ANALYSIS_IMAGE"
                    args """ --device "/dev/fuse" --cap-add "SYS_ADMIN" --security-opt "apparmor:unconfined" \
                        --name "$CONTAINER_ANALYSIS_NAME" \
                        --mount "type=bind,source=${RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET},target=${CONTAINER_RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET}" \
                        --mount "type=bind,source=${RB_AOSP_BASE}/src,target=${CONTAINER_RB_AOSP_BASE}/src" \
                        --mount "type=bind,source=${RB_AOSP_BASE}/diff,target=${CONTAINER_RB_AOSP_BASE}/diff" \
                        --mount "type=bind,source=/boot,target=/boot" \
                        --mount "type=bind,source=/lib/modules,target=/lib/modules"
                    """
                }
            }
            steps {
                sh "/scripts/analysis/19_unpack-imgs.sh \"${BUILD_NUMBER}\" \"${BUILD_TARGET}\" \"${BUILD_TARGET}\" \"${RB_BUILD_ENV}\""
                sh """
                    "/scripts/analysis/20_diffoscope-files.sh" \
                        "${CONTAINER_RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET}/${GOOGLE_BUILD_ENV}" \
                        "${CONTAINER_RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET}/${RB_BUILD_ENV}" \
                        "${CONTAINER_DIFF_PATH}" "generic"
                """
                sh "/scripts/analysis/21_generate-diffstat.sh \"${CONTAINER_DIFF_PATH}\" \"generic\""
                sh "/scripts/analysis/22_generate-metrics.sh \"${CONTAINER_DIFF_PATH}\" \"generic\""
                sh "/scripts/analysis/23_generate-visualization.sh \"${CONTAINER_DIFF_PATH}\""
            }
        }
    }
}
