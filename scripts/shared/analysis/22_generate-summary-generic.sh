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
        "./system.img.diff.json.csv" \
        $(find . -path '*.apexes/*' -iname '*-apex_payload.img.diff.json.csv' -type f) \
    )

    # Write CSV Summary Header
    local -r HEADER_LINE="FILENAME,$(head -n 1 ${CSV_FILES[0]} | cut -d , -f 1-3)"
    echo -e "${HEADER_LINE}" > "$SUMMARY_FILE"
    echo -e "${HEADER_LINE}" > "$SUMMARY_MAJOR_FILE"

    # read considers an encountered EOF as error, but for that's fine in our multiline usage here
    set +o errexit # Disable early exit
    read -r -d '' AWK_SUM_SOURCE_CSV <<'_EOF_'
    @include "join"
    BEGIN {
        for (i=1 ; i<=3 ; i++) {
            a[i] = 0
        }
    }

    {
        for (i=1 ; i<=3 ; i++) {
            a[i] += $i
        }
    }

    END {
        printf("%s\n", join(a, 1, 3, ","))
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
        if [[ "$BASE_NAME" = "system.img" ]]; then
            # Exclude NOTICE.xml
            local CSV_MAJOR_CONTENT="$(grep 'NOTICE.xml.gz' -v <(echo "$CSV_CONTENT"))"
        else
            # Unchanged
            local CSV_MAJOR_CONTENT="$CSV_CONTENT"
        fi

        # Write major summary CSV entry
        echo -n "${BASE_NAME}," >> "$SUMMARY_MAJOR_FILE"
        awk --field-separator ',' "$AWK_SUM_SOURCE_CSV" <(echo "$CSV_MAJOR_CONTENT") >> "$SUMMARY_MAJOR_FILE"
    done

    set +o errexit # Disable early exit
    read -r -d '' AWK_SUM_SUMMARY <<'_EOF_'
    @include "join"
    BEGIN {
        for (i=2 ; i<=4 ; i++) {
            a[i] = 0
        }
    }

    {
        for (i=2 ; i<=4 ; i++) {
            a[i] += $i
        }
    }

    END {
        printf("All,%s\n", join(a, 2, 4, ","))
    }
_EOF_
    set -o errexit # Re-enable early exit

    # Final sum over all files
    awk --field-separator ',' "$AWK_SUM_SUMMARY" <(tail -n +2 "$SUMMARY_FILE") >> "$SUMMARY_FILE"
    awk --field-separator ',' "$AWK_SUM_SUMMARY" <(tail -n +2 "$SUMMARY_MAJOR_FILE") >> "$SUMMARY_MAJOR_FILE"
}

main "$@"
