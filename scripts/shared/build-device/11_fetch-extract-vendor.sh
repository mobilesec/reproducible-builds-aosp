#!/bin/bash
set -o errexit -o nounset -o pipefail -o xtrace

# Argument sanity check
if [[ "$#" -ne 2 ]]; then
    echo "Usage: $0 <BUILD_ID> <DEVICE_CODENAME>"
    echo "BUILD_ID: version of AOSP, corresponds to a tag, refer to https://source.android.com/setup/start/build-numbers#source-code-tags-and-builds"
    echo "DEVICE_CODENAME: Internal code name for device, see https://source.android.com/setup/build/running#booting-into-fastboot-mode for details."
    exit 1
fi
BUILD_ID="$1"
DEVICE_CODENAME="$2"
# Reproducible base directory
if [[ -z "${RB_AOSP_BASE+x}" ]]; then
	# Use default location
	RB_AOSP_BASE="${HOME}/aosp"
	mkdir -p "${RB_AOSP_BASE}"
fi

# Create and navigate into temporary driver dir
DRIVER_DIR="${RB_AOSP_BASE}/driver-binaries/${BUILD_ID}/${DEVICE_CODENAME}"
mkdir -p "${DRIVER_DIR}"
cd "${DRIVER_DIR}"

# Extract download links via primitive web scrapping
curl "https://developers.google.com/android/drivers" \
	| grep -i "${DEVICE_CODENAME}-${BUILD_ID}" \
	| sed -n "s/^.*href=\"\s*\(\S*\)\".*$/\1/p" \
	> links
while read LINK; do
	wget "${LINK}"
done <links

# Expand all downloaded files
for FILE_ARCHIVE in *.tgz; do
	tar -zxvf "${FILE_ARCHIVE}"
done

# Expanded files are simple shell scripts that usually need to be run (in order to accept the license).
# Automate this extraction step by identifying offset from internal extraction command and apply it directly
for FILE_EXTRACT in *.sh; do
	OFFSET="$(grep -aP 'tail -n [+0-9]+ \$0 \| tar zxv' "${FILE_EXTRACT}" | sed -n "s/^.*tail -n\s*\(\S*\).*$/\1/p")"
	tail -n "${OFFSET}" "${FILE_EXTRACT}" | tar zxv
done

# Copy complete vendor folder required for build process
SRC_DIR="${RB_AOSP_BASE}/src"
cp -r "${DRIVER_DIR}/vendor" "${SRC_DIR}"
