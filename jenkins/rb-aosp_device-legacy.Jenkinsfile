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
    agent none

    environment {
        RB_AOSP_BASE="/home/dev/aosp"

        GOOGLE_BUILD_ENV="Google"
        RB_BUILD_ENV="Ubuntu14.04"
        RB_BUILD_ENV_DOCKER="docker-${RB_BUILD_ENV}"

        DIFF_DIR="${AOSP_REF}_${GOOGLE_BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${AOSP_REF}_${RB_BUILD_TARGET}_${RB_BUILD_ENV_DOCKER}"
        DIFF_PATH="${RB_AOSP_BASE}/diff/${DIFF_DIR}"

        CONTAINER_NAME_BUILD="${DIFF_DIR}--build"
        CONTAINER_NAME_ANALYSIS="${DIFF_DIR}--analysis"
    }

    stages {
        stage('Setup') {
            agent any
            steps {
                sh "mkdir -p \"${RB_AOSP_BASE}\""
                sh "mkdir -p \"${RB_AOSP_BASE}/src\""
                sh "mkdir -p \"${RB_AOSP_BASE}/build\""
                sh "mkdir -p \"${RB_AOSP_BASE}/diff\""
            }
        }
        stage('Build') {
            agent {
                docker {
                    image 'mobilesec/rb-aosp-build-legacy:latest'
                    args """ --device "/dev/fuse" --cap-add "SYS_ADMIN" --security-opt "apparmor:unconfined" \
                        --name "$CONTAINER_NAME_BUILD" \
                        --mount "type=bind,source=${RB_AOSP_BASE}/src,target=${RB_AOSP_BASE}/src" \
                        --mount "type=bind,source=${RB_AOSP_BASE}/build,target=${RB_AOSP_BASE}/build" \
                        --mount "type=bind,source=/boot,target=/boot" \
                        --mount "type=bind,source=/lib/modules,target=/lib/modules" \
                    """
                }
            }
            steps {
                sh "( cd \"${RB_AOSP_BASE}/src/.repo/repo\" && git checkout \"v1.13.9.4\" )"
                sh "/scripts/build-device/10_fetch-extract-factory-images.sh \"${AOSP_REF}\" \"${BUILD_ID}\" \"${DEVICE_CODENAME}\" \"${DEVICE_CODENAME_FACTORY_IMAGE}\""
                sh "/scripts/build-device/11_clone-src-device.sh \"${AOSP_REF}\""
                sh "/scripts/build-device/12_fetch-extract-vendor.sh \"${BUILD_ID}\" \"${DEVICE_CODENAME}\""
                sh "/scripts/build-device/13_build-device.sh \"${AOSP_REF}\" \"${RB_BUILD_TARGET}\" \"${GOOGLE_BUILD_TARGET}\""
                sh "/scripts/analysis/18_build-tools.sh"
                sh "( cd \"${RB_AOSP_BASE}/src/.repo/repo\" && git checkout \"default\" )"
            }
        }
        stage('Analysis') {
            agent {
                docker {
                    image 'mobilesec/rb-aosp-analysis:latest'
                    args """ --device "/dev/fuse" --cap-add "SYS_ADMIN" --security-opt "apparmor:unconfined" \
                        --name "$CONTAINER_NAME_ANALYSIS" \
                        --mount "type=bind,source=${RB_AOSP_BASE}/build/${AOSP_REF}/${GOOGLE_BUILD_TARGET},target=${RB_AOSP_BASE}/build/${AOSP_REF}/${GOOGLE_BUILD_TARGET}" \
                        --mount "type=bind,source=${RB_AOSP_BASE}/build/${AOSP_REF}/${RB_BUILD_TARGET},target=${RB_AOSP_BASE}/build/${AOSP_REF}/${RB_BUILD_TARGET}" \
                        --mount "type=bind,source=${RB_AOSP_BASE}/src,target=${RB_AOSP_BASE}/src" \
                        --mount "type=bind,source=${RB_AOSP_BASE}/diff,target=${RB_AOSP_BASE}/diff" \
                        --mount "type=bind,source=/boot,target=/boot" \
                        --mount "type=bind,source=/lib/modules,target=/lib/modules"
                    """
                }
            }
            steps {
                sh "/scripts/analysis/19_preprocess-imgs.sh \"${AOSP_REF}\" \"${GOOGLE_BUILD_TARGET}\" \"${RB_BUILD_TARGET}\" \"${RB_BUILD_ENV}\""
                sh """
                    "/scripts/analysis/20_diffoscope-files.sh" \
                        "${RB_AOSP_BASE}/build/${AOSP_REF}/${GOOGLE_BUILD_TARGET}/${GOOGLE_BUILD_ENV}" \
                        "${RB_AOSP_BASE}/build/${AOSP_REF}/${RB_BUILD_TARGET}/${RB_BUILD_ENV}" \
                        "${DIFF_PATH}" "device"
                """
                sh "/scripts/analysis/21_generate-diffstat.sh \"${DIFF_PATH}\" \"device\""
                sh "/scripts/analysis/22_generate-metrics.sh \"${DIFF_PATH}\" \"device\""
                sh "/scripts/analysis/23_generate-visualization.sh \"${DIFF_PATH}\""
            }
        }
    }
}
