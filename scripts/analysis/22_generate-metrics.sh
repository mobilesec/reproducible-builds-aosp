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
    # read considers an encountered EOF as error, but that's fine in our multiline usage here, suppress via || true
    read -r -d '' AWK_CODE_DIFFSTAT_TO_DIFF_SCORE <<'_EOF_' || true
    {
        printf("%s,%d\n", $4, max($1, $2));
    }

    function max(a, b) {
        return a > b ? a: b
    }
_EOF_

    read -r -d '' AWK_CODE_DIFF_SCORE_SUMMARY <<'_EOF_' || true
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
            BASE_FILENAME="$(dirname "${DIFFSTAT_CSV_FILE}")/$(basename -s '-apex_payload.img.diffstat.csv' "${DIFFSTAT_CSV_FILE}")"
        elif [[ "$BASE_FILENAME" == *".img" ]]; then
            IS_IMG_WITH_APEX_WITHIN=true
        fi

        # Transform diffstat to diff score metric
        unset DIFFSTAT_CONTENT
        local DIFFSTAT_CONTENT=""
        if [[ "$IS_IMG_WITH_APEX_WITHIN" == true ]]; then
            DIFFSTAT_CONTENT+="$(tail --lines=+2 "$DIFFSTAT_CSV_FILE" \
                | grep --invert-match --extended-regexp '\.c?apex' || true \
            )"
        elif [[ "$IS_APEX" == true ]]; then
            # Extract diffstat lines from parent image for outer full APEX file
            local APEX_NAME PARENT_IMG_BASENAME
            APEX_NAME="$(sed 's/com\.android\.//' <( basename -s '.apex' "$BASE_FILENAME" ))"
            PARENT_IMG_BASENAME="$(dirname "$(dirname "$BASE_FILENAME")")/$(basename -s '.apexes' "$(dirname "$BASE_FILENAME")")"
            local PARENT_IMG_DIFFSTAT_CSV_FILE="${PARENT_IMG_BASENAME}.diffstat.csv"
            DIFFSTAT_CONTENT+="$(tail --lines=+2 "$PARENT_IMG_DIFFSTAT_CSV_FILE" \
                | grep "${APEX_NAME}\.apex" || true \
            )"
            DIFFSTAT_CONTENT+=$'\n'
            DIFFSTAT_CONTENT+="$(tail --lines=+2 "$DIFFSTAT_CSV_FILE")"
        else
            DIFFSTAT_CONTENT+="$(tail --lines=+2 "$DIFFSTAT_CSV_FILE")"
        fi

        # Write diff score file for artifact
        local METRIC_FILE="${BASE_FILENAME}.metric.diff-score.csv"
        echo -e "$HEADER_LINE" > "$METRIC_FILE"
        awk --field-separator ',' "$AWK_CODE_DIFFSTAT_TO_DIFF_SCORE" <( echo "$DIFFSTAT_CONTENT" ) >> "$METRIC_FILE"

        # Write summary entry
        local METRIC_CONTENT
        METRIC_CONTENT="$(tail --lines=+2 "$METRIC_FILE")"
        echo -n "${BASE_FILENAME}," >> "$SUMMARY_FILE"
        awk --field-separator ',' "$AWK_CODE_DIFF_SCORE_SUMMARY" <( echo "$METRIC_CONTENT" ) >> "$SUMMARY_FILE"

        # Determine major varation of diff score
        local MAJOR_METRIC_CONTENT
        if [[ "$BASE_FILENAME" == *"initrd.img" ]] || [[ "$BASE_FILENAME" == *"ramdisk.img" ]] || [[ "$BASE_FILENAME" == *"ramdisk-debug.img" ]]; then
            # Exclude res/images
            MAJOR_METRIC_CONTENT="$(echo "$METRIC_CONTENT" \
                | grep --invert-match 'res/images' \
                | grep --invert-match 'etc/NOTICE.xml.gz' \
            )"
        else
            # Exclude NOTICE.xml.gz in etc folder in all cases
            MAJOR_METRIC_CONTENT="$(grep 'etc/NOTICE.xml.gz' -v <( echo "$METRIC_CONTENT" ))"
        fi

        # Write major diff score file for artifact, but only if different
        if [[ "$MAJOR_METRIC_CONTENT" != "$METRIC_CONTENT" ]]; then
            local METRIC_MAJOR_FILE="${BASE_FILENAME}.metric.major-diff-score.csv"
            echo -e "$HEADER_LINE" > "$METRIC_MAJOR_FILE"
            echo "$MAJOR_METRIC_CONTENT" >> "$METRIC_MAJOR_FILE"
        fi

        # Write major summary entry
        echo -n "${BASE_FILENAME}," >> "$SUMMARY_MAJOR_FILE"
        awk --field-separator ',' "$AWK_CODE_DIFF_SCORE_SUMMARY" <(echo "$MAJOR_METRIC_CONTENT") >> "$SUMMARY_MAJOR_FILE"
    done

    # Sum up system.img with APEX files. Update system.img with it, but append self only number for traceability
    local SYSTEM_IMG_ONlY_SELF SYSTEM_IMG_SIZES
    SYSTEM_IMG_ONlY_SELF="$(tail --lines=+2 $SUMMARY_FILE \
        | grep 'system\.img,' \
        | sed 's/system\.img/system.img (only self)/' \
    )"
    SYSTEM_IMG_DIFF_SCORE="$(awk --field-separator ',' "$AWK_CODE_DIFF_SCORE_SUMMARY" <( tail --lines=+2 $SUMMARY_FILE \
        | grep 'system\.img') \
    )"
    sed --in-place --regexp-extended -e "s/system\.img,[0-9]+/system.img,${SYSTEM_IMG_DIFF_SCORE}/" "$SUMMARY_FILE"
    echo -n -e "${SYSTEM_IMG_ONlY_SELF}\n" >> "$SUMMARY_FILE"

    SYSTEM_IMG_ONlY_SELF="$(tail --lines=+2 $SUMMARY_MAJOR_FILE \
        | grep 'system\.img,' \
        | sed 's/system\.img/system.img (only self)/' \
    )"
    SYSTEM_IMG_DIFF_SCORE="$(awk --field-separator ',' "$AWK_CODE_DIFF_SCORE_SUMMARY" <( tail --lines=+2 $SUMMARY_MAJOR_FILE | grep 'system\.img') )"
    sed --in-place --regexp-extended -e "s/system\.img,[0-9]+/system.img,${SYSTEM_IMG_DIFF_SCORE}/" "$SUMMARY_MAJOR_FILE"
    echo -n -e "${SYSTEM_IMG_ONlY_SELF}\n" >> "$SUMMARY_MAJOR_FILE"
}

