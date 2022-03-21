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
        RB_BUILD_ENV="Ubuntu14.04"
        RB_BUILD_ENV_DOCKER="docker-${RB_BUILD_ENV}"
        SOAP_ID="${AOSP_REF}_${GOOGLE_BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${AOSP_REF}_${RB_BUILD_TARGET}_${RB_BUILD_ENV_DOCKER}"

        CONTAINER_RB_AOSP_BASE="${env.HOME}/aosp"
        CONTAINER_BUILD_IMAGE="mobilesec/rb-aosp-build-legacy:latest"
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
                        --mount "type=bind,source=${RB_AOSP_BASE}/driver-binaries,target=${CONTAINER_RB_AOSP_BASE}/driver-binaries" \
                        --mount "type=bind,source=/boot,target=/boot" \
                        --mount "type=bind,source=/lib/modules,target=/lib/modules" \
                    """
                }
            }
            steps {
                sh "( cd \"${CONTAINER_RB_AOSP_BASE}/src/.repo/repo\" && git checkout \"v1.13.9.4\" )"
                sh "/scripts/build-device/10_fetch-extract-factory-images.sh \"${AOSP_REF}\" \"${BUILD_ID}\" \"${DEVICE_CODENAME}\" \"${DEVICE_CODENAME_FACTORY_IMAGE}\""
                sh "/scripts/build-device/11_clone-src-device.sh \"${AOSP_REF}\""
                sh "/scripts/build-device/12_fetch-extract-vendor.sh \"${BUILD_ID}\" \"${DEVICE_CODENAME}\""
                sh "/scripts/build-device/13_build-device.sh \"${AOSP_REF}\" \"${RB_BUILD_TARGET}\" \"${GOOGLE_BUILD_TARGET}\""
                sh "/scripts/analysis/18_build-tools.sh"
                sh "( cd \"${CONTAINER_RB_AOSP_BASE}/src/.repo/repo\" && git checkout \"default\" )"
            }
        }
        stage('Analysis') {
            agent {
                docker {
                    image "$CONTAINER_ANALYSIS_IMAGE"
                    args """ --device "/dev/fuse" --cap-add "SYS_ADMIN" --security-opt "apparmor:unconfined" \
                        --name "$CONTAINER_ANALYSIS_NAME" \
                        --mount "type=bind,source=${RB_AOSP_BASE}/build/${AOSP_REF}/${GOOGLE_BUILD_TARGET},target=${CONTAINER_RB_AOSP_BASE}/build/${AOSP_REF}/${GOOGLE_BUILD_TARGET}" \
                        --mount "type=bind,source=${RB_AOSP_BASE}/build/${AOSP_REF}/${RB_BUILD_TARGET},target=${CONTAINER_RB_AOSP_BASE}/build/${AOSP_REF}/${RB_BUILD_TARGET}" \
                        --mount "type=bind,source=${RB_AOSP_BASE}/src,target=${CONTAINER_RB_AOSP_BASE}/src" \
                        --mount "type=bind,source=${RB_AOSP_BASE}/diff,target=${CONTAINER_RB_AOSP_BASE}/diff" \
                        --mount "type=bind,source=/boot,target=/boot" \
                        --mount "type=bind,source=/lib/modules,target=/lib/modules"
                    """
                }
            }
            steps {
                sh "/scripts/analysis/19_unpack-imgs.sh \"${AOSP_REF}\" \"${GOOGLE_BUILD_TARGET}\" \"${RB_BUILD_TARGET}\" \"${RB_BUILD_ENV}\""
                sh """
                    "/scripts/analysis/20_diffoscope-files.sh" \
                        "${CONTAINER_RB_AOSP_BASE}/build/${AOSP_REF}/${GOOGLE_BUILD_TARGET}/${GOOGLE_BUILD_ENV}" \
                        "${CONTAINER_RB_AOSP_BASE}/build/${AOSP_REF}/${RB_BUILD_TARGET}/${RB_BUILD_ENV}" \
                        "${CONTAINER_DIFF_PATH}" "device"
                """
                sh "/scripts/analysis/21_generate-diffstat.sh \"${CONTAINER_DIFF_PATH}\" \"device\""
                sh "/scripts/analysis/22_generate-metrics.sh \"${CONTAINER_DIFF_PATH}\" \"device\""
                sh "/scripts/analysis/23_generate-visualization.sh \"${CONTAINER_DIFF_PATH}\""
            }
        }
    }
}
