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

# diff score metric, i.e. number of changed lines
generateMetricDiffScore() {
    # read considers an encountered EOF as error, but that's fine in our multiline usage here
    set +o errexit # Disable early exit
    read -r -d '' AWK_CODE_DIFFSTAT_TO_DIFF_SCORE <<'_EOF_'
    {
        printf("%s,%d\n", $4, max($1, $2));
    }

    function max(a, b) {
        return a > b ? a: b
    }
_EOF_

    read -r -d '' AWK_CODE_DIFF_SCORE_SUMMARY <<'_EOF_'
    BEGIN {
        diff_score_sum = 0
    }

    {
        diff_score_sum += $2
    }

    END {
        printf("%d\n", diff_score_sum)
    }
_EOF_
    set -o errexit # Re-enable early exit

    # Start summary files
    local -r SUMMARY_FILE="summary.metric.diff-score.csv"
    local -r SUMMARY_MAJOR_FILE="summary.metric.major-diff-score.csv"
    rm -f "$SUMMARY_FILE" "$SUMMARY_MAJOR_FILE"
    local -r SUMMARY_HEADER_LINE="ARTIFACT,DIFF_SCORE"
    echo -e "${SUMMARY_HEADER_LINE}" > "$SUMMARY_FILE"
    echo -e "${SUMMARY_HEADER_LINE}" > "$SUMMARY_MAJOR_FILE"

    local -r HEADER_LINE="FILENAME,DIFF_SCORE"

    local -a DIFFSTAT_CSV_FILES
    mapfile -t DIFFSTAT_CSV_FILES < <( find . -name '*.diffstat.csv' -type f | sort )
    declare -r DIFFSTAT_CSV_FILES
    for DIFFSTAT_CSV_FILE in "${DIFFSTAT_CSV_FILES[@]}"; do
        local BASE_FILENAME
        BASE_FILENAME="$(dirname "${DIFFSTAT_CSV_FILE}")/$(basename -s '.diffstat.csv' "${DIFFSTAT_CSV_FILE}")"

        # Determine flags related to APEX files fo future reference
        local IS_APEX=false
        local IS_IMG_WITH_APEX_WITHIN=false
        if [[ "$BASE_FILENAME" == *'.apex-apex_payload.img' ]]; then
            IS_APEX=true
        elif [[ "$BASE_FILENAME" == *".img" ]]; then
            IS_IMG_WITH_APEX_WITHIN=true
        fi

        # Transform diffstat CSV to diff score metric
        unset DIFFSTAT_CONTENT
        local DIFFSTAT_CONTENT=""
        if [ "$IS_IMG_WITH_APEX_WITHIN" == true ]; then
            set +o errexit # Disable early exit
            DIFFSTAT_CONTENT+="$(tail -n +2 "$DIFFSTAT_CSV_FILE" \
                | grep --invert-match '\.apex' \
            )"
            set -o errexit # Re-enable early exit
        elif [[ "$IS_APEX" == true ]]; then
            # Extract diffstat lines from parent image for outer full APEX file
            local APEX_NAME PARENT_IMG_BASENAME
            APEX_NAME="$(sed 's/com\.android\.//' <( basename -s '.apex-apex_payload.img' "$BASE_FILENAME" ))"
            PARENT_IMG_BASENAME="$(dirname "$(dirname "$BASE_FILENAME")")/$(basename -s '.apexes' "$(dirname "$BASE_FILENAME")")"
            local PARENT_IMG_DIFFSTAT_CSV_FILE="${PARENT_IMG_BASENAME}.diffstat.csv"
            set +o errexit # Disable early exit
            DIFFSTAT_CONTENT+="$(tail -n +2 "$PARENT_IMG_DIFFSTAT_CSV_FILE" \
                | grep "${APEX_NAME}\.apex" \
            )"
            set -o errexit # Re-enable early exit
            DIFFSTAT_CONTENT+=$'\n'
        fi
        DIFFSTAT_CONTENT+="$(tail -n +2 "$DIFFSTAT_CSV_FILE")"
        local METRIC_DIFF_SCORE_FILE="${BASE_FILENAME}.metric.diff-score.csv"
        echo -e "$HEADER_LINE" > "$METRIC_DIFF_SCORE_FILE"
        awk --field-separator ',' "$AWK_CODE_DIFFSTAT_TO_DIFF_SCORE" <( echo "$DIFFSTAT_CONTENT" ) >> "$METRIC_DIFF_SCORE_FILE"

        # Write summary entry
        local METRIC_CONTENT
        METRIC_CONTENT="$(tail -n +2 "$METRIC_DIFF_SCORE_FILE")"
        echo -n "${BASE_FILENAME}," >> "$SUMMARY_FILE"
        awk --field-separator ',' "$AWK_CODE_DIFF_SCORE_SUMMARY" <( echo "$METRIC_CONTENT" ) >> "$SUMMARY_FILE"

        # Special logic that only tracks major differences
        local MAJOR_ARTIFACT=true
        local MAJOR_METRIC_CONTENT
        if [[ "$BUILD_FLOW" == "device" ]] && [[ "$BASE_FILENAME" == *"vendor.img" ]]; then
            # Skip vendor
            MAJOR_ARTIFACT=false
            MAJOR_METRIC_CONTENT=""
        elif [[ "$BASE_FILENAME" == *"initrd.img" ]] || [[ "$BASE_FILENAME" == *"ramdisk.img" ]] || [[ "$BASE_FILENAME" == *"ramdisk-debug.img" ]]; then
            # Exclude res/images
            MAJOR_METRIC_CONTENT="$(grep 'res/images' -v <( echo "$METRIC_CONTENT" ))"
        elif [[ "$BASE_FILENAME" == *"system.img" ]]; then
            # Exclude NOTICE.xml
            MAJOR_METRIC_CONTENT="$(grep 'NOTICE.xml.gz' -v <( echo "$METRIC_CONTENT" ))"
        else
            # Unchanged
            MAJOR_METRIC_CONTENT="$METRIC_CONTENT"
        fi

        if [[ "$MAJOR_ARTIFACT" == true ]]; then
            # Write major summary CSV entry
            echo -n "${BASE_FILENAME}," >> "$SUMMARY_MAJOR_FILE"
            awk --field-separator ',' "$AWK_CODE_DIFF_SCORE_SUMMARY" <(echo "$MAJOR_METRIC_CONTENT") >> "$SUMMARY_MAJOR_FILE"
        fi
    done

    # Sum up system.img with APEX files. Update system.img with it, but append self only number for traceability
    local SYSTEM_IMG_ONlY_SELF SYSTEM_IMG_SIZES
    SYSTEM_IMG_ONlY_SELF="$(tail -n +2 $SUMMARY_FILE | grep 'system\.img,' | sed 's/system\.img/system.img (only self)/' )"
    SYSTEM_IMG_DIFF_SCORE="$(awk --field-separator ',' "$AWK_CODE_DIFF_SCORE_SUMMARY" <( tail -n +2 $SUMMARY_FILE | grep 'system\.img') )"
    sed --in-place --regexp-extended -e "s/system\.img,[0-9]+/system.img,${SYSTEM_IMG_DIFF_SCORE}/" "$SUMMARY_FILE"
    echo -n -e "${SYSTEM_IMG_ONlY_SELF}\n" >> "$SUMMARY_FILE"

    SYSTEM_IMG_ONlY_SELF="$(tail -n +2 $SUMMARY_MAJOR_FILE | grep 'system\.img,' | sed 's/system\.img/system.img (only self)/' )"
    SYSTEM_IMG_DIFF_SCORE="$(awk --field-separator ',' "$AWK_CODE_DIFF_SCORE_SUMMARY" <( tail -n +2 $SUMMARY_MAJOR_FILE | grep 'system\.img') )"
    sed --in-place --regexp-extended -e "s/system\.img,[0-9]+/system.img,${SYSTEM_IMG_DIFF_SCORE}/" "$SUMMARY_MAJOR_FILE"
    echo -n -e "${SYSTEM_IMG_ONlY_SELF}\n" >> "$SUMMARY_MAJOR_FILE"
}

