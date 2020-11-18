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
		echo "Usage: $0 <AOSP_REF> <BUILD_TARGET> <DEVICE_CODENAME>"
		echo "AOSP_REF: Branch or Tag in AOSP, refer to https://source.android.com/setup/start/build-numbers#source-code-tags-and-builds"
		echo "BUILD_TARGET: Tuple of <BUILD>-<BUILDTYPE>, see https://source.android.com/setup/build/building#choose-a-target for details."
		echo "DEVICE_CODENAME: Simply the codename for the target device, see https://source.android.com/setup/build/running#booting-into-fastboot-mode"
		exit 1
	fi
	local -r AOSP_REF="$1"
	local -r BUILD_TARGET="$2"
	local -r DEVICE_CODENAME="$3"
	# Reproducible base directory
	if [[ -z "${RB_AOSP_BASE+x}" ]]; then
		# Use default location
		local -r RB_AOSP_BASE="${HOME}/aosp"
		mkdir -p "${RB_AOSP_BASE}"
	fi

	# Navigate to src dir and init build
	local -r SRC_DIR="${RB_AOSP_BASE}/src"
	# Communicate custom build dir to soong build system.
	#export OUT_DIR_COMMON_BASE="${BUILD_DIR}" # Deactivated on purpose (Shared build dir leeds to build artifact caching)
	cd "${SRC_DIR}"
	# Unfortunately envsetup doesn't work with nounset flag, specifically fails with:
	# ./build/envsetup.sh: line 361: ZSH_VERSION: unbound variable
	set +o nounset
	source ./build/envsetup.sh
	lunch "${BUILD_TARGET}"
	m -j $(nproc)
	set -o nounset

	# Release build
	make dist

	# Prepare TARGET_DIR as destination for relevant build output. Used for further analysis
	local -r BUILD_DIR="${SRC_DIR}/out"
	local -r BUILD_ENV="$(lsb_release -si)$(lsb_release -sr)"
	local -r TARGET_DIR="${RB_AOSP_BASE}/build/${AOSP_REF}/${BUILD_TARGET}/${BUILD_ENV}"
	mkdir -p "${TARGET_DIR}"
	# Copy relevant build output from BUILD_DIR to TARGET_DIR
	cp "${BUILD_DIR}/target/product/${DEVICE_CODENAME}"/*.img "${TARGET_DIR}"
	cp "${BUILD_DIR}/target/product/${DEVICE_CODENAME}/android-info.txt" "${TARGET_DIR}"
}

main "$@"
