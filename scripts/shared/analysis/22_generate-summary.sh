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

    # Both images and APEX files are dyanmically enumerated
    local -ar CSV_FILES=( \
        "./android-info.txt.diff.json.csv" \
        $(find . -iname '*.img.diff.json.csv' -type f | sort) \
    )

    # Write CSV Summary Header
    local -r HEADER_LINE="FILENAME,$(head -n 1 ${CSV_FILES[0]} | cut -d , -f 1-3)"
    echo -e "${HEADER_LINE}" > "$SUMMARY_FILE"
    echo -e "${HEADER_LINE}" > "$SUMMARY_MAJOR_FILE"

    # read considers an encountered EOF as error, but that's fine in our multiline usage here
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

    # Some diffs are expected due to being metadata of some excludes.
    # An example diff can be found in `doc/expected-diffs.diff`, aggregated these are
    # * APEX files
    #   * zipinfo: +5, -6
    #   * zipnote: +0, -3
    #   * META-INF/CERT.SF: +3, -6
    #   * META-INF/MANIFEST.MF: +2, -5
    #   * stat: +1, -1
    # * APK files
    #   * zipinfo: +5, -6
    #   * APK metadata: +1, -2
    #   * META-INF/MANIFEST.MF: +0, -3
    #   * META-INF/CERT.SF: +1, -4
    #   * stat: +1, -1
    # * etc/security/otacerts.zip
    #   * zipinfo: +3, -3
    #   * zipnote: +1, -1
    #   * stat: +1, -1
    # * etc/selinux/plat_mac_permissions.xml
    #   * content: +3, -3
    #   * stat: +1, -1
    read -r -d '' AWK_SIGNING_ADJUSTMENTS_CSV <<'_EOF_'
    {
        if ( $4 ~ /\.apex::zipinfo/ )
            { $1 -= 5; $2 -= 6; }
        else if ( $4 ~ /\.apex::zipnote/ )
            { $1 -= 0; $2 -= 3; }
        else if ( $4 ~ /\.apex::META-INF\/CERT\.SF/ )
            { $1 -= 3; $2 -= 6; }
        else if ( $4 ~ /\.apex::META-INF\/MANIFEST\.MF/ )
            { $1 -= 2; $2 -= 5; }
        else if ( $4 ~ /\.apex::stat/ )
            { $1 -= 1; $2 -= 1; }
        else if ( $4 ~ /\.apk::zipinfo/ )
            { $1 -= 5; $2 -= 6; }
        else if ( $4 ~ /\.apk::APK metadata/ )
            { $1 -= 1; $2 -= 2; }
        else if ( $4 ~ /\.apk::original\/META-INF\/MANIFEST\.MF/ )
            { $1 -= 0; $2 -= 3; }
        else if ( $4 ~ /\.apk::original\/META-INF\/CERT\.SF/ )
            { $1 -= 1; $2 -= 4; }
        else if ( $4 ~ /\.apk::stat/ )
            { $1 -= 1; $2 -= 1; }
        else if ( $4 ~ /etc\/security\/otacerts\.zip::zipinfo/ )
            { $1 -= 3; $2 -= 3; }
        else if ( $4 ~ /etc\/security\/otacerts\.zip::zipnote/ )
            { $1 -= 1; $2 -= 1; }
        else if ( $4 ~ /etc\/security\/otacerts\.zip::stat/ )
            { $1 -= 1; $2 -= 1; }
        else if ( $4 ~ /etc\/selinux\/plat_mac_permissions\.xml::stat/ )
            { $1 -= 1; $2 -= 1; }
        else if ( $4 ~ /etc\/selinux\/plat_mac_permissions\.xml/ )
            { $1 -= 3; $2 -= 3; }

        if ( $1 > 0 || $2 > 0 || $3 > 0 ) {
            printf("%d,%d,%d,%s\n", $1, $2, $3, $4)
        }
    }
_EOF_
    set -o errexit # Re-enable early exit

    for CSV_FILE in "${CSV_FILES[@]}"; do
        local BASE_NAME="$(basename --suffix '.diff.json.csv' "$CSV_FILE")"
        local CSV_CONTENT="$(tail -n +2 "$CSV_FILE")"

        # Perform adjustments for signing related numbers
        local CSV_FILE_ADJUSTED="${BASE_NAME}.diff.json.adjusted.csv"
        echo -e "$(head -n 1 ${CSV_FILE})" > "$CSV_FILE_ADJUSTED"
        awk --field-separator ',' "$AWK_SIGNING_ADJUSTMENTS_CSV" <(echo "$CSV_CONTENT") >> "$CSV_FILE_ADJUSTED"
        CSV_CONTENT="$(tail -n +2 "$CSV_FILE_ADJUSTED")"

        # Write summary CSV entry
        echo -n "${BASE_NAME}," >> "$SUMMARY_FILE"
        awk --field-separator ',' "$AWK_SUM_SOURCE_CSV" <(echo "$CSV_CONTENT") >> "$SUMMARY_FILE"

        # Special logic that only tracks major differences
        local MAJOR_ARTIFACT="true"
        if [[ "$BASE_NAME" = "vendor.img" ]]; then
            # Skip vendor
            local MAJOR_ARTIFACT="false"
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

        if [[ "$MAJOR_ARTIFACT" = "true" ]]; then
            # Write major summary CSV entry
            echo -n "${BASE_NAME}," >> "$SUMMARY_MAJOR_FILE"
            awk --field-separator ',' "$AWK_SUM_SOURCE_CSV" <(echo "$CSV_MAJOR_CONTENT") >> "$SUMMARY_MAJOR_FILE"
        fi
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
