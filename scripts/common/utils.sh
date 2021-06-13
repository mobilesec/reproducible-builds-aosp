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

getLatestCIBuildNumber() {
    local -r BUILD_TARGET="$1"

    local -r BUILD_NUMBER="$(curl "https://ci.android.com/builds/branches/aosp-master/status.json" \
        | jq -r ".targets[] | select(.name | contains(\"${BUILD_TARGET}\")) | .last_known_good_build" \
    )"

    echo "$BUILD_NUMBER"
}

setAdditionalBuildEnvironmentVars() {
    local SYSTEM_IMG="$1"

    # General location of host binaries
    local -r AOSP_HOST_BIN="${RB_AOSP_BASE}/src/out/host/linux-x86/bin"

    # Detect sparse images, AOSP integrated tool should print something like `system.img: Total of 167424 4096-byte output blocks in 1258 input chunks.`
    if "${AOSP_HOST_BIN}/simg_dump.py" "${SYSTEM_IMG}" | grep 'Total of'; then
        # Deomcpress into raw ext2/3/4 partition image
        "${AOSP_HOST_BIN}/simg2img" "${SYSTEM_IMG}" "${SYSTEM_IMG}.raw"
        SYSTEM_IMG="${SYSTEM_IMG}.raw"
    fi

    local DEVICE_IN_IMAGE
    DEVICE_IN_IMAGE="$(virt-filesystems -a "${SYSTEM_IMG}")"
    if [[ "$DEVICE_IN_IMAGE" == "" ]]; then
        DEVICE_IN_IMAGE="/dev/sda"
    fi

    mkdir -p "${SYSTEM_IMG}.mount"
    guestmount -o "uid=$(id -u)" -o "gid=$(id -g)" -a "${SYSTEM_IMG}" -m "$DEVICE_IN_IMAGE" --ro "${SYSTEM_IMG}.mount"
    SYSTEM_IMG="${SYSTEM_IMG}.mount"

    # Extract build properties and set them as environment variables
    local BUILD_PROP_FILE
    if [[ -f "${SYSTEM_IMG}/system/build.prop" ]]; then
        BUILD_PROP_FILE="${SYSTEM_IMG}/system/build.prop"
    elif [[ -f "${SYSTEM_IMG}/build.prop" ]]; then
        BUILD_PROP_FILE="${SYSTEM_IMG}/build.prop"
    else
        echo "Can't find build property file, checked all known locations!"
        exit 1
    fi
    local BUILD_DATETIME_TMP
    BUILD_DATETIME_TMP="$(grep 'ro.build.date.utc' "$BUILD_PROP_FILE" \
        | sed -n -r 's/^ro\.build\.date\.utc=([0-9]+)$/\1/p' \
    )"
    export BUILD_DATETIME="$BUILD_DATETIME_TMP"

    local BUILD_NUMBER_TMP
    BUILD_NUMBER_TMP="$(grep 'ro.build.version.incremental' "$BUILD_PROP_FILE" \
        | sed -n -r 's/^ro\.build\.version\.incremental=(\S+)$/\1/p' \
    )"
    export BUILD_NUMBER="$BUILD_NUMBER_TMP"

    local BUILD_USERNAME_TMP
    BUILD_USERNAME_TMP="$(grep 'ro.build.user' "$BUILD_PROP_FILE" \
        | sed -n -r 's/^ro\.build\.user=(\S+)$/\1/p' \
    )"
    export BUILD_USERNAME="$BUILD_USERNAME_TMP"

    local BUILD_HOSTNAME_TMP
    BUILD_HOSTNAME_TMP="$(grep 'ro.build.host' "$BUILD_PROP_FILE" \
        | sed -n -r 's/^ro\.build\.host=(\S+)$/\1/p' \
    )"
    export BUILD_HOSTNAME="$BUILD_HOSTNAME_TMP"

    # Sanity check that we are dealing with a mount
    if mount | grep "${SYSTEM_IMG}"; then
        IMAGE="$(dirname "$SYSTEM_IMG")/$(basename -s '.mount' "$SYSTEM_IMG")"

        guestunmount "${IMAGE}.mount"
        rmdir "${IMAGE}.mount"

        if [[ "$IMAGE" == *".img.raw" ]]; then
            # Delete raw image that was uncompressed from the sparse one
            rm "$IMAGE"
        fi
    fi
}
