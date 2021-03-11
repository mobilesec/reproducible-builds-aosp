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
        PATH="$PATH:/home/dev/bin:/home/dev/.local/bin"
        SCRIPT_DIR="/home/dev/reproducible-builds-aosp"
        RB_AOSP_BASE="/var/lib/jenkins/aosp"
        GOOGLE_BUILD_ENV="Google"
        RB_BUILD_ENV="\$(lsb_release -si)\$(lsb_release -sr)"
    }

    stages {
        stage('Cloning') {
            steps {
                sh "${SCRIPT_DIR}/scripts/shared/build-device/10_clone-src-device.sh \"${AOSP_REF}\""
                sh "${SCRIPT_DIR}/scripts/shared/build-device/11_fetch-extract-vendor.sh \"${BUILD_ID}\" \"${DEVICE_CODENAME}\""
            }
        }
        stage('Building') {
            steps {
                sh  "${SCRIPT_DIR}/scripts/shared/build-device/12_build-device.sh \"${AOSP_REF}\" \"${RB_BUILD_TARGET}\" \"${DEVICE_CODENAME}\""
            }
        }
        stage('Fetch Reference') {
            steps {
                sh  "${SCRIPT_DIR}/scripts/shared/build-device/13_fetch-extract-factory-images.sh \"${AOSP_REF}\" \"${BUILD_ID}\" \"${DEVICE_CODENAME}\""
            }
        }
        stage('Analysis') {
            steps {
                sh "${SCRIPT_DIR}/scripts/shared/analysis/18_build-lpunpack.sh \"${RB_BUILD_TARGET}\""
                sh "${SCRIPT_DIR}/scripts/shared/analysis/19_lpunpack-super-imgs.sh \"${AOSP_REF}\" \"${GOOGLE_BUILD_TARGET}\" \"${RB_BUILD_TARGET}\""
                sh "${SCRIPT_DIR}/scripts/shared/analysis/20_diffoscope-files.sh \"${RB_AOSP_BASE}/build/${AOSP_REF}/${GOOGLE_BUILD_TARGET}/${GOOGLE_BUILD_ENV}\" \"${RB_AOSP_BASE}/build/${AOSP_REF}/${RB_BUILD_TARGET}/${RB_BUILD_ENV}\" \"${RB_AOSP_BASE}/diff/${AOSP_REF}_${GOOGLE_BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${AOSP_REF}_${RB_BUILD_TARGET}_${RB_BUILD_ENV}\""
                sh "${SCRIPT_DIR}/scripts/shared/analysis/21_generate-csv.sh \"${RB_AOSP_BASE}/diff/${AOSP_REF}_${GOOGLE_BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${AOSP_REF}_${RB_BUILD_TARGET}_${RB_BUILD_ENV}\""
                sh "${SCRIPT_DIR}/scripts/shared/analysis/22_generate-summary.sh \"${RB_AOSP_BASE}/diff/${AOSP_REF}_${GOOGLE_BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${AOSP_REF}_${RB_BUILD_TARGET}_${RB_BUILD_ENV}\""
                sh "${SCRIPT_DIR}/scripts/shared/analysis/23_generate-html.sh \"${RB_AOSP_BASE}/diff/${AOSP_REF}_${GOOGLE_BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${AOSP_REF}_${RB_BUILD_TARGET}_${RB_BUILD_ENV}\""
                sh "${SCRIPT_DIR}/scripts/shared/analysis/24_generate-index-html.sh \"${RB_AOSP_BASE}/diff\""
            }
        }
    }
}
