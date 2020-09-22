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

main() {
	# Argument sanity check
	if [[ "$#" -ne 3 ]]; then
		echo "Usage: $0 <AOSP_REF> <DEVICE_CODENAME>"
		echo "AOSP_REF: Branch or Tag in AOSP, refer to https://source.android.com/setup/start/build-numbers#source-code-tags-and-builds"
		echo "BUILD_ID: version of AOSP, corresponds to a tag, refer to https://source.android.com/setup/start/build-numbers#source-code-tags-and-builds"
		echo "DEVICE_CODENAME: Internal code name for device, see https://source.android.com/setup/build/running#booting-into-fastboot-mode for details."
		exit 1
	fi
	local -r AOSP_REF="$1"
	local -r BUILD_ID="$2"
	local -r DEVICE_CODENAME="$3"
	# Reproducible base directory
	if [[ -z "${RB_AOSP_BASE+x}" ]]; then
		# Use default location
		local -r RB_AOSP_BASE="${HOME}/aosp"
		mkdir -p "${RB_AOSP_BASE}"
	fi

	# Create and navigate to image directory
	local -r BUILD_ENV="Google"
	local -r IMAGE_DIR="${RB_AOSP_BASE}/build/${AOSP_REF}/${DEVICE_CODENAME}-user/${BUILD_ENV}"
	mkdir -p "${IMAGE_DIR}"
	cd "${IMAGE_DIR}"
	rm -rf * # Clean up previously fetched files

	# Download link via primitive web scrapping
	grep -i "${DEVICE_CODENAME}-${BUILD_ID}" \
		<( curl "https://developers.google.com/android/images" -H 'cookie: devsite_wall_acks=nexus-image-tos' ) \
		| sed -n "s/^.*href=\"\s*\(\S*\)\".*$/\1/p" > link
	wget "$(cat link)"

	# Extract outer zip file (contains flash sh/bat file, firmware blobs and actual partition *.img files in another zip)
	unzip *.zip
	# Extract inner zip with *.img files (extracted into current dir, i.e. IMAGE_DIR)
	unzip */*.zip
}

main "$@"
