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
    local -r SYSTEM_IMG_META="$1"

    local SYSTEM_IMG_RESOLVED
    SYSTEM_IMG_RESOLVED=$(eval echo \$"$SYSTEM_IMG_META")

    # Detect sparse images
    if file "${SYSTEM_IMG_RESOLVED}" | grep 'Android sparse image'; then
        # Deomcpress into raw ext2/3/4 partition image
        simg2img "${SYSTEM_IMG_RESOLVED}" "${SYSTEM_IMG_RESOLVED}.raw"
        eval "$SYSTEM_IMG_META=${SYSTEM_IMG_RESOLVED}.raw"
    fi
    SYSTEM_IMG_RESOLVED=$(eval echo \$"$SYSTEM_IMG_META")

    mkdir -p "${SYSTEM_IMG_RESOLVED}.mount"
    guestmount -o "uid=$(id -u)" -o "gid=$(id -g)" -a "${SYSTEM_IMG_RESOLVED}" -m "$(virt-filesystems -a "${SYSTEM_IMG_RESOLVED}")" --ro "${SYSTEM_IMG_RESOLVED}.mount"
    eval "$SYSTEM_IMG_META=${SYSTEM_IMG_RESOLVED}.mount"
    SYSTEM_IMG_RESOLVED=$(eval echo \$"$SYSTEM_IMG_META")

    # Extract build properties and set them as environment variables
    local BUILD_DATETIME_TMP
    BUILD_DATETIME_TMP="$(grep 'ro.build.date.utc' "${SYSTEM_IMG_RESOLVED}/system/build.prop" \
        | sed -n -r 's/^ro\.build\.date\.utc=([0-9]+)$/\1/p' \
    )"
    export BUILD_DATETIME="$BUILD_DATETIME_TMP"

    local BUILD_NUMBER_TMP
    BUILD_NUMBER_TMP="$(grep 'ro.build.version.incremental' "${SYSTEM_IMG_RESOLVED}/system/build.prop" \
        | sed -n -r 's/^ro\.build\.version\.incremental=(\S+)$/\1/p' \
    )"
    export BUILD_NUMBER="$BUILD_NUMBER_TMP"

    local BUILD_USERNAME_TMP
    BUILD_USERNAME_TMP="$(grep 'ro.build.user' "${SYSTEM_IMG_RESOLVED}/system/build.prop" \
        | sed -n -r 's/^ro\.build\.user=(\S+)$/\1/p' \
    )"
    export BUILD_USERNAME="$BUILD_USERNAME_TMP"

    local BUILD_HOSTNAME_TMP
    BUILD_HOSTNAME_TMP="$(grep 'ro.build.host' "${SYSTEM_IMG_RESOLVED}/system/build.prop" \
        | sed -n -r 's/^ro\.build\.host=(\S+)$/\1/p' \
    )"
    export BUILD_HOSTNAME="$BUILD_HOSTNAME_TMP"

    # Sanity check that we are dealing with a mount
    if mount | grep "${SYSTEM_IMG_RESOLVED}"; then
        IMAGE="$(dirname "$SYSTEM_IMG_RESOLVED")/$(basename -s '.mount' "$SYSTEM_IMG_RESOLVED")"

        guestunmount "${IMAGE}.mount"
        rmdir "${IMAGE}.mount"

        if [[ "$IMAGE" = *".img.raw" ]]; then
            # Delete raw image that was uncompressed from the sparse one
            rm "$IMAGE"
        fi
    fi
}
