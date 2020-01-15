#!/bin/bash

BUILD_NUMBER="6032886"
DEVICE_CODENAME="crosshatch"
BUILD_TARGET="aosp_${DEVICE_CODENAME}-user"
GOOGLE_BUILD_ENV="Google"
RB_AOSP_BASE="/root/aosp"

compose_cmds() {
cat <<EOF | tr '\n' '; '
source "./scripts/shared/setup-runtime/01_set-runtime-path.sh"
bash "./scripts/shared/build-generic/10_fetch-ci-artifacts.sh" "${BUILD_NUMBER}" "${BUILD_TARGET}"
bash "./scripts/shared/build-generic/11_clone-src-via-manifest.sh" "${BUILD_NUMBER}" "${BUILD_TARGET}"
bash "./scripts/shared/build-generic/12_build-generic.sh" "${BUILD_NUMBER}" "${BUILD_TARGET}"
bash "./scripts/shared/build-generic/13_build-lpunpack.sh" "${BUILD_TARGET}"
bash "./scripts/shared/build-generic/14_lpunpack-super-imgs.sh" "${BUILD_NUMBER}" "${BUILD_TARGET}"
bash "./scripts/shared/analysis/20_install-simg2img.sh"
bash "./scripts/shared/analysis/21_diffoscope-files.sh" \
    "${RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET}/${GOOGLE_BUILD_ENV}" \
    "${RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET}/\$(lsb_release -si)\$(lsb_release -sr)" \
    "${RB_AOSP_BASE}/diff/${BUILD_NUMBER}_${BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${BUILD_NUMBER}_${BUILD_TARGET}_\$(lsb_release -si)\$(lsb_release -sr)"
EOF
}

docker run \
    --name "${AOSP_REF}_${GOOGLE_BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${AOSP_REF}_${RB_BUILD_TARGET}_${RB_BUILD_ENV}" \
    --mount "type=bind,source=${HOME}/aosp/src/.repo/project-objects,target=/root/aosp/src/.repo/project-objects" \
    --mount "type=bind,source=${HOME}/aosp/src/.repo/project.list,target=/root/aosp/src/.repo/project.list" \
    --mount "type=bind,source=${HOME}/aosp/src/.repo/projects,target=/root/aosp/src/.repo/projects" \
    --mount "type=bind,source=${HOME}/aosp/diff,target=/root/aosp/diff" \
    "mpoell/rb-aosp:latest" /bin/bash -c "$(compose_cmds)"
