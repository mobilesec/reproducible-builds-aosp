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

downloadExpandVendor() {
    mkdir -p "${DRIVER_DIR}"
    cd "${DRIVER_DIR}"

    # Extract download links via primitive web scrapping
    grep -i "${DEVICE_CODENAME}-${BUILD_ID}" \
        <( curl "https://developers.google.com/android/drivers" ) \
        | sed -n "s/^.*href=\"\s*\(\S*\)\".*$/\1/p" \
        > links
    while read -r LINK; do
        wget "${LINK}"
    done <links

    # Expand all downloaded files
    for FILE_ARCHIVE in *.tgz; do
        tar -zxvf "${FILE_ARCHIVE}"
    done

    # Expanded files are simple shell scripts that usually need to be run (in order to accept the license).
    # Automate this extraction step by identifying offset from internal extraction command and apply it directly
    local OFFSET
    for FILE_EXTRACT in *.sh; do
        OFFSET="$(grep -aP 'tail -n [+0-9]+ \$0 \| tar zxv' "${FILE_EXTRACT}" | sed -n "s/^.*tail -n\s*\(\S*\).*$/\1/p")"
        tail -n "${OFFSET}" "${FILE_EXTRACT}" | tar zxv
    done
}

main() {
    # Argument sanity check
    if [[ "$#" -ne 2 ]]; then
        echo "Usage: $0 <BUILD_ID> <DEVICE_CODENAME>"
        echo "BUILD_ID: version of AOSP, corresponds to a tag, refer to https://source.android.com/setup/start/build-numbers#source-code-tags-and-builds"
        echo "DEVICE_CODENAME: Internal code name for device, see https://source.android.com/setup/build/running#booting-into-fastboot-mode for details."
        exit 1
    fi
    local -r BUILD_ID="$1"
    local -r DEVICE_CODENAME="$2"
    # Reproducible base directory
    if [[ -z "${RB_AOSP_BASE+x}" ]]; then
        # Use default location
        local -r RB_AOSP_BASE="${HOME}/aosp"
        mkdir -p "${RB_AOSP_BASE}"
    fi

    # Create and navigate into temporary driver dir
    local -r DRIVER_DIR="${RB_AOSP_BASE}/driver-binaries/${BUILD_ID}/${DEVICE_CODENAME}"

    # Skip driver directory download if it is cached locally
    if [[ ! -d "${DRIVER_DIR}" ]]; then    
        downloadExpandVendor
    fi

    # Copy complete vendor folder required for build process
    local -r SRC_DIR="${RB_AOSP_BASE}/src"
    cp -r "${DRIVER_DIR}/vendor" "${SRC_DIR}"
}

main "$@"
