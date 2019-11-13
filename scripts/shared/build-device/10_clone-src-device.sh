#!/bin/bash

# Argument sanity check
if [ "$#" -ne 1 ]; then
	echo "Usage: $0 <AOSP_REF>"
	echo "AOSP_REF: Branch or Tag in AOSP, refer to https://source.android.com/setup/start/build-numbers#source-code-tags-and-builds"
	exit 1
fi
AOSP_REF="$1"
# Reproducible base directory
if [ -z "${RB_AOSP_BASE+x}" ]; then
	# Use default location
	RB_AOSP_BASE="${HOME}/aosp"
	mkdir -p "${RB_AOSP_BASE}"
fi

# Follow steps from https://source.android.com/setup/build/downloading#initializing-a-repo-client
SRC_DIR="${RB_AOSP_BASE}/src"
mkdir -p "${SRC_DIR}"
cd "${SRC_DIR}"

# Init repo for a named AOSP Ref, i.e. a branch or Tag
repo init -u "https://android.googlesource.com/platform/manifest" -b "${AOSP_REF}"
repo sync -j $(nproc)
