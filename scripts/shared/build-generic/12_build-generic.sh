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
	if [[ "$#" -ne 2 ]]; then
		echo "Usage: $0 <BUILD_NUMBER> <BUILD_TARGET>"
		echo "BUILD_NUMBER: GoogleCI internal incremental build number that identifies each build, see https://android.googlesource.com/platform/build/+/master/Changes.md#BUILD_NUMBER"
		echo "BUILD_TARGET: Tuple of <BUILD>-<BUILDTYPE>, see https://source.android.com/setup/build/building#choose-a-target for details."
		exit 1
	fi
	local -r BUILD_NUMBER="$1"
	local -r BUILD_TARGET="$2"
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

	# Create Dist bundle
	make dist

	# Prepare TARGET_DIR as destination for relevant build output. Used for further analysis
	local -r BUILD_DIR="${SRC_DIR}/out"
	local -r BUILD_ENV="$(lsb_release -si)$(lsb_release -sr)"
	local -r TARGET_DIR="${RB_AOSP_BASE}/build/${BUILD_NUMBER}/${BUILD_TARGET}/${BUILD_ENV}"
	mkdir -p "${TARGET_DIR}"
	# Generic build targets have specific names for their folders in ${BUILD_DIR}/target/product
	# Extract this name from the PRODUCT_DEVICE variable from their Makefile
	local -r BUILD=$(echo ${BUILD_TARGET} | sed -E -e 's/-[a-z]+$//') # Remove -BUILDTYPE suffix
	local -r MAKEFILE="${SRC_DIR}/build/make/target/product/${BUILD}.mk"
	local -r PRODUCT_DIR=$(grep 'PRODUCT_DEVICE' "${MAKEFILE}" | sed -E -e 's/^[^=]+=[ ]*//') # Remove variable assignment
	# Copy relevant build output from BUILD_DIR to TARGET_DIR
	cp "${BUILD_DIR}/dist"/*-img-*.zip "${TARGET_DIR}"
	cd "$TARGET_DIR"
	unzip *-img-*.zip
	rm *-img-*.zip
}

main "$@"
