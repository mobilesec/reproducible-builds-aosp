#!/bin/bash
set -o errexit -o nounset -o pipefail -o xtrace

main() {
    # Argument sanity check
    if [[ "$#" -ne 1 ]]; then
        echo "Usage: $0 <DIFF_DIR>"
        echo "DIFF_DIR: Output directory CSV output"
        exit 1
    fi
    local -r DIFF_DIR="$1"
    # Reproducible base directory
    if [[ -z "${RB_AOSP_BASE+x}" ]]; then
        # Use default location
        local -r RB_AOSP_BASE="${HOME}/aosp"
        mkdir -p "${RB_AOSP_BASE}"
    fi

    # Navigate to diff dir
    cd "${DIFF_DIR}"
    local -r SUMMARY_FILE="summary.csv"
    local -r SUMMARY_MAJOR_FILE="summary-major.csv"
    rm -f "$SUMMARY_FILE" "$SUMMARY_MAJOR_FILE"

    # Hardcoded lits of files relevant for summary. If any of these is missing, we did something wrong
    # APEX files are dyanmically enumerated, since there may be many and they are all relevant
    local -ar CSV_FILES=( \
        "./android-info.txt.diff.json.csv" \
        "./boot.img.diff.json.csv" \
        "./dtbo.img.diff.json.csv" \
        "./system_other.img.diff.json.csv" \
        "./system.img.diff.json.csv" \
        "./vbmeta.img.diff.json.csv" \
        "./vendor.img.diff.json.csv" \
        $(find . -path '*.apexes/*' -iname '*-apex_payload.img.diff.json.csv' -type f) \
    )

    # Write CSV Summary Header
    local -r HEADER_LINE="FILENAME,$(head -n 1 ${CSV_FILES[0]} | cut -d , -f 1-3)"
    echo -e "${HEADER_LINE}" > "$SUMMARY_FILE"
    echo -e "${HEADER_LINE}" > "$SUMMARY_MAJOR_FILE"

    # read considers an encountered EOF as error, but for that's fine in our multiline usage here
    set +o errexit # Disable early exit
    read -r -d '' AWK_SUM_SOURCE_CSV <<-'_EOF_'
    @include "join"
    {
        for (i=1 ; i<=NF-1 ; i++) {
            a[i] += $i
        }
    }

    END {
        printf("%s\n", join(a, 1, NF-1, ","))
    }
_EOF_
    set -o errexit # Re-enable early exit

    for CSV_FILE in "${CSV_FILES[@]}"; do
        local BASE_NAME="$(basename --suffix '.diff.json.csv' "$CSV_FILE")"
        local CSV_CONTENT="$(tail -n +2 "$CSV_FILE")"

        # Write summary CSV entry
        echo -n "${BASE_NAME}," >> "$SUMMARY_FILE"
        awk --field-separator ',' "$AWK_SUM_SOURCE_CSV" <(echo "$CSV_CONTENT") >> "$SUMMARY_FILE"

        # Special logic that only tracks major differences
        if [[ "$BASE_NAME" = "vendor.img" || ( "$BASE_NAME" = "com.android."* && "$BASE_NAME" != "com.android.runtime.release"* ) ]]; then
            # Skip vendor and all APEX filesx except 
            local CSV_MAJOR_CONTENT=""
        elif [[ "$BASE_NAME" = "boot.img" ]]; then
            # Exclude res/images
            local CSV_MAJOR_CONTENT="$(grep 'res/images' -v <(echo "$CSV_CONTENT"))"
        elif [[ "$BASE_NAME" = "system.img" ]]; then
            # Exclude NOTICE.xml
            local CSV_MAJOR_CONTENT="$(grep 'NOTICE.xml.gz' -v <(echo "$CSV_CONTENT"))"
        else
            # Unchanged
            local CSV_MAJOR_CONTENT="$CSV_CONTENT"
        fi

        if [[ "$CSV_MAJOR_CONTENT" != "" ]]; then
            # Write major summary CSV entry
            echo -n "${BASE_NAME}," >> "$SUMMARY_MAJOR_FILE"
            awk --field-separator ',' "$AWK_SUM_SOURCE_CSV" <(echo "$CSV_MAJOR_CONTENT") >> "$SUMMARY_MAJOR_FILE"
        fi
    done

    set +o errexit # Disable early exit
    read -r -d '' AWK_SUM_SUMMARY <<-'_EOF_'
    @include "join"
    {
        for (i=2 ; i<=NF ; i++) {
            a[i] += $i
        }
    }

    END {
        printf("All,%s\n", join(a, 2, NF, ","))
    }
_EOF_
    set -o errexit # Re-enable early exit

    # Final sum over all files
    awk --field-separator ',' "$AWK_SUM_SUMMARY" <(tail -n +2 "$SUMMARY_FILE") >> "$SUMMARY_FILE"
    awk --field-separator ',' "$AWK_SUM_SUMMARY" <(tail -n +2 "$SUMMARY_MAJOR_FILE") >> "$SUMMARY_MAJOR_FILE"
}

main "$@"
