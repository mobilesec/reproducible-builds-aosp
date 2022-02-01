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
        RB_BUILD_ENV="Ubuntu18.04"
        RB_BUILD_ENV_DOCKER="docker-${RB_BUILD_ENV}"

        DIFF_DIR="${BUILD_NUMBER}_${BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${BUILD_NUMBER}_${BUILD_TARGET}_${RB_BUILD_ENV_DOCKER}"
        DIFF_PATH="${RB_AOSP_BASE}/diff/${DIFF_DIR}"

        CONTAINER_NAME_BUILD="${DIFF_DIR}--build"
        CONTAINER_NAME_ANALYSIS="${DIFF_DIR}--analysis"
    }

    stages {
        stage('Build') {
            agent {
                docker {
                    image 'mobilesec/rb-aosp-build:latest'
                    args """ --device "/dev/fuse" --cap-add "SYS_ADMIN" --security-opt "apparmor:unconfined" \
                        --name "$CONTAINER_NAME_BUILD" \
                        --mount "type=bind,source=${RB_AOSP_BASE}/src,target=${RB_AOSP_BASE}/src" \
                        --mount "type=bind,source=${RB_AOSP_BASE}/build,target=${RB_AOSP_BASE}/build" \
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
                    image 'mobilesec/rb-aosp-analysis:latest'
                    args """ --device "/dev/fuse" --cap-add "SYS_ADMIN" --security-opt "apparmor:unconfined" \
                        --name "$CONTAINER_NAME_ANALYSIS" \
                        --mount "type=bind,source=${RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET},target=${RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET}" \
                        --mount "type=bind,source=${RB_AOSP_BASE}/src,target=${RB_AOSP_BASE}/src" \
                        --mount "type=bind,source=${RB_AOSP_BASE}/diff,target=${RB_AOSP_BASE}/diff" \
                        --mount "type=bind,source=/boot,target=/boot" \
                        --mount "type=bind,source=/lib/modules,target=/lib/modules"
                    """
                }
            }
            steps {
                sh "/scripts/analysis/19_preprocess-imgs.sh \"${BUILD_NUMBER}\" \"${BUILD_TARGET}\" \"${BUILD_TARGET}\" \"${RB_BUILD_ENV}\""
                sh """
                    "/scripts/analysis/20_diffoscope-files.sh" \
                        "${RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET}/${GOOGLE_BUILD_ENV}" \
                        "${RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET}/${RB_BUILD_ENV}" \
                        "${DIFF_PATH}" "generic"
                """
                sh "/scripts/analysis/21_generate-diffstat.sh \"${DIFF_PATH}\" \"generic\""
                sh "/scripts/analysis/22_generate-metrics.sh \"${DIFF_PATH}\" \"generic\""
                sh "/scripts/analysis/23_generate-visualization.sh \"${DIFF_PATH}\""
            }
        }
    }
}
