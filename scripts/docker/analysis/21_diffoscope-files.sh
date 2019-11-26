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

function mountSparseImage {
    IMG_SPARSE="$1"
    IMG_RAW="${IMG_SPARSE}.raw"

    # Deomcpress into raw ext2/3/4 partition image
    "${SIMG_2_IMG_BIN}" "${IMG_SPARSE}" "${IMG_RAW}"
    # To avoid accidental changes, mount ro (also simg2img has a bug where Android 10 images can't be mounted rw)
    # This bug is also the reason we can't give ${IMG_RAW} directly to diffoscope (it attempts and fails a rw mount)
    mkdir -p "${IMG_RAW}_mount/"
    mount -o ro "${IMG_RAW}" "${IMG_RAW}_mount/"
}

function unmountSparseImage {
    IMG_SPARSE="$1"
    IMG_RAW="${IMG_SPARSE}.raw"

    umount "${IMG_RAW}_mount/"
    rmdir "${IMG_RAW}_mount/"
    rm "${IMG_RAW}"
}

function diffoscopeFile {
    IN_1="$1"
    IN_2="$2"
    DIFF_OUT="$3"

    # Detect sparse images
    IN_1_SPARSE_IMG=false
    IN_2_SPARSE_IMG=false
    set +e # Disable early exit
    file "${IN_1}" | grep 'Android sparse image'
    if [[ "$?" -eq 0 ]]; then
        IN_1_SPARSE_IMG=true
    fi
    file "${IN_2}" | grep 'Android sparse image'
    if [[ "$?" -eq 0 ]]; then
        IN_2_SPARSE_IMG=true
    fi
    set -e # Re-enable early exit

    # Convert them to raw images that can be readily mounted
    if [[ "${IN_1_SPARSE_IMG}" = true ]]; then
        mountSparseImage "${IN_1}"
        DIFF_IN_1="${IN_1}.raw_mount"
    else
        DIFF_IN_1="${IN_1}"
    fi
    if [[ "${IN_2_SPARSE_IMG}" = true ]]; then
        mountSparseImage "${IN_2}"
        DIFF_IN_2="${IN_2}.raw_mount"
    else
        DIFF_IN_2="${IN_2}"
    fi

    diffoscope --output-empty --progress \
            --exclude-directory-metadata=recursive --exclude 'com.android.runtime.release.apex' \
            --text "${DIFF_OUT}.txt" \
            --html-dir "${DIFF_OUT}.html-dir" \
            "${DIFF_IN_1}" \
            "${DIFF_IN_2}"

    # Unmount sparse images if applicable
    if [[ "${IN_1_SPARSE_IMG}" = true ]]; then
        unmountSparseImage "${IN_1}"
    fi
    if [[ "${IN_2_SPARSE_IMG}" = true ]]; then
        unmountSparseImage "${IN_2}"
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
    if [[ "${FILE}" != "super.img" ]]; then # Ignore super.img, we decompressed it previously 
        diffoscopeFile "${IN_DIR_1}/${FILE}" "${IN_DIR_2}/${FILE}" "${OUT_DIR}/${FILE}.diff" &
    fi
done