# weight score metric, i.e. sum of all files that have any difference in relation to overall size
generateMetricWeightScore() {
    # read considers an encountered EOF as error, but that's fine in our multiline usage here, suppress via || true
    read -r -d '' AWK_CODE_WEIGHT_SCORE_SUMMARY_SUMMARY <<'_EOF_' || true
    BEGIN {
        size_all = 0;
        size_changed = 0
    }

    {
        size_all += $2;
        size_changed += $3
    }

    END {
        printf("%d,%d", size_all, size_changed)
    }
_EOF_

    read -r -d '' AWK_CODE_FIND_FILE_LIST_START <<'_EOF_' || true
    /^--- /{
        if ( $2 ~ /a\/file␣list/ )
            { print NR + 3 }
    }
_EOF_
    
    read -r -d '' AWK_CODE_FIND_FILE_LIST_END <<_EOF_ || true
    BEGIN {
        passed_start = 0
    }
    
    /^--- /{
        if ( passed_start)
            { print NR-1; exit }
        else if ( (NR+3) == file_list_start )
            { passed_start = 1 }
    }
_EOF_

    # Start summary files
    local -r SUMMARY_FILE="summary.metric.weight-score.csv"
    local -r SUMMARY_MAJOR_FILE="summary.metric.major-weight-score.csv"
    rm -f "$SUMMARY_FILE" "$SUMMARY_MAJOR_FILE"
    local -r SUMMARY_HEADER_LINE="ARTIFACT,SIZE_ALL,SIZE_CHANGED,WEIGHT_SCORE"
    echo -e "${SUMMARY_HEADER_LINE}" > "$SUMMARY_FILE"
    echo -e "${SUMMARY_HEADER_LINE}" > "$SUMMARY_MAJOR_FILE"

    local -r HEADER_LINE="FILENAME,SIZE"
    local -r WEIGHT_SCORE_SCALE="5"

    local -a DIFFSTAT_CSV_FILES
    mapfile -t DIFFSTAT_CSV_FILES < <( find . -name '*.diffstat.csv' -type f | sort )
    declare -r DIFFSTAT_CSV_FILES
    for DIFFSTAT_CSV_FILE in "${DIFFSTAT_CSV_FILES[@]}"; do
        local BASE_FILENAME
        BASE_FILENAME="$(dirname "${DIFFSTAT_CSV_FILE}")/$(basename -s '.diffstat.csv' "${DIFFSTAT_CSV_FILE}")"
        local SOURCE_1_FILE_SIZES_FILE="${BASE_FILENAME}.source-1.file-sizes.csv"
        local SOURCE_1_FILE_SIZE_FILE="${BASE_FILENAME}.source-1.file-size.txt"
        local DIFF_FILE="${BASE_FILENAME}.diffoscope.json.flattened_clean.diff"
        # Helper variables
        local -i SIZE_ALL=0 SIZE_CHANGED=0 MAJOR_SIZE_CHANGED=0
        local WEIGHT_SCORE
        local METRIC_MAJOR_CHANGED_FILE

        # Determine flags related to APEX files fo future reference
        local IS_APEX=false
        local IS_IMG_WITH_APEX_WITHIN=false
        if [[ "$BASE_FILENAME" == *'.apex-apex_payload.img' ]]; then
            IS_APEX=true
            BASE_FILENAME="$(dirname "${DIFFSTAT_CSV_FILE}")/$(basename -s '-apex_payload.img.diffstat.csv' "${DIFFSTAT_CSV_FILE}")"
        elif [[ "$BASE_FILENAME" == *".img" ]]; then
            IS_IMG_WITH_APEX_WITHIN=true
        fi

        # Transform diffstat to weight score metric
        if [[ -f "${SOURCE_1_FILE_SIZES_FILE}" ]]; then
            # Artifact has file sizes metadata about its members
            unset CHANGED_FILES CHANGED_FILES_APEX
            local -a CHANGED_FILES CHANGED_FILES_APEX
            # Transform diffstat to list of changed files
            if [[ "$IS_IMG_WITH_APEX_WITHIN" == true ]]; then
                # Skip header, exclude file␣list entry, exclude all .apex files
                mapfile -t CHANGED_FILES < <( tail --lines=+2 "$DIFFSTAT_CSV_FILE" \
                    | cut --delimiter=, --fields=4 \
                    | grep --invert-match 'file list' \
                    | cut --delimiter=: --fields=1 \
                    | grep --invert-match --extended-regexp '\.c?apex' \
                )
            elif [[ "$IS_APEX" == true ]]; then
                # Extract diffstat lines from parent image for outer full APEX file
                local APEX_NAME PARENT_IMG_BASENAME
                APEX_NAME="$(sed 's/com\.android\.//' <( basename -s '.apex' "$BASE_FILENAME" ))"
                PARENT_IMG_BASENAME="$(dirname "$(dirname "$BASE_FILENAME")")/$(basename -s '.apexes' "$(dirname "$BASE_FILENAME")")"
                local PARENT_IMG_DIFFSTAT_CSV_FILE="${PARENT_IMG_BASENAME}.diffstat.csv"
                # Skip header, exclude file␣list entry, only entries related to ${APEX_NAME}.apex files
                # Subselect filename within container after :: via --fields=3, discard all known tool invocations
                mapfile -t CHANGED_FILES_APEX < <( tail --lines=+2 "$PARENT_IMG_DIFFSTAT_CSV_FILE" \
                    | grep "${APEX_NAME}\.apex" \
                    | cut --delimiter=, --fields=4 \
                    | grep --invert-match 'file list' \
                    | cut --delimiter=: --fields=3 \
                    | grep --invert-match --extended-regexp '(zipinfo )|(zipnote )' \
                    | sort --unique \
                )

                # Skip header, exclude file␣list entry
                mapfile -t CHANGED_FILES < <( tail --lines=+2 "$DIFFSTAT_CSV_FILE" \
                    | cut --delimiter=, --fields=4 \
                    | grep --invert-match 'file list' \
                    | cut --delimiter=: --fields=1 \
                )
            else
                # Skip header, exclude file␣list entry
                mapfile -t CHANGED_FILES < <( tail --lines=+2 "$DIFFSTAT_CSV_FILE" \
                    | cut --delimiter=, --fields=4 \
                    | grep --invert-match 'file list' \
                    | cut --delimiter=: --fields=1 \
                )
            fi
            # Append all files that exist only in source 1 by inspecting root file␣list entry in .diff
            if grep -- '--- a/file␣list' "$DIFF_FILE"; then
                local FILE_LIST_START FILE_LIST_END
                FILE_LIST_START="$(awk "$AWK_CODE_FIND_FILE_LIST_START" "$DIFF_FILE")"
                FILE_LIST_END="$(awk --assign file_list_start="${FILE_LIST_START}" "$AWK_CODE_FIND_FILE_LIST_END" "$DIFF_FILE")"
                if [[ "$BUILD_FLOW" == "generic" ]] && [[ "$BASE_FILENAME" == *"vendor.img" ]]; then
                    # Prefilter line range determined by start and end values, then extract deleted file names
                    # Exclude test related APKs from generic vendor.img
                    mapfile -t -O "${#CHANGED_FILES[@]}" CHANGED_FILES < <( sed -n "${FILE_LIST_START},${FILE_LIST_END}p" "$DIFF_FILE" \
                        | grep '^-' \
                        | sed -e 's/^-//g' \
                        | grep --invert-match --extended-regexp 'Tests?__auto_generated_rro_vendor\.apk' \
                    )
                else
                    # Prefilter line range determined by start and end values, then extract deleted file names
                    mapfile -t -O "${#CHANGED_FILES[@]}" CHANGED_FILES < <( sed -n "${FILE_LIST_START},${FILE_LIST_END}p" "$DIFF_FILE" \
                        | grep '^-' \
                        | sed -e 's/^-//g' \
                    )
                fi
            fi
            # Sort and eliminate duplicates from full list of changed files
            mapfile -t CHANGED_FILES < <( echo "${CHANGED_FILES[@]}" \
                | tr ' ' '\n' \
                | sort --unique \
            )

            # Prepare file size information
            unset SOURCE_1_FILE_SIZES SOURCE_1_FILE_SIZES_APEX
            local -a SOURCE_1_FILE_SIZES SOURCE_1_FILE_SIZES_APEX
            if [[ "$IS_IMG_WITH_APEX_WITHIN" == true ]]; then
                # Skip header, exclude root . directory entry, exclude APEX files
                mapfile -t SOURCE_1_FILE_SIZES < <( tail --lines=+2 "$SOURCE_1_FILE_SIZES_FILE" \
                    | grep --invert-match --extended-regexp '\.c?apex' \
                )
            elif [[ "$IS_APEX" == true ]]; then
                local SOURCE_1_APEX_FILE_SIZES_FILE="${BASE_FILENAME}.source-1.file-sizes.csv"
                # Skip header, exclude root . directory entry, exclude apex_payload since that's part of the main SOURCE_1_FILE_SIZES_FILE
                mapfile -t SOURCE_1_FILE_SIZES_APEX < <( tail --lines=+2 "$SOURCE_1_APEX_FILE_SIZES_FILE" \
                    | grep --invert-match 'apex_payload\.img' \
                )
                # Skip header, exclude root . directory entry
                mapfile -t SOURCE_1_FILE_SIZES < <( tail --lines=+2 "$SOURCE_1_FILE_SIZES_FILE" )
            else
                # Skip header, exclude root . directory entry
                mapfile -t SOURCE_1_FILE_SIZES < <( tail --lines=+2 "$SOURCE_1_FILE_SIZES_FILE" )
            fi

            # Persist all and changed file sizes for artifact for traceability
            local METRIC_ALL_FILE="${BASE_FILENAME}.metric.weight-score.all.csv"
            local METRIC_CHANGED_FILE="${BASE_FILENAME}.metric.weight-score.changed.csv"
            METRIC_MAJOR_CHANGED_FILE="${BASE_FILENAME}.metric.major-weight-score.changed.csv"
            echo -e "$HEADER_LINE" > "$METRIC_ALL_FILE"
            echo -e "$HEADER_LINE" > "$METRIC_CHANGED_FILE"
            echo -e "$HEADER_LINE" > "$METRIC_MAJOR_CHANGED_FILE"
            if [[ "$IS_APEX" == true ]]; then
                # Main variables only have content from apex_payload.img, handle files from outer .apex here
                for SOURCE_1_FILE_SIZE_APEX in "${SOURCE_1_FILE_SIZES_APEX[@]}"; do
                    local FILENAME FILENAME_REL SIZE
                    FILENAME_REL="${SOURCE_1_FILE_SIZE_APEX%,*}"
                    FILENAME="${FILENAME_REL:2}"
                    SIZE="${SOURCE_1_FILE_SIZE_APEX##*,}"
                    
                    SIZE_ALL=$(( SIZE_ALL + SIZE ))
                    echo "${FILENAME_REL},${SIZE}" >> "$METRIC_ALL_FILE"

                    for CHANGED_FILE_APEX in "${CHANGED_FILES_APEX[@]}"; do
                        if [[ "$FILENAME" = "$CHANGED_FILE_APEX" ]]; then
                            SIZE_CHANGED=$(( SIZE_CHANGED + SIZE ))
                            echo "${FILENAME_REL},${SIZE}" >> "$METRIC_CHANGED_FILE"

                            MAJOR_SIZE_CHANGED=$(( MAJOR_SIZE_CHANGED + SIZE ))
                            echo "${FILENAME_REL},${SIZE}" >> "$METRIC_MAJOR_CHANGED_FILE"
                        fi
                    done
                done
            fi
            # Compute changed files by traversing both arrays 
            for SOURCE_1_FILE_SIZE in "${SOURCE_1_FILE_SIZES[@]}"; do
                local FILENAME FILENAME_REL SIZE
                FILENAME_REL="${SOURCE_1_FILE_SIZE%,*}"
                FILENAME="${FILENAME_REL:2}"
                SIZE="${SOURCE_1_FILE_SIZE##*,}"
                
                SIZE_ALL=$(( SIZE_ALL + SIZE ))
                echo "${FILENAME_REL},${SIZE}" >> "$METRIC_ALL_FILE"

                for CHANGED_FILE in "${CHANGED_FILES[@]}"; do
                    if [[ "$FILENAME" == "$CHANGED_FILE" ]]; then
                        SIZE_CHANGED=$(( SIZE_CHANGED + SIZE ))
                        echo "${FILENAME_REL},${SIZE}" >> "$METRIC_CHANGED_FILE"

                        # Exclude certain files from major variation
                        if [[ "$FILENAME" == *"etc/NOTICE.xml.gz" ]]; then
                            continue
                        elif [[ "$BASE_FILENAME" == *"initrd.img" ]] || [[ "$BASE_FILENAME" == *"ramdisk.img" ]] || [[ "$BASE_FILENAME" == *"ramdisk-debug.img" ]]; then
                            if [[ "$FILENAME" == *"res/images"* ]]; then
                                continue
                            fi
                        fi
                        MAJOR_SIZE_CHANGED=$(( MAJOR_SIZE_CHANGED + SIZE ))
                        echo "${FILENAME_REL},${SIZE}" >> "$METRIC_MAJOR_CHANGED_FILE"
                    fi
                done
            done
            # Only keep major file sizes if they are different to normal version
            if [[ "$(md5sum "$METRIC_CHANGED_FILE" | cut '--delimiter= ' --fields=1 )" == "$(md5sum "$METRIC_MAJOR_CHANGED_FILE" | cut '--delimiter= ' --fields=1)" ]]; then
                rm "$METRIC_MAJOR_CHANGED_FILE"
            fi
        else
            # Artifact is treated as single file
            # Prepare values for summary file
            SIZE_ALL="$(cat "$SOURCE_1_FILE_SIZE_FILE")"
            if [[ $(stat --printf="%s" "$DIFF_FILE") -eq "1" ]]; then
                SIZE_CHANGED=0
                MAJOR_SIZE_CHANGED=0
            else
                SIZE_CHANGED=$(( SIZE_ALL ))
                MAJOR_SIZE_CHANGED=$(( SIZE_ALL ))
            fi
        fi

        # Write summary entry
        WEIGHT_SCORE="$(bc <<< "scale=${WEIGHT_SCORE_SCALE}; ${SIZE_CHANGED}/${SIZE_ALL}")"
        echo "${BASE_FILENAME},${SIZE_ALL},${SIZE_CHANGED},${WEIGHT_SCORE}" >> "$SUMMARY_FILE"            

        # Write major summary CSV entry
        WEIGHT_SCORE="$(bc <<< "scale=${WEIGHT_SCORE_SCALE}; ${MAJOR_SIZE_CHANGED}/${SIZE_ALL}")"
        echo "${BASE_FILENAME},${SIZE_ALL},${MAJOR_SIZE_CHANGED},${WEIGHT_SCORE}" >> "$SUMMARY_MAJOR_FILE"
    done

    # Sum up system.img with APEX files. Update system.img with it, but append self only number for traceability
    local SYSTEM_IMG_ONlY_SELF SYSTEM_IMG_SIZES
    SYSTEM_IMG_ONlY_SELF="$(tail --lines=+2 $SUMMARY_FILE \
        | grep 'system\.img,' \
        | sed 's/system\.img/system.img (only self)/' \
    )"
    SYSTEM_IMG_SIZES="$(awk --field-separator ',' "$AWK_CODE_WEIGHT_SCORE_SUMMARY_SUMMARY" <(tail --lines=+2 $SUMMARY_FILE \
        | grep 'system\.img') \
    )"
    WEIGHT_SCORE="$(bc <<< "scale=${WEIGHT_SCORE_SCALE}; ${SYSTEM_IMG_SIZES#*,}/${SYSTEM_IMG_SIZES%,*}")"
    sed --in-place --regexp-extended -e "s/system\.img,[0-9]+,[0-9]+,[0-9.]+/system.img,${SYSTEM_IMG_SIZES%,*},${SYSTEM_IMG_SIZES#*,},${WEIGHT_SCORE}/" "$SUMMARY_FILE"
    echo "${SYSTEM_IMG_ONlY_SELF}" >> "$SUMMARY_FILE"

    SYSTEM_IMG_ONlY_SELF="$(tail --lines=+2 $SUMMARY_MAJOR_FILE \
        | grep 'system\.img,' \
        | sed 's/system\.img/system.img (only self)/' \
    )"
    SYSTEM_IMG_SIZES="$(awk --field-separator ',' "$AWK_CODE_WEIGHT_SCORE_SUMMARY_SUMMARY" <(tail --lines=+2 $SUMMARY_MAJOR_FILE \
        | grep 'system\.img') \
    )"
    WEIGHT_SCORE="$(bc <<< "scale=${WEIGHT_SCORE_SCALE}; ${SYSTEM_IMG_SIZES#*,}/${SYSTEM_IMG_SIZES%,*}")"
    sed --in-place --regexp-extended -e "s/system\.img,[0-9]+,[0-9]+,[0-9.]+/system.img,${SYSTEM_IMG_SIZES%,*},${SYSTEM_IMG_SIZES#*,},${WEIGHT_SCORE}/" "$SUMMARY_MAJOR_FILE"
    echo "${SYSTEM_IMG_ONlY_SELF}" >> "$SUMMARY_MAJOR_FILE"
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
