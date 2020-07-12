#!/bin/bash
set -o errexit -o nounset -o pipefail -o xtrace

function preProcessImage {
    # Mutable diffoscope params
    local DIFF_IN_META="$1"

    local DIFF_IN_RESOLVED=$(eval echo \$"$DIFF_IN_META")
    # Sanity check that we are dealing with a image
    set +o errexit # Disable early exit
    file "${DIFF_IN_RESOLVED}" | grep -P '(ext2)|(ext3)|(ext4)|(Android sparse image)'
    if [[ "$?" -eq 0 ]]; then
        set -o errexit # Re-enable early exit

        # Detect sparse images
        set +o errexit # Disable early exit
        file "${DIFF_IN_RESOLVED}" | grep 'Android sparse image'
        if [[ "$?" -eq 0 ]]; then
            set -o errexit # Re-enable early exit
            # Deomcpress into raw ext2/3/4 partition image
            "${AOSP_HOST_BIN}/simg2img" "${DIFF_IN_RESOLVED}" "${DIFF_IN_RESOLVED}.raw"
            eval $DIFF_IN_META="${DIFF_IN_RESOLVED}.raw"
        fi
        set -o errexit # Re-enable early exit

        # Detect ext4 images with EXT4_FEATURE_RO_COMPAT_SHARED_BLOCKS (`shared_blocks` or `FEATURE_R14` if not explicitly named).
        # Current kernels (as or writing 5.4 upstream) don't support this yet, thus mount.ext4 with defaults (including rw) fails
        # Thus we double the image size (simple heuristic that should work in 99% of cases) and remove the block sharing feature
        #set +o errexit # Disable early exit
        # Check for 'shared_blocks'
        #"${TUNE2FS_BIN}/tune2fs" -l "${DIFF_IN_RESOLVED}" | grep -P 'Filesystem features:[ a-zA-Z_-]+(shared_blocks)|(FEATURE_R14)'
        #if [[ "$?" -eq 0 ]]; then
            #set -o errexit # Re-enable early exit
            # Determine new expanded block number
            #local EXPANDED_BLOCK_COUNT=$(( $("${TUNE2FS_BIN}/tune2fs" -l "${DIFF_IN_RESOLVED}" | grep 'Block count' | cut -d: -f2) * 2 ))
            #"${TUNE2FS_BIN}/resize2fs" "${DIFF_IN_RESOLVED}" "$EXPANDED_BLOCK_COUNT"
            #"${TUNE2FS_BIN}/e2fsck" -E unshare_blocks "${DIFF_IN_RESOLVED}"
        #fi
        #set -o errexit # Re-enable early exit

        local DIFF_IN_RESOLVED=$(eval echo \$"$DIFF_IN_META")
        # Mount image to ensure stable file iteration order
        mkdir "${DIFF_IN_RESOLVED}.mount"
        sudo mount -o ro "${DIFF_IN_RESOLVED}" "${DIFF_IN_RESOLVED}.mount"
        eval $DIFF_IN_META="${DIFF_IN_RESOLVED}.mount"

        # Extract apex_payload.img from APEX archives for separate diffoscope run
        if [[ "$(sudo find "${DIFF_IN_RESOLVED}.mount" -type f -iname '*.apex' | wc -l)" -ne 0 ]]; then
            mkdir "${DIFF_IN_RESOLVED}.apexes"
            sudo find "${DIFF_IN_RESOLVED}.mount" -type f -iname '*.apex' -exec cp {} "${DIFF_IN_RESOLVED}.apexes/" \;
            find "${DIFF_IN_RESOLVED}.apexes" -type f -iname '*.apex' \
                -exec unzip "{}" -d "{}.unzip" \; \
                -exec mv "{}.unzip/apex_payload.img" "{}-apex_payload.img" \; \
                -exec rm -rf "{}.unzip" "{}" \;

            # Have another look at the list if files in common, but only consider APEX related ones
            local -r APEX_FOLDER_BASENAME="$(basename "${DIFF_IN_RESOLVED}.apexes")"
            local -ar APEX_PAYLOAD_FILES=($(comm -12 \
                <(cd "${IN_DIR_1}" && find -type f | sort) \
                <(cd "${IN_DIR_2}" && find -type f | sort) \
            | grep "${APEX_FOLDER_BASENAME}"))
            # Append to list of files requiring processing via diffoscope
            FILES+=( "${APEX_PAYLOAD_FILES[@]}" )
        fi
    fi
    set -o errexit # Re-enable early exit

}

function postProcessImage {
    # Normalize path (e.g. /my/path/./to/somewhere -> /my/path/to/somewhere)
    local DIFF_IN="$(realpath $1)"

    # Sanity check that we are dealing with a mount
    set +o errexit # Disable early exit
    mount | grep "${DIFF_IN}"
    if [[ "$?" -eq 0 ]]; then
        set -o errexit # Re-enable early exit

        sudo umount "$DIFF_IN"
    fi
    set -o errexit # Re-enable early exit
}

function diffoscopeFile {
    # Original input paramts
    local -r IN_1="$1"
    local -r IN_2="$2"
    local -r DIFF_OUT="$3"
    # Start values for diff input params
    local DIFF_IN_1="${IN_1}"
    local DIFF_IN_2="${IN_2}"

    preProcessImage "DIFF_IN_1"
    preProcessImage "DIFF_IN_2"

    set +o errexit # Disable early exit
    sudo "$(command -v diffoscope)" --output-empty --progress \
            --exclude-directory-metadata=recursive --exclude 'apex_payload.img' --exclude 'CERT.RSA' --exclude 'apex_pubkey' --exclude 'update-payload-key.pub.pem' \
            --json "${DIFF_OUT}.json" \
            --html-dir "${DIFF_OUT}.html-dir" \
            "${DIFF_IN_1}" "${DIFF_IN_2}"
    set -o errexit # Re-enable early exit

    postProcessImage "${DIFF_IN_1}"
    postProcessImage "${DIFF_IN_2}"
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
    local -r AOSP_HOST_BIN="${RB_AOSP_BASE}/src/out/host/linux-x86/bin"
    mkdir -p "${OUT_DIR}"
    rm -rf "${OUT_DIR}/"* # Clean up previous diff results

    # apktool quirk workaround, see https://github.com/iBotPeaches/Apktool/issues/2048
    sudo mkdir -p  "/root/.local/share/apktool/framework"

    # Create list of files in common for both directories. Ignore super.img, we unpacked it previously
    local -a FILES=($(comm -12 \
        <(cd "${IN_DIR_1}" && find -type f | sort) \
        <(cd "${IN_DIR_2}" && find -type f | sort) \
    | grep -v 'super.img'))

    for ((i = 0; i < "${#FILES[@]}"; i++)); do
        diffoscopeFile "${IN_DIR_1}/${FILE}" "${IN_DIR_2}/${FILE}" "${OUT_DIR}/${FILE}.diff"
    done

    # Cleanup both builds after diffing process
    rm -rf "${IN_DIR_1}"
    rm -rf "${IN_DIR_2}"
}

main "$@"