# weight score metric, i.e. sum of all files that have any difference in relation to overall size
generateMetricWeightScore() {
    # read considers an encountered EOF as error, but that's fine in our multiline usage here
    set +o errexit # Disable early exit
    read -r -d '' AWK_CODE_WEIGHT_SCORE_SUMMARY <<'_EOF_'
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

    read -r -d '' AWK_CODE_WEIGHT_SCORE_SUMMARY_SUMMARY <<'_EOF_'
    BEGIN {
        size_all = 0
        size_changed = 0
    }

    {
        size_all += $2
        size_changed += $3
    }

    END {
        printf("%d,%d", size_all, size_changed)
    }
_EOF_
    set -o errexit # Re-enable early exit

    # Start summary files
    local -r SUMMARY_FILE="summary.metric.weight-score.csv"
    local -r SUMMARY_MAJOR_FILE="summary.metric.major-weight-score.csv"
    rm -f "$SUMMARY_FILE" "$SUMMARY_MAJOR_FILE"
    local -r SUMMARY_HEADER_LINE="ARTIFACT,SIZE_ALL,SIZE_CHANGED,WEIGHT_SCORE"
    echo -e "${SUMMARY_HEADER_LINE}" > "$SUMMARY_FILE"
    echo -e "${SUMMARY_HEADER_LINE}" > "$SUMMARY_MAJOR_FILE"

    local -r HEADER_LINE="FILENAME,SIZE"

    local WEIGHT_SCORE
    local -r WEIGHT_SCORE_SCALE="5"

    local -a DIFFSTAT_CSV_FILES
    mapfile -t DIFFSTAT_CSV_FILES < <( find . -name '*.diffstat.csv' -type f | sort )
    declare -r DIFFSTAT_CSV_FILES
    for DIFFSTAT_CSV_FILE in "${DIFFSTAT_CSV_FILES[@]}"; do
        local BASE_FILENAME
        BASE_FILENAME="$(dirname "${DIFFSTAT_CSV_FILE}")/$(basename -s '.diffstat.csv' "${DIFFSTAT_CSV_FILE}")"
        local SOURCE_1_FILE_SIZES_FILE="${BASE_FILENAME}.source-1.file-sizes.csv"
        local DIFF_FILE="${BASE_FILENAME}.diffoscope.json.flattened_clean.diff"     
        local SIZE_ALL SIZE_CHANGED

        # Determine flags related to APEX files fo future reference
        local IS_APEX=false
        local IS_IMG_WITH_APEX_WITHIN=false
        if [[ "$BASE_FILENAME" == *'.apex-apex_payload.img' ]]; then
            IS_APEX=true
        elif [[ "$BASE_FILENAME" == *".img" ]]; then
            IS_IMG_WITH_APEX_WITHIN=true
        fi

        if [[ -f "${SOURCE_1_FILE_SIZES_FILE}" ]]; then
            # artifact has file sizes metadata about its members
            unset CHANGED_FILES
            local -a CHANGED_FILES
            # Transform diffstat CSV to list of changed files
            if [ "$IS_IMG_WITH_APEX_WITHIN" == true ]; then
                mapfile -t CHANGED_FILES < <( tail -n +3 "$DIFFSTAT_CSV_FILE" \
                    | cut --delimiter=, --fields=4 \
                    | cut --delimiter=: --fields=1 \
                    | uniq \
                    | grep --invert-match '\.apex' \
                )
            elif [[ "$IS_APEX" == true ]]; then
                # Extract diffstat lines from parent image for outer full APEX file
                local APEX_NAME PARENT_IMG_BASENAME
                APEX_NAME="$(sed 's/com\.android\.//' <( basename -s '.apex-apex_payload.img' "$BASE_FILENAME" ))"
                PARENT_IMG_BASENAME="$(dirname "$(dirname "$BASE_FILENAME")")/$(basename -s '.apexes' "$(dirname "$BASE_FILENAME")")"
                local PARENT_IMG_DIFFSTAT_CSV_FILE="${PARENT_IMG_BASENAME}.diffstat.csv"
                mapfile -t CHANGED_FILES < <( tail -n +3 "$PARENT_IMG_DIFFSTAT_CSV_FILE" \
                    | grep "${APEX_NAME}\.apex" \
                    | cut --delimiter=, --fields=4 \
                    | cut --delimiter=: --fields=3 \
                    | grep --invert-match --extended-regexp '(zipinfo )|(zipnote )' \
                    | uniq \
                )

                mapfile -t -O "${#CHANGED_FILES[@]}" CHANGED_FILES < <( tail -n +3 "$DIFFSTAT_CSV_FILE" \
                    | cut --delimiter=, --fields=4 \
                    | cut --delimiter=: --fields=1 \
                    | uniq \
                )
            else
                mapfile -t CHANGED_FILES < <( tail -n +3 "$DIFFSTAT_CSV_FILE" \
                    | cut --delimiter=, --fields=4 \
                    | cut --delimiter=: --fields=1 \
                    | uniq \
                )
            fi
            # Extract list of deleted files from root file␣list entry in .diff
            if grep -- '--- a/file␣list' "$DIFF_FILE"; then
                local FILE_LIST_START FILE_LIST_END    
                FILE_LIST_START="$(awk '/^--- /{ if ( $2 ~ /a\/file␣list/ ) { print NR + 3 } }' "$DIFF_FILE")"
                FILE_LIST_END="$(awk "BEGIN { passed_start = 0 }  /^--- /{ if ( passed_start) { print NR-1; exit } else if ( (NR+3) == $FILE_LIST_START ) { passed_start = 1 } }" "$DIFF_FILE")"
                mapfile -t -O "${#CHANGED_FILES[@]}" CHANGED_FILES < <( sed -n "${FILE_LIST_START},${FILE_LIST_END}p" "$DIFF_FILE" \
                    | grep '^-' \
                    | sed -e 's/^-//g' \
                )
            fi

            # Retrieve file size information
            local SOURCE_1_FILE_SIZES=""
            if [[ "$IS_APEX" == true ]]; then
                OUTER_SOURCE_1_FILE_SIZES_FILE="$(dirname "$BASE_FILENAME")/$(basename -s '-apex_payload.img' "$BASE_FILENAME").source-1.file-sizes.csv"
                SOURCE_1_FILE_SIZES+="$(tail -n +3 "$OUTER_SOURCE_1_FILE_SIZES_FILE" \
                    | grep --invert-match '\.\/apex_payload\.img' \
                )"
                SOURCE_1_FILE_SIZES+=$'\n'
            fi
            SOURCE_1_FILE_SIZES+="$(tail -n +3 "$SOURCE_1_FILE_SIZES_FILE")"

            # Persist list of all/changed files with their size
            local METRIC_WEIGHT_SCORE_ALL_FILE="${BASE_FILENAME}.metric.weight-score.all.csv"
            local METRIC_WEIGHT_SCORE_CHANGED_FILE="${BASE_FILENAME}.metric.weight-score.changed.csv"
            echo -e "$HEADER_LINE" > "$METRIC_WEIGHT_SCORE_ALL_FILE"
            echo -e "$HEADER_LINE" > "$METRIC_WEIGHT_SCORE_CHANGED_FILE"
            while read -r LINE; do
                local FILENAME FILENAME_REL SIZE
                FILENAME_REL="${LINE%,*}"
                FILENAME="${FILENAME_REL:2}"
                SIZE="${LINE##*,}"
                
                echo "${FILENAME_REL},${SIZE}" >> "$METRIC_WEIGHT_SCORE_ALL_FILE"

                for CHANGED_FILE in "${CHANGED_FILES[@]}"; do
                    if [[ "$FILENAME" = "$CHANGED_FILE" ]]; then
                        echo "${FILENAME_REL},${SIZE}" >> "$METRIC_WEIGHT_SCORE_CHANGED_FILE"
                    fi
                done
            done < <( grep --invert-match '^ *#' < <(echo "$SOURCE_1_FILE_SIZES") )

            # Prepare value for summary file
            SIZE_ALL="$(awk --field-separator ',' "$AWK_CODE_WEIGHT_SCORE_SUMMARY" <( echo "$SOURCE_1_FILE_SIZES" ))"
            SIZE_CHANGED="$(awk --field-separator ',' "$AWK_CODE_WEIGHT_SCORE_SUMMARY" <( tail -n +2 "$METRIC_WEIGHT_SCORE_CHANGED_FILE" ))"
        else
            # artifact = single file

            # Prepare value for summary file
            local SOURCE_1_FILE_SIZE_FILE="${BASE_FILENAME}.source-1.file-size.txt"

            SIZE_ALL="$(cat "$SOURCE_1_FILE_SIZE_FILE")"
            if [[ $(stat --printf="%s" "$DIFF_FILE") -eq "1" ]]; then
                SIZE_CHANGED="0"
            else
                SIZE_CHANGED="$SIZE_ALL"
            fi
        fi
        WEIGHT_SCORE="$(bc <<< "scale=${WEIGHT_SCORE_SCALE}; ${SIZE_CHANGED}/${SIZE_ALL}")"
        echo -n -e "${BASE_FILENAME},${SIZE_ALL},${SIZE_CHANGED},${WEIGHT_SCORE}\n" >> "$SUMMARY_FILE"            
        
        # Special logic that only tracks major differences
        local MAJOR_ARTIFACT=true
        local MAJOR_SIZE_CHANGED
        if [[ "$BUILD_FLOW" == "device" ]] && [[ "$BASE_FILENAME" == *"vendor.img" ]]; then
            # Skip vendor
            MAJOR_ARTIFACT=false
            MAJOR_SIZE_CHANGED=""
        elif [[ "$BASE_FILENAME" == *"initrd.img" ]] || [[ "$BASE_FILENAME" == *"ramdisk.img" ]] || [[ "$BASE_FILENAME" == *"ramdisk-debug.img" ]]; then
            # Exclude res/images
            MAJOR_SIZE_CHANGED="$(awk --field-separator ',' "$AWK_CODE_WEIGHT_SCORE_SUMMARY" <( tail -n +2 "$METRIC_WEIGHT_SCORE_CHANGED_FILE" | grep --invert-match 'res/images' ))"
        elif [[ "$BASE_FILENAME" == *"system.img" ]]; then
            # Exclude NOTICE.xml
            MAJOR_SIZE_CHANGED="$(awk --field-separator ',' "$AWK_CODE_WEIGHT_SCORE_SUMMARY" <( tail -n +2 "$METRIC_WEIGHT_SCORE_CHANGED_FILE" | grep --invert-match 'NOTICE.xml.gz' ))"
        else
            # Unchanged
            MAJOR_SIZE_CHANGED="$SIZE_CHANGED"
        fi

        if [[ "$MAJOR_ARTIFACT" == true ]]; then
            # Write major summary CSV entry
            WEIGHT_SCORE="$(bc <<< "scale=${WEIGHT_SCORE_SCALE}; ${MAJOR_SIZE_CHANGED}/${SIZE_ALL}")"
            echo -n -e "${BASE_FILENAME},${SIZE_ALL},${MAJOR_SIZE_CHANGED},${WEIGHT_SCORE}\n" >> "$SUMMARY_MAJOR_FILE"
        fi
    done

    # Sum up system.img with APEX files. Update system.img with it, but append self only number for traceability
    local SYSTEM_IMG_ONlY_SELF SYSTEM_IMG_SIZES
    SYSTEM_IMG_ONlY_SELF="$(tail -n +2 $SUMMARY_FILE | grep 'system\.img,' | sed 's/system\.img/system.img (only self)/' )"
    SYSTEM_IMG_SIZES="$(awk --field-separator ',' "$AWK_CODE_WEIGHT_SCORE_SUMMARY_SUMMARY" <(tail -n +2 $SUMMARY_FILE | grep 'system\.img') )"
    WEIGHT_SCORE="$(bc <<< "scale=${WEIGHT_SCORE_SCALE}; ${SYSTEM_IMG_SIZES#*,}/${SYSTEM_IMG_SIZES%,*}")"
    sed --in-place --regexp-extended -e "s/system\.img,[0-9]+,[0-9]+,[0-9.]+/system.img,${SYSTEM_IMG_SIZES%,*},${SYSTEM_IMG_SIZES#*,},${WEIGHT_SCORE}/" "$SUMMARY_FILE"
    echo -n -e "${SYSTEM_IMG_ONlY_SELF}\n" >> "$SUMMARY_FILE"

    SYSTEM_IMG_ONlY_SELF="$(tail -n +2 $SUMMARY_MAJOR_FILE | grep 'system\.img,' | sed 's/system\.img/system.img (only self)/' )"
    SYSTEM_IMG_SIZES="$(awk --field-separator ',' "$AWK_CODE_WEIGHT_SCORE_SUMMARY_SUMMARY" <(tail -n +2 $SUMMARY_MAJOR_FILE | grep 'system\.img') )"
    WEIGHT_SCORE="$(bc <<< "scale=${WEIGHT_SCORE_SCALE}; ${SYSTEM_IMG_SIZES#*,}/${SYSTEM_IMG_SIZES%,*}")"
    sed --in-place --regexp-extended -e "s/system\.img,[0-9]+,[0-9]+,[0-9.]+/system.img,${SYSTEM_IMG_SIZES%,*},${SYSTEM_IMG_SIZES#*,},${WEIGHT_SCORE}/" "$SUMMARY_MAJOR_FILE"
    echo -n -e "${SYSTEM_IMG_ONlY_SELF}\n" >> "$SUMMARY_MAJOR_FILE"
}

main() {
    # Argument sanity check
    if [[ "$#" -ne 2 ]]; then
        echo "Usage: $0 <DIFF_DIR> <BUILD_FLOW>"
        echo "DIFF_DIR: Output directory CSV output"
        echo "BUILD_FLOW: Either 'device' or 'generic', there are slight varations in the major variation of the metrics"
        exit 1
    fi
    local -r DIFF_DIR="$1"
    local -r BUILD_FLOW="$2"
    if [[ "$BUILD_FLOW" != "device" ]] && [[ "$BUILD_FLOW" != "generic" ]]; then
        echo "Invalid BUILD_FLOW, expected either 'device' or 'generic'"
    fi

    # Navigate to diff dir
    cd "${DIFF_DIR}"

    generateMetricDiffScore
    generateMetricWeightScore
}

main "$@"
