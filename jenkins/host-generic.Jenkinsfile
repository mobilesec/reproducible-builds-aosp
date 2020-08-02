
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
        stage('Fetch Reference') {
            steps {
                sh "${SCRIPT_DIR}/scripts/shared/build-generic/10_fetch-ci-artifacts.sh \"${BUILD_NUMBER}\" \"${BUILD_TARGET}\""
            }
        }
        stage('Cloning') {
            steps {
                sh "${SCRIPT_DIR}/scripts/shared/build-generic/11_clone-src-via-manifest.sh \"${BUILD_NUMBER}\" \"${BUILD_TARGET}\""
            }
        }
        stage('Building') {
            steps {
                sh "${SCRIPT_DIR}/scripts/shared/build-generic/12_build-generic.sh \"${BUILD_NUMBER}\" \"${BUILD_TARGET}\""
            }
        }
        stage('Analysis') {
            steps {
                sh "${SCRIPT_DIR}/scripts/shared/analysis/18_build-lpunpack.sh \"${BUILD_TARGET}\""
                sh "${SCRIPT_DIR}/scripts/shared/analysis/19_lpunpack-super-imgs.sh \"${BUILD_NUMBER}\" \"${BUILD_TARGET}\" \"${BUILD_TARGET}\""
                sh "${SCRIPT_DIR}/scripts/shared/analysis/20_diffoscope-files.sh \"${RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET}/${GOOGLE_BUILD_ENV}\" \"${RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET}/${RB_BUILD_ENV}\" \"${RB_AOSP_BASE}/diff/${BUILD_NUMBER}_${BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${BUILD_NUMBER}_${BUILD_TARGET}_${RB_BUILD_ENV}\""
                sh "${SCRIPT_DIR}/scripts/shared/analysis/21_generate-csv.sh \"${RB_AOSP_BASE}/diff/${BUILD_NUMBER}_${BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${BUILD_NUMBER}_${BUILD_TARGET}_${RB_BUILD_ENV}\""
                sh "${SCRIPT_DIR}/scripts/shared/analysis/22_generate-summary-generic.sh \"${RB_AOSP_BASE}/diff/${BUILD_NUMBER}_${BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${BUILD_NUMBER}_${BUILD_TARGET}_${RB_BUILD_ENV}\""
            }
        }
    }
}
