#!/bin/bash
set -o errexit -o nounset -o pipefail -o xtrace

compose_cmds() {
    cat <<EOF | tr '\n' '; '
        bash "./scripts/shared/build-device/10_clone-src-device.sh" "${AOSP_REF}"
        bash "./scripts/shared/build-device/11_fetch-extract-vendor.sh" "${BUILD_ID}" "${DEVICE_CODENAME}"
        bash "./scripts/shared/build-device/12_build-device.sh" "${AOSP_REF}" "${RB_BUILD_TARGET}" "${DEVICE_CODENAME}"
        bash "./scripts/shared/build-device/13_fetch-extract-factory-images.sh" "${AOSP_REF}" "${BUILD_ID}" "${DEVICE_CODENAME}"
        bash "./scripts/shared/analysis/18_build-lpunpack.sh" "${RB_BUILD_TARGET}"
        bash "./scripts/shared/analysis/19_lpunpack-super-imgs.sh" "${AOSP_REF}" "${GOOGLE_BUILD_TARGET}" "${RB_BUILD_TARGET}"
        bash "./scripts/shared/analysis/20_diffoscope-files.sh" \
            "${RB_AOSP_BASE}/build/${AOSP_REF}/${GOOGLE_BUILD_TARGET}/${GOOGLE_BUILD_ENV}" \
            "${RB_AOSP_BASE}/build/${AOSP_REF}/${RB_BUILD_TARGET}/\$(lsb_release -si)\$(lsb_release -sr)" \
            "${RB_AOSP_BASE}/diff/${AOSP_REF}_${GOOGLE_BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${AOSP_REF}_${RB_BUILD_TARGET}_\$(lsb_release -si)\$(lsb_release -sr)"
        bash "./scripts/shared/analysis/21_generate-csv.sh" "${RB_AOSP_BASE}/diff/${AOSP_REF}_${GOOGLE_BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${AOSP_REF}_${RB_BUILD_TARGET}_\$(lsb_release -si)\$(lsb_release -sr)"
        bash "./scripts/shared/analysis/22_generate-summary-device.sh" "${RB_AOSP_BASE}/diff/${AOSP_REF}_${GOOGLE_BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${AOSP_REF}_${RB_BUILD_TARGET}_\$(lsb_release -si)\$(lsb_release -sr)"
EOF
}

main() {
    local -r AOSP_REF="android-10.0.0_r30"
    local -r BUILD_ID="QQ2A.200305.002"
    local -r DEVICE_CODENAME="crosshatch"
    local -r GOOGLE_BUILD_TARGET="${DEVICE_CODENAME}-user"
    local -r GOOGLE_BUILD_ENV="Google"
    local -r RB_AOSP_BASE="/root/aosp"
    local -r RB_BUILD_TARGET="aosp_${DEVICE_CODENAME}-user"
    local -r RB_BUILD_ENV="docker"

    docker run --rm --device "/dev/fuse" --cap-add "SYS_ADMIN" --security-opt "apparmor:unconfined" \
        --name "${AOSP_REF}_${GOOGLE_BUILD_TARGET}_${GOOGLE_BUILD_ENV}__${AOSP_REF}_${RB_BUILD_TARGET}_${RB_BUILD_ENV}" \
        --mount "type=bind,source=${HOME}/aosp/src/.repo/project-objects,target=/root/aosp/src/.repo/project-objects" \
        --mount "type=bind,source=${HOME}/aosp/src/.repo/project.list,target=/root/aosp/src/.repo/project.list" \
        --mount "type=bind,source=${HOME}/aosp/src/.repo/projects,target=/root/aosp/src/.repo/projects" \
        --mount "type=bind,source=${HOME}/aosp/diff,target=/root/aosp/diff" \
        "mpoell/rb-aosp:latest" /bin/bash -l -c "$(compose_cmds)"
}

main "$@"
