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
    local -r HEADER_LINE="FILENAME,CHANGE_LINES"
    echo -e "${HEADER_LINE}" > "$SUMMARY_FILE"
    echo -e "${HEADER_LINE}" > "$SUMMARY_MAJOR_FILE"

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
}

main "$@"
