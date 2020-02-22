
pipeline {
    agent any

    environment {
        PATH="$PATH:/home/dev/bin:/home/dev/.local/bin"
        SCRIPT_DIR="/home/dev/rb-aosp"
        RB_AOSP_BASE="/home/dev/aosp"
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
                sh "${SCRIPT_DIR}/scripts/shared/analysis/20_diffoscope-files.sh \"${RB_AOSP_BASE}/build/${AOSP_REF}/${GOOGLE_BUILD_TARGET}/${GOOGLE_BUILD_ENV}\" \"${RB_AOSP_BASE}/build/${AOSP_REF}/${RB_BUILD_TARGET}/${RB_BUILD_ENV}\" \"${RB_AOSP_BASE}/diff/${AOSP_REF}_${GOOGLE_BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${AOSP_REF}_${RB_BUILD_TARGET}_${RB_BUILD_ENV}\""
                sh "${SCRIPT_DIR}/scripts/shared/analysis/21_generate-diffstat.sh \"${RB_AOSP_BASE}/diff/${AOSP_REF}_${GOOGLE_BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${AOSP_REF}_${RB_BUILD_TARGET}_${RB_BUILD_ENV}\""
            }
        }
    }
}
