#!/bin/bash
set -o errexit -o nounset -o pipefail -o xtrace

function preProcessImage {
    # Mutable diffoscope params
    local DIFF_IN_META="$1"

    local DIFF_IN_BASE=$(eval echo \$"$DIFF_IN_META")
    local DIFF_IN_RESOLVED=$DIFF_IN_BASE
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

        local DIFF_IN_RESOLVED=$(eval echo \$"$DIFF_IN_META")
        # Mount image to ensure stable file iteration order
        mkdir -p "${DIFF_IN_RESOLVED}.mount"
        # guestfs allows working with complex file systems images (e.g. LVM volume groups with multiple LVs) and thus requires
        # us to be explicit about what part of image we want to mount. Running `virt-filesystems -a system.img.raw` returns the
        # name of the "virtual" device and can be directly fed to guestmount (usually this is /dev/sda)
        guestmount -o "uid=$(id -u)" -o "gid=$(id -g)" -a "${DIFF_IN_RESOLVED}" -m "$(virt-filesystems -a "${DIFF_IN_RESOLVED}")" --ro "${DIFF_IN_RESOLVED}.mount"
        eval $DIFF_IN_META="${DIFF_IN_RESOLVED}.mount"

        # Extract apex_payload.img from APEX archives for separate diffoscope run
        if [[ "$(find "${DIFF_IN_RESOLVED}.mount" -type f -iname '*.apex' | wc -l)" -ne 0 ]]; then
            mkdir -p "${DIFF_IN_BASE}.apexes"
            find "${DIFF_IN_BASE}.mount" -type f -iname '*.apex' \
                -exec cp {} "${DIFF_IN_BASE}.apexes/" \;
            find "${DIFF_IN_BASE}.apexes" -type f -iname '*.apex' \
                -exec unzip "{}" -d "{}.unzip" \; \
                -exec mv "{}.unzip/apex_payload.img" "{}-apex_payload.img" \; \
                -exec rm -rf "{}.unzip" "{}" \;
            
            # Some production APEX files have the `com.google.android` prefix,
            # while GSI and aosp_* targets strictly use the `com.android` prefix
            # Perform linking for these to the common prefix to enable filename based matching
            (
                cd "${DIFF_IN_BASE}.apexes" && \
                find -type f -iname 'com.google.android.*-apex_payload.img' \
                    -exec bash -c 'ln -s "$0" "$(echo "$0" | sed "s/com.google.android/com.android/")"' "{}" \;
            )
            # AFAIK the bash -c invokation is needed to make the sed subshell invocation lazily evaluated during find result iteration

            # Have another look at the list if files in common, but only consider APEX related ones
            local -r APEX_FOLDER_BASENAME="$(basename "${DIFF_IN_BASE}.apexes")"
            local -ar APEX_PAYLOAD_FILES=($(comm -12 \
                <(cd "${IN_DIR_1}" && find "${APEX_FOLDER_BASENAME}" -type 'f,l' | sort) \
                <(cd "${IN_DIR_2}" && find "${APEX_FOLDER_BASENAME}" -type 'f,l' | sort) \
            ))
            # Append to list of files requiring processing via diffoscope
            FILES+=( "${APEX_PAYLOAD_FILES[@]}" )
        fi
    fi
    set -o errexit # Re-enable early exit

}

function postProcessImage {
    local DIFF_IN="$1"

    # Sanity check that we are dealing with a mount
    set +o errexit # Disable early exit
    mount | grep "${DIFF_IN}"
    if [[ "$?" -eq 0 ]]; then
        set -o errexit # Re-enable early exit

        IMAGE="$(dirname $DIFF_IN)/$(basename -s '.mount' "$DIFF_IN")"

        guestunmount "${IMAGE}.mount"
        rmdir "${IMAGE}.mount"

        if [[ "$IMAGE" = *".img.raw" ]]; then
            # Delete raw image that was uncompressed from the sparse one
            rm "$IMAGE"
        fi
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

    # Ensure that parent directory exists
    mkdir -p "$(dirname "${DIFF_OUT}")"

    # Assembly lengthy list of diffoscope arguments
    local -a DIFFOSCOPE_ARGS=()
    # Display output in all cases and show continous progress (helps with debugging and logging)
    DIFFOSCOPE_ARGS+=( --output-empty --progress )
    # Disregard directory/container metadata (e.g. ctime/mtime) on all levels
    DIFFOSCOPE_ARGS+=( --exclude-directory-metadata=recursive )
    # APKs embed certificates
    DIFFOSCOPE_ARGS+=( --exclude 'original/META-INF/CERT.RSA' )
    # APEX files embed a certificates and a separate public key. Furthermore ignore APEX payload images, treated in separate step
    DIFFOSCOPE_ARGS+=( --exclude 'META-INF/CERT.RSA' --exclude 'apex_pubkey' --exclude 'apex_payload.img' )
    # Certificates used by OTA updates
    DIFFOSCOPE_ARGS+=( --exclude 'update-payload-key.pub.pem' --exclude 'releasekey.x509.pem' --exclude 'testkey.x509.pem' )

    set +o errexit # Disable early exit
    # Due to a bug when using --max-diff-block-lines-saved and --html-dir at the same time, we call diffoscope twice
    "$(command -v diffoscope)" "${DIFFOSCOPE_ARGS[@]}" \
        --max-diff-block-lines-saved 200 \
        --json "${DIFF_OUT}.json" \
        "${DIFF_IN_1}" "${DIFF_IN_2}"
    "$(command -v diffoscope)" "${DIFFOSCOPE_ARGS[@]}" \
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

    # Ubuntu does not permit reading the local kernel images by non-root users, see https://bugs.launchpad.net/ubuntu/+source/libguestfs/+bug/1673431
    # guestfs requires that to provide a kernel for QEMU.
    sudo chmod +r "/boot/vmlinuz-"*

    # Create list of files in common for both directories. Ignore super.img, we unpacked it previously
    local -a FILES=($(comm -12 \
        <(cd "${IN_DIR_1}" && find -type f | sort) \
        <(cd "${IN_DIR_2}" && find -type f | sort) \
    | grep -v 'super.img'))

    for ((i = 0; i < "${#FILES[@]}"; i++)); do
        FILE="${FILES[$i]}"
        # Normalize concated paths (e.g "/path/to/./somewhere.img") to canonical ones (e.g. "/path/to/somewhere.img") via realpath
        diffoscopeFile "$(realpath "${IN_DIR_1}/${FILE}")" "$(realpath "${IN_DIR_2}/${FILE}")" \
            "$(realpath "${OUT_DIR}/${FILE}.diff")"
    done

    # Cleanup both builds after diffing process
    rm -rf "${IN_DIR_1}"
    rm -rf "${IN_DIR_2}"
}

main "$@"
