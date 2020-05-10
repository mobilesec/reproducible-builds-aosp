#!/bin/bash
set -o errexit -o nounset -o pipefail -o xtrace

function decompressSparseImage {
    local -r IMG_SPARSE="$1"
    local -r IMG_RAW="$2"

    # Deomcpress into raw ext2/3/4 partition image
    simg2img "${IMG_SPARSE}" "${IMG_RAW}"
}

function diffoscopeFile {
    # Original input paramts
    local -r IN_1="$1"
    local -r IN_2="$2"
    local -r DIFF_OUT="$3"
    # Mutable diffoscope params
    local DIFF_IN_1="${IN_1}"
    local DIFF_IN_2="${IN_2}"
    
    # Detect sparse images
    local IN_1_SPARSE_IMG=false
    local IN_2_SPARSE_IMG=false
    set +o errexit # Disable early exit
    file "${DIFF_IN_1}" | grep 'Android sparse image'
    if [[ "$?" -eq 0 ]]; then
        IN_1_SPARSE_IMG=true
    fi
    file "${DIFF_IN_2}" | grep 'Android sparse image'
    if [[ "$?" -eq 0 ]]; then
        IN_2_SPARSE_IMG=true
    fi
    set -o errexit # Re-enable early exit

    # Convert them to raw images that can be readily mounted
    if [[ "${IN_1_SPARSE_IMG}" = true ]]; then
        decompressSparseImage "${DIFF_IN_1}" "${DIFF_IN_1}.raw"
        DIFF_IN_1="${DIFF_IN_1}.raw"
    fi
    if [[ "${IN_2_SPARSE_IMG}" = true ]]; then
        decompressSparseImage "${DIFF_IN_2}" "${DIFF_IN_2}.raw"
        DIFF_IN_2="${DIFF_IN_2}.raw"
    fi

    # Detect ext4 images with EXT4_FEATURE_RO_COMPAT_SHARED_BLOCKS (`shared_blocks` or `FEATURE_R14` if not explicitly named).
    # Current kernels (as or writing 5.4 upstream) don't support this yet, thus mount.ext4 with defaults (including rw) fails
    # Thus we set the 'read-only' feature on these, allowing mount.ext4 with defaults (now ro) to suceed.
    local IN_1_EXT_IMG_SHARED_BLOCKS=false
    local IN_2_EXT_IMG_SHARED_BLOCKS=false
    set +o errexit # Disable early exit
    # Check if ext4 image (file tends to show ext2)
    file "${DIFF_IN_1}" | grep -P '(ext2)|(ext3)|(ext4)'
    if [[ "$?" -eq 0 ]]; then
        # Check for 'shared_blocks'
        "${TUNE2FS_BIN}" -l "${DIFF_IN_1}" | grep -P 'Filesystem features:[ a-zA-Z_-]+(shared_blocks)|(FEATURE_R14)'
        if [[ "$?" -eq 0 ]]; then
            IN_1_EXT_IMG_SHARED_BLOCKS=true
        fi
    fi
    file "${DIFF_IN_2}" | grep -P '(ext2)|(ext3)|(ext4)'
    if [[ "$?" -eq 0 ]]; then
        # Check for 'shared_blocks'
        "${TUNE2FS_BIN}" -l "${DIFF_IN_2}" | grep -P 'Filesystem features:[ a-zA-Z_-]+(shared_blocks)|(FEATURE_R14)'
        if [[ "$?" -eq 0 ]]; then
            IN_2_EXT_IMG_SHARED_BLOCKS=true
        fi
    fi
    set -o errexit # Re-enable early exit

    # As stated, set the ext4 'read-only' flag, see https://www.mankier.com/8/tune2fs#-O
    if [[ "${IN_1_EXT_IMG_SHARED_BLOCKS}" = true ]]; then
        "${TUNE2FS_BIN}" -O "read-only" "${DIFF_IN_1}"
    fi
    if [[ "${IN_2_EXT_IMG_SHARED_BLOCKS}" = true ]]; then
        "${TUNE2FS_BIN}" -O "read-only" "${DIFF_IN_2}"
    fi

    set +o errexit # Disable early exit
    sudo "$(command -v diffoscope)" --output-empty --progress \
            --exclude-directory-metadata=recursive --exclude 'apex_payload.img' --exclude 'CERT.RSA' --exclude 'apex_pubkey' --exclude 'update-payload-key.pub.pem' \
            --json "${DIFF_OUT}.json" \
            --html-dir "${DIFF_OUT}.html-dir" \
            "${DIFF_IN_1}" "${DIFF_IN_2}"
    set -o errexit # Re-enable early exit

    # Clear `read-only` flag
    if [[ "${IN_1_EXT_IMG_SHARED_BLOCKS}" = true ]]; then
        "${TUNE2FS_BIN}" -O "^read-only" "${DIFF_IN_1}"
    fi
    if [[ "${IN_2_EXT_IMG_SHARED_BLOCKS}" = true ]]; then
        "${TUNE2FS_BIN}" -O "^read-only" "${DIFF_IN_2}"
    fi

    # Delete raw image (if original was sparse)
    if [[ "${IN_1_SPARSE_IMG}" = true ]]; then
        rm "${IN_1}.raw"
    fi
    if [[ "${IN_2_SPARSE_IMG}" = true ]]; then
        rm "${IN_2}.raw"
    fi
}

main() {
    # Argument sanity check
    if [[ "$#" -ne 3 ]]; then
        echo "Usage: $0 <IN_DIR_1> <IN_DIR_2> <OUT_DIR>"
        echo "IN_DIR_1, IN_DIR_2: Directory with files that should be compared (Only files in both dirs will be compared)"
        echo "OUT_DIR: Output directory diffoscope output"
        exit 1
    fi
    local -r IN_DIR_1="$1"
    local -r IN_DIR_2="$2"
    local -r OUT_DIR="$3"
    # Reproducible base directory
    if [[ -z "${RB_AOSP_BASE+x}" ]]; then
        # Use default location
        RB_AOSP_BASE="${HOME}/aosp"
        mkdir -p "${RB_AOSP_BASE}"
    fi

    # Misc variables + ensure ${OUT_DIR} exists
    local -r DEPS_DIR="${RB_AOSP_BASE}/deps"
    local -r TUNE2FS_BIN="${RB_AOSP_BASE}/src/out/host/linux-x86/bin/tune2fs"
    mkdir -p "${OUT_DIR}"
    rm -rf "${OUT_DIR}/"* # Clean up previous diff results

    # apktool quirk workaround, see https://github.com/iBotPeaches/Apktool/issues/2048
    sudo mkdir -p  "/root/.local/share/apktool/framework"

    # Create list of files in common for both directories
    local -ar FILES=($(comm -12 \
        <(cd "${IN_DIR_1}" && find -type f | sort) \
        <(cd "${IN_DIR_2}" && find -type f | sort) \
    ))

    for FILE in "${FILES[@]}"; do
        if [[ "${FILE}" != *"super.img" && "${FILE}" != *".link" ]]; then # Ignore super.img, we decompressed it previously
            diffoscopeFile "${IN_DIR_1}/${FILE}" "${IN_DIR_2}/${FILE}" "${OUT_DIR}/${FILE}.diff"
        fi
    done

    # Cleanup both builds after diffing process
    rm -rf "${IN_DIR_1}"
    rm -rf "${IN_DIR_1}"
}

main "$@"
