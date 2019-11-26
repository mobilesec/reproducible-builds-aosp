#!/bin/bash
set -ex

# Argument sanity check
if [[ "$#" -ne 3 ]]; then
    echo "Usage: $0 <IN_DIR_1> <IN_DIR_2> <OUT_DIR>"
	echo "IN_DIR_1, IN_DIR_2: Directory with files that should be compared (Only files in both dirs will be compared)"
	echo "OUT_DIR: Output directory diffoscope output"
    exit 1
fi
IN_DIR_1="$1"
IN_DIR_2="$2"
OUT_DIR="$3"
# Reproducible base directory
if [[ -z "${RB_AOSP_BASE+x}" ]]; then
    # Use default location
    RB_AOSP_BASE="${HOME}/aosp"
	mkdir -p "${RB_AOSP_BASE}"
fi

function decompressSparseImage {
    IMG_SPARSE="$1"
    IMG_RAW="$2"

    # Deomcpress into raw ext2/3/4 partition image
    "${SIMG_2_IMG_BIN}" "${IMG_SPARSE}" "${IMG_RAW}"
}

function mountExtImage {
    IMG_EXT="$1"
    IMG_MOUNT="$2"

    # To avoid accidental changes + unsupported feature flag, mount ro
    mkdir -p "${IMG_MOUNT}"
    mount -o ro "${IMG_EXT}" "${IMG_MOUNT}"
}

function unmountExtImage {
    IMG_EXT="$1"
    IMG_MOUNT="$2"

    umount "${IMG_MOUNT}"
    rmdir "${IMG_MOUNT}"
}

function diffoscopeFile {
    # Original input paramts
    IN_1="$1"
    IN_2="$2"
    DIFF_OUT="$3"
    # Mutable diffoscope params
    DIFF_IN_1="${IN_1}"
    DIFF_IN_2="${IN_2}"
    
    # Detect sparse images
    set +e # Disable early exit
    file "${DIFF_IN_1}" | grep 'Android sparse image'
    if [[ "$?" -eq 0 ]]; then
        IN_1_SPARSE_IMG=true
    fi
    file "${DIFF_IN_2}" | grep 'Android sparse image'
    if [[ "$?" -eq 0 ]]; then
        IN_2_SPARSE_IMG=true
    fi
    set -e # Re-enable early exit

    # Convert them to raw images that can be readily mounted
    if [[ "${IN_1_SPARSE_IMG}" = true ]]; then
        decompressSparseImage "${DIFF_IN_1}" "${DIFF_IN_1}.raw"
        DIFF_IN_1="${DIFF_IN_1}.raw"
    fi
    if [[ "${IN_2_SPARSE_IMG}" = true ]]; then
        decompressSparseImage "${DIFF_IN_2}" "${DIFF_IN_2}.raw"
        DIFF_IN_2="${DIFF_IN_2}.raw"
    fi

    # Detect ext2/3/4 images. Usually these can be handled by diffoscope just fine, however...
    # Starting with Android 10 all ext4 images use some special dedup/compression feature which results in
    # `EXT4-fs (loop3): couldn't mount RDWR because of unsupported optional features (4000)`
    # when attempting a standard rw mount. Thus mount these images ro before calling diffoscope with the mount point
    set +e # Disable early exit
    file "${DIFF_IN_1}" | grep -P '(ext2)|(ext3)|(ext4)'
    if [[ "$?" -eq 0 ]]; then
        IN_1_EXT_IMG=true
    fi
    file "${DIFF_IN_2}" | grep -P '(ext2)|(ext3)|(ext4)'
    if [[ "$?" -eq 0 ]]; then
        IN_2_EXT_IMG=true
    fi
    set -e # Re-enable early exit

    # Convert them to raw images that can be readily mounted
    if [[ "${IN_1_EXT_IMG}" = true ]]; then
        mountExtImage "${DIFF_IN_1}" "${DIFF_IN_1}_mount"
        DIFF_IN_1="${DIFF_IN_1}_mount"
    fi
    if [[ "${IN_2_EXT_IMG}" = true ]]; then
        mountExtImage "${DIFF_IN_2}" "${DIFF_IN_2}_mount"
        DIFF_IN_2="${DIFF_IN_2}_mount"
    fi

    set +e # Disable early exit
    diffoscope --output-empty --progress \
            --exclude-directory-metadata=recursive --exclude 'com.android.runtime.release.apex' \
            --text "${DIFF_OUT}.txt" \
            --html-dir "${DIFF_OUT}.html-dir" \
            "${DIFF_IN_1}" "${DIFF_IN_2}"
    set -e # Re-enable early exit

    # Unmount ext images if applicable
    if [[ "${IN_1_EXT_IMG}" = true ]]; then
        if [[ "${IN_1_SPARSE_IMG}" = true ]]; then
            unmountExtImage "${IN_1}.raw" "${DIFF_IN_1}"
        else
            unmountExtImage "${IN_1}" "${DIFF_IN_1}"
        fi
    fi
    if [[ "${IN_2_EXT_IMG}" = true ]]; then
        if [[ "${IN_2_SPARSE_IMG}" = true ]]; then
            unmountExtImage "${IN_2}.raw" "${DIFF_IN_2}"
        else
            unmountExtImage "${IN_2}" "${DIFF_IN_2}"
        fi
    fi

    # Delete sparse images if applicable
    if [[ "${IN_1_SPARSE_IMG}" = true ]]; then
        rm "${IN_1}.raw"
    fi
    if [[ "${IN_2_SPARSE_IMG}" = true ]]; then
        rm "${IN_2}.raw"
    fi
}

# Misc variables + ensure ${OUT_DIR} exists
DEPS_DIR="${RB_AOSP_BASE}/deps"
SIMG_2_IMG_BIN="${DEPS_DIR}/android-simg2img/simg2img"
mkdir -p "${OUT_DIR}"

# Create list of files in common for both directories
FILES=($(comm -12 \
    <(cd "${IN_DIR_1}" && find -type f | sort) \
    <(cd "${IN_DIR_2}" && find -type f | sort) \
))

for FILE in "${FILES[@]}"; do
    if [[ "${FILE}" != *"super.img" ]]; then # Ignore super.img, we decompressed it previously 
        diffoscopeFile "${IN_DIR_1}/${FILE}" "${IN_DIR_2}/${FILE}" "${OUT_DIR}/${FILE}.diff" &
    fi
done
