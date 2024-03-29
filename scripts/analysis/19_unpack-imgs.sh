#!/bin/bash

# Copyright 2020 Manuel Pöll
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit -o nounset -o pipefail -o xtrace

unpackSuper() {
    local -r BUILD_TARGET="$1"
    local -r BUILD_ENV="$2"
    local -r TARGET_DIR="${RB_AOSP_BASE}/build/${AOSP_REF_OR_BUILD_NUMBER}/${BUILD_TARGET}/${BUILD_ENV}"

    # Only perform unpacking a super image exists
    if [[ -f "${TARGET_DIR}/super.img" ]]; then
        local SUPER_IMG="${TARGET_DIR}/super.img"

        # Detect sparse image, AOSP integrated tool should print something like `system.img: Total of 167424 4096-byte output blocks in 1258 input chunks.`
        if "${AOSP_HOST_BIN}/simg_dump.py" "${SUPER_IMG}" | grep 'Total of'; then
            # Decompress into raw image
            "${AOSP_HOST_BIN}/simg2img" "${TARGET_DIR}/super.img" "${TARGET_DIR}/super.img.raw"
            SUPER_IMG="${TARGET_DIR}/super.img.raw"
        fi

        "${AOSP_HOST_BIN}/lpunpack" "${SUPER_IMG}" "${TARGET_DIR}"   
    fi
}

unpackBoot() {
    local -r BUILD_TARGET="$1"
    local -r BUILD_ENV="$2"
    local -r TARGET_DIR="${RB_AOSP_BASE}/build/${AOSP_REF_OR_BUILD_NUMBER}/${BUILD_TARGET}/${BUILD_ENV}"
    cd "${TARGET_DIR}"

    local -a IMG_FILES
    mapfile -t IMG_FILES < <( find . -name '*.img' -type f | sort )
    declare -r IMG_FILES

    # For all android boot images: Unpack into components and move them to top directory
    for IMG_FILE in "${IMG_FILES[@]}"; do
        if file "$IMG_FILE" | grep 'Android bootimg'; then
            if [[ -f "${SRC_DIR}/system/tools/mkbootimg/unpack_bootimg.py" ]]; then
                # Use custom unpack_bootimg python script from AOSP
                local UNPACK_BOOT_DIR="${IMG_FILE}.unpack-boot"
                mkdir "$UNPACK_BOOT_DIR"
                "${SRC_DIR}/system/tools/mkbootimg/unpack_bootimg.py" --boot_img "$IMG_FILE" --out "$UNPACK_BOOT_DIR" > "${IMG_FILE}.unpack_bootimg.py.output"
                if [[ -f "${UNPACK_BOOT_DIR}/kernel" ]]; then
                    mv "${UNPACK_BOOT_DIR}/kernel" "${IMG_FILE}.kernel.img"
                fi
                if [[ -f "${UNPACK_BOOT_DIR}/ramdisk" ]]; then
                    mv "${UNPACK_BOOT_DIR}/ramdisk" "${IMG_FILE}.ramdisk.img"
                fi
                if [[ -f "${UNPACK_BOOT_DIR}/boot_signature" ]]; then
                    mv "${UNPACK_BOOT_DIR}/boot_signature" "${IMG_FILE}.boot_signature.img"
                fi
                if [[ -f "${UNPACK_BOOT_DIR}/second" ]]; then
                    mv "${UNPACK_BOOT_DIR}/second" "${IMG_FILE}.second.img"
                fi
                rm -rf "./${UNPACK_BOOT_DIR}"
            elif [[ -f "${SRC_DIR}/system/core/mkbootimg/unpack_bootimg" ]]; then
                # Use custom unpack_bootimg binary from AOSP
                local UNPACK_BOOT_DIR="${IMG_FILE}.unpack-boot"
                mkdir "$UNPACK_BOOT_DIR"
                "${SRC_DIR}/system/core/mkbootimg/unpack_bootimg" --boot_img "$IMG_FILE" --out "$UNPACK_BOOT_DIR" > "${IMG_FILE}.unpack_bootimg.output"
                if [[ -f "${UNPACK_BOOT_DIR}/kernel" ]]; then
                    mv "${UNPACK_BOOT_DIR}/kernel" "${IMG_FILE}.kernel.img"
                fi
                if [[ -f "${UNPACK_BOOT_DIR}/ramdisk" ]]; then
                    mv "${UNPACK_BOOT_DIR}/ramdisk" "${IMG_FILE}.ramdisk.img"
                fi
                if [[ -f "${UNPACK_BOOT_DIR}/second" ]]; then
                    mv "${UNPACK_BOOT_DIR}/second" "${IMG_FILE}.second.img"
                fi
                rm -rf "./${UNPACK_BOOT_DIR}"
            else
                # Fallback to abootimg, a small helper tool to handle Android boot images, previously installed via apt
                abootimg -x "$IMG_FILE" "${IMG_FILE}.bootimg.cfg" "${IMG_FILE}.kernel.img" "${IMG_FILE}.ramdisk.img" "${IMG_FILE}.second.img"
            fi
            rm "$IMG_FILE"
        fi
    done
}

main() {
    # Argument sanity check
    if [[ "$#" -ne 4 ]]; then
        echo "Usage: $0 [ <AOSP_REF> | <BUILD_NUMBER> ] <GOOGLE_BUILD_TARGET> <RB_BUILD_TARGET>"
        echo "AOSP_REF or BUILD_NUMBER: Tag/Branch reference or Google internal build number"
        echo "GOOGLE_BUILD_TARGET: Google build target as choosen in lunch (consist of <TARGET_PRODUCT>-<TARGET_BUILD_VARIANT>"
        echo "RB_BUILD_TARGET: Our build target as choosen in lunch (consist of <TARGET_PRODUCT>-<TARGET_BUILD_VARIANT>"
        echo "RB_BUILD_ENV: Our build environment, may be different to the environment used for analysis"
        exit 1
    fi
    local -r AOSP_REF_OR_BUILD_NUMBER="$1"
    local -r GOOGLE_BUILD_TARGET="$2"
    local -r RB_BUILD_TARGET="$3"
    local -r RB_BUILD_ENV="$4"
    # Reproducible base directory
    if [[ -z "${RB_AOSP_BASE+x}" ]]; then
        # Use default location
        local -r RB_AOSP_BASE="${HOME}/aosp"
        mkdir -p "${RB_AOSP_BASE}"
    fi

    # General location of host binaries
    local -r SRC_DIR="${RB_AOSP_BASE}/src"
    local -r AOSP_HOST_BIN="${RB_AOSP_BASE}/src/out/host/linux-x86/bin"
    # Environment names used for build paths
    local -r GOOGLE_BUILD_ENV="Google"
    
    unpackSuper "${GOOGLE_BUILD_TARGET}" "${GOOGLE_BUILD_ENV}"
    unpackSuper "${RB_BUILD_TARGET}" "${RB_BUILD_ENV}"

    unpackBoot "${GOOGLE_BUILD_TARGET}" "${GOOGLE_BUILD_ENV}"
    unpackBoot "${RB_BUILD_TARGET}" "${RB_BUILD_ENV}"
}

main "$@"
