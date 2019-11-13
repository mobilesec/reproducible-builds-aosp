#!/bin/bash

# Argument sanity check
if [ "$#" -ne 3 ]; then
	echo "Usage: $0 <AOSP_REF> <DEVICE_CODENAME>"
	echo "AOSP_REF: Branch or Tag in AOSP, refer to https://source.android.com/setup/start/build-numbers#source-code-tags-and-builds"
	echo "BUILD_ID: version of AOSP, corresponds to a tag, refer to https://source.android.com/setup/start/build-numbers#source-code-tags-and-builds"
	echo "DEVICE_CODENAME: Internal code name for device, see https://source.android.com/setup/build/running#booting-into-fastboot-mode for details."
	exit 1
fi
AOSP_REF="$1"
BUILD_ID="$2"
DEVICE_CODENAME="$3"
# Reproducible base directory
if [ -z "${RB_AOSP_BASE+x}" ]; then
	# Use default location
	RB_AOSP_BASE="${HOME}/aosp"
	mkdir -p "${RB_AOSP_BASE}"
fi

# Create and navigate to image directory
BUILD_ENV="Google"
IMAGE_DIR="${RB_AOSP_BASE}/build/${AOSP_REF}/${DEVICE_CODENAME}-user/${BUILD_ENV}"
mkdir -p "${IMAGE_DIR}"
cd "${IMAGE_DIR}"

# Download link via primitive web scrapping
curl "https://developers.google.com/android/images" \
	| grep -i "${DEVICE_CODENAME}-${BUILD_ID}" \
	| sed -n "s/^.*href=\"\s*\(\S*\)\".*$/\1/p" > link
wget "$(cat link)"

# Extract outer zip file (contains flash sh/bat file, firmware blobs and actual partition *.img files in another zip)
unzip *.zip
# Extract inner zip with *.img files (extracted into current dir, i.e. IMAGE_DIR)
unzip */*.zip

