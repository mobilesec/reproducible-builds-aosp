#!/bin/bash

AOSP_REF="android-10.0.0_r10"
BUILD_ID="QP1A.191105.003"
DEVICE_CODENAME="crosshatch"
GOOGLE_BUILD_TARGET="${DEVICE_CODENAME}-user"
GOOGLE_BUILD_ENV="Google"
RB_AOSP_BASE="/root/aosp"
RB_BUILD_TARGET="aosp_${DEVICE_CODENAME}-user"
RB_BUILD_ENV="docker"

compose_cmds() {
cat <<EOF | tr '\n' '; '
bash
EOF
}

docker run -it --rm --device "/dev/fuse" --cap-add "SYS_ADMIN" --security-opt "apparmor:unconfined" \
    --name "${AOSP_REF}_${GOOGLE_BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${AOSP_REF}_${RB_BUILD_TARGET}_${RB_BUILD_ENV}" \
    --mount "type=bind,source=${HOME}/aosp/src/.repo/project-objects,target=/root/aosp/src/.repo/project-objects" \
    --mount "type=bind,source=${HOME}/aosp/src/.repo/project.list,target=/root/aosp/src/.repo/project.list" \
    --mount "type=bind,source=${HOME}/aosp/src/.repo/projects,target=/root/aosp/src/.repo/projects" \
    --mount "type=bind,source=${HOME}/aosp/diff,target=/root/aosp/diff" \
    "mpoell/rb-aosp:latest" /bin/bash -l -c "$(compose_cmds)"
