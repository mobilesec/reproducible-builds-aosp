#!/bin/bash

# Copyright 2020 Manuel Pöll
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit -o nounset -o pipefail -o xtrace

generateMetricChangeLines() {
    # read considers an encountered EOF as error, but that's fine in our multiline usage here
    set +o errexit # Disable early exit
    read -r -d '' AWK_CODE_DIFFSTAT_TO_CHANGE_LINES <<'_EOF_'
    {
        printf("%s,%d\n", $4, max($1, $2));
    }

    function max(a, b) {
        return a > b ? a: b
    }
_EOF_

    read -r -d '' AWK_CODE_CHANGE_LINES_SUMMARY <<'_EOF_'
    BEGIN {
        change_lines_sum = 0
    }

    {
        change_lines_sum += $2
    }

    END {
        printf("%d\n", change_lines_sum)
    }
_EOF_
    set -o errexit # Re-enable early exit

    # Start summary files for the change line metric
    local -r SUMMARY_FILE="summary.metric.change-lines.csv"
    local -r SUMMARY_MAJOR_FILE="summary-major.metric.change-lines.csv"
    rm -f "$SUMMARY_FILE" "$SUMMARY_MAJOR_FILE"
    local -r SUMMARY_HEADER_LINE="ARTIFACT,CHANGE_LINES"
    echo -e "${SUMMARY_HEADER_LINE}" > "$SUMMARY_FILE"
    echo -e "${SUMMARY_HEADER_LINE}" > "$SUMMARY_MAJOR_FILE"

    local -r HEADER_LINE="FILENAME,CHANGE_LINES"

    local -a DIFFSTAT_CSV_FILES
    mapfile -t DIFFSTAT_CSV_FILES < <(find . -name '*.diffstat.csv' -type f | sort)
    declare -r DIFFSTAT_CSV_FILES
    for DIFFSTAT_CSV_FILE in "${DIFFSTAT_CSV_FILES[@]}"; do
        local BASE_FILENAME
        BASE_FILENAME="$(dirname "${DIFFSTAT_CSV_FILE}")/$(basename -s '.diffstat.csv' "${DIFFSTAT_CSV_FILE}")"

        # Transform diffstat CSV to change lines metric
        local DIFFSTAT_CONTENT
        DIFFSTAT_CONTENT="$(tail -n +2 "$DIFFSTAT_CSV_FILE")"
        local METRIC_CHANGE_LINES_FILE="${BASE_FILENAME}.metric.change-lines.csv"
        echo -e "$HEADER_LINE" > "$METRIC_CHANGE_LINES_FILE"
        awk --field-separator ',' "$AWK_CODE_DIFFSTAT_TO_CHANGE_LINES" <(echo "$DIFFSTAT_CONTENT") >> "$METRIC_CHANGE_LINES_FILE"

        # Write summary entry
        local METRIC_CONTENT
        METRIC_CONTENT="$(tail -n +2 "$METRIC_CHANGE_LINES_FILE")"
        echo -n "${BASE_FILENAME}," >> "$SUMMARY_FILE"
        awk --field-separator ',' "$AWK_CODE_CHANGE_LINES_SUMMARY" <(echo "$METRIC_CONTENT") >> "$SUMMARY_FILE"

        # Special logic that only tracks major differences
        local MAJOR_ARTIFACT="true"
        local METRIC_MAJOR_CONTENT
        if [[ "$BASE_FILENAME" = *"vendor.img" ]]; then
            # Skip vendor
            MAJOR_ARTIFACT="false"
            METRIC_MAJOR_CONTENT=""
        elif [[ "$BASE_FILENAME" = *"initrd.img" ]]; then
            # Exclude res/images
            METRIC_MAJOR_CONTENT="$(grep 'res/images' -v <(echo "$METRIC_CONTENT"))"
        elif [[ "$BASE_FILENAME" = *"system.img" ]]; then
            # Exclude NOTICE.xml
            METRIC_MAJOR_CONTENT="$(grep 'NOTICE.xml.gz' -v <(echo "$METRIC_CONTENT"))"
        else
            # Unchanged
            METRIC_MAJOR_CONTENT="$METRIC_CONTENT"
        fi

        if [[ "$MAJOR_ARTIFACT" = "true" ]]; then
            # Write major summary CSV entry
            echo -n "${BASE_FILENAME}," >> "$SUMMARY_MAJOR_FILE"
            awk --field-separator ',' "$AWK_CODE_CHANGE_LINES_SUMMARY" <(echo "$METRIC_MAJOR_CONTENT") >> "$SUMMARY_MAJOR_FILE"
        fi
    done
}

