#!/bin/bash

# Reproducible base directory
if [ -z "${RB_AOSP_BASE+x}" ]; then
    # Use default location
    RB_AOSP_BASE="${HOME}/aosp"
	mkdir -p "${RB_AOSP_BASE}"
fi

# Create directory for dependency projects
DEPS_DIR="${RB_AOSP_BASE}/deps"
mkdir -p "${DEPS_DIR}"
cd "${DEPS_DIR}"

# Clonse and build android-simg2img, a utility for decompressing a sparse Android image to a raw partition image
git clone "https://github.com/anestisb/android-simg2img" "android-simg2img"
cd "android-simg2img"
make
