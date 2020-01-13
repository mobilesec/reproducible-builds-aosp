#!/bin/bash

AOSP_REF="android-10.0.0_r10"
BUILD_ID="QP1A.191105.003"
DEVICE_CODENAME="crosshatch"
GOOGLE_BUILD_TARGET="${DEVICE_CODENAME}-user"
GOOGLE_BUILD_ENV="Google"
RB_AOSP_BASE="/root/aosp"
RB_BUILD_TARGET="aosp_${DEVICE_CODENAME}-user"

compose_cmds() {
cat <<EOF | tr '\n' '; '
source "./scripts/shared/setup-runtime/01_set-runtime-path.sh"
bash "./scripts/shared/build-device/10_clone-src-device.sh" "${AOSP_REF}"
bash "./scripts/shared/build-device/13_fetch-extract-factory-images.sh" "${AOSP_REF}" "${BUILD_ID}" "${DEVICE_CODENAME}"
bash "./scripts/shared/analysis/20_install-simg2img.sh"
EOF
}

docker run \
    --name "${AOSP_REF}_${GOOGLE_BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${AOSP_REF}_${RB_BUILD_TARGET}_${RB_BUILD_ENV}" \
    --mount "type=bind,source=${HOME}/aosp/src/.repo/project-objects,target=/root/aosp/src/.repo/project-objects" \
    --mount "type=bind,source=${HOME}/aosp/src/.repo/project.list,target=/root/aosp/src/.repo/project.list" \
    --mount "type=bind,source=${HOME}/aosp/src/.repo/projects,target=/root/aosp/src/.repo/projects" \
    --mount "type=bind,source=${HOME}/aosp/diff,target=/root/aosp/diff" \
    "mpoell/rb-aosp:kernel-5.3" /bin/bash -c "$(compose_cmds)"