generateMetricChangedFiles() {
    # read considers an encountered EOF as error, but that's fine in our multiline usage here
    set +o errexit # Disable early exit
    read -r -d '' AWK_CODE_CHANGED_FILES_SUMMARY <<'_EOF_'
    BEGIN {
        files_size = 0
    }

    {
        files_size += $2
    }

    END {
        printf("%d", files_size)
    }
_EOF_
    set -o errexit # Re-enable early exit

    # Start summary file for the changed files metric
    local -r SUMMARY_FILE="summary.metric.changed-files.csv"
    rm -f "$SUMMARY_FILE"
    local -r SUMMARY_HEADER_LINE="ARTIFACT,SIZE_ALL,SIZE_CHANGED"
    echo -e "${SUMMARY_HEADER_LINE}" > "$SUMMARY_FILE"

    local -r HEADER_LINE="FILENAME,SIZE"

    local -a DIFFSTAT_CSV_FILES
    mapfile -t DIFFSTAT_CSV_FILES < <(find . -name '*.diffstat.csv' -type f | sort)
    declare -r DIFFSTAT_CSV_FILES
    for DIFFSTAT_CSV_FILE in "${DIFFSTAT_CSV_FILES[@]}"; do
        local BASE_FILENAME
        BASE_FILENAME="$(dirname "${DIFFSTAT_CSV_FILE}")/$(basename -s '.diffstat.csv' "${DIFFSTAT_CSV_FILE}")"
        local SOURCE_1_FILE_SIZES_FILE="${BASE_FILENAME}.source-1.file-sizes.csv"
        local DIFF_FILE="${BASE_FILENAME}.diffoscope.json.flattened_clean.diff"     
        local SIZE_ALL SIZE_CHANGED

        if [[ -f "${SOURCE_1_FILE_SIZES_FILE}" ]]; then
            # artifact has file sizes metadata about its members
            unset CHANGED_FILES
            local -a CHANGED_FILES
            # Transform diffstat CSV to changd files list
            mapfile -t CHANGED_FILES < <(tail -n +3 $DIFFSTAT_CSV_FILE \
                | cut --delimiter=, --fields=4 \
                | cut --delimiter=: --fields=1 \
                | uniq \
                | grep '.apex' -v \
            )
            # Extract list of deleted files from root file␣list entry in .diff

            if grep -- '--- a/file␣list' $DIFF_FILE; then
                local FILE_LIST_START FILE_LIST_END    
                FILE_LIST_START="$(awk '/^--- /{ if ( $2 ~ /a\/file␣list/ ) { print NR + 3 } }' $DIFF_FILE)"
                FILE_LIST_END="$(awk "BEGIN { passed_start = 0 }  /^--- /{ if ( passed_start) { print NR-1; exit } else if ( (NR+3) == $FILE_LIST_START ) { passed_start = 1 } }" $DIFF_FILE)"
                mapfile -t -O "${#CHANGED_FILES[@]}" CHANGED_FILES < <(sed -n "${FILE_LIST_START},${FILE_LIST_END}p" $DIFF_FILE \
                    | grep '^-' \
                    | sed -e 's/^-//g' \
                )
            fi

            # Persist list of changed files with their size
            local METRIC_CHANGED_FILES_FILE="${BASE_FILENAME}.metric.changed-files.csv"
            echo -e "$HEADER_LINE" > "$METRIC_CHANGED_FILES_FILE"
            while read -r LINE; do
                local FILENAME FILENAME_REL SIZE
                FILENAME_REL="${LINE%,*}"
                FILENAME="${FILENAME_REL:2}"
                SIZE="${LINE##*,}"
                
                if [[ " ${CHANGED_FILES[@]} " =~ " ${FILENAME} " ]]; then
                    echo "${FILENAME_REL},${SIZE}" >> "$METRIC_CHANGED_FILES_FILE"
                fi
            done < <(grep -v '^ *#' < $SOURCE_1_FILE_SIZES_FILE)

            # Prepare value for summary file
            SIZE_ALL="$(awk --field-separator ',' "$AWK_CODE_CHANGED_FILES_SUMMARY" <(echo "$(tail -n +2 "$SOURCE_1_FILE_SIZES_FILE")"))"
            SIZE_CHANGED="$(awk --field-separator ',' "$AWK_CODE_CHANGED_FILES_SUMMARY" <(echo "$(tail -n +2 "$METRIC_CHANGED_FILES_FILE")"))"
        else
            # artifact = single file

            # Prepare value for summary file
            local SOURCE_1_FILE_SIZE_FILE="${BASE_FILENAME}.source-1.file-size.txt"

            SIZE_ALL="$(cat "$SOURCE_1_FILE_SIZE_FILE")"
            if [[ $(stat --printf="%s" $DIFF_FILE) -eq "1" ]]; then
                SIZE_CHANGED="0"
            else
                SIZE_CHANGED="$SIZE_ALL"
            fi
        fi
        echo -n -e "${BASE_FILENAME},${SIZE_ALL},${SIZE_CHANGED}\n" >> "$SUMMARY_FILE"            
            
    done
}

main() {
    # Argument sanity check
    if [[ "$#" -ne 1 ]]; then
        echo "Usage: $0 <DIFF_DIR>"
        echo "DIFF_DIR: Output directory CSV output"
        exit 1
    fi
    local -r DIFF_DIR="$1"

    # Navigate to diff dir
    cd "${DIFF_DIR}"

    generateMetricChangeLines
    generateMetricChangedFiles
}

main "$@"
