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
        echo "DIFF_DIR: Output directory diff output"
        exit 1
    fi
    local -r DIFF_DIR="$1"
    # Reproducible base directory
    if [[ -z "${RB_AOSP_BASE+x}" ]]; then
        # Use default location
        local -r RB_AOSP_BASE="${HOME}/aosp"
        mkdir -p "${RB_AOSP_BASE}"
    fi

    # Template directory
    local -r SCRIPT_LOCATION="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
    local -r LOCATION_IN_RB_AOSP="scripts/shared/analysis"
    local -r SCRIPT_BASE=${SCRIPT_LOCATION%"$LOCATION_IN_RB_AOSP"}
    # Templates
    local -r TEMPLATE_CHANGE_VIS="${SCRIPT_BASE}html-template/change-vis.html"
    local -r TEMPLATE_SUMMARY="${SCRIPT_BASE}html-template/summary.html"
    local -r SOAP_VERSION_FILE="${SCRIPT_BASE}.version"
    # Report Info
    local -r SOAP_VERSION=$(cat $SOAP_VERSION_FILE)
    local -r DATETIME=$(date -u)

    # Navigate to diff dir
    cd "$DIFF_DIR"

    # Generate diffoscope reports template string
    local -ar DIFFOSCOPE_REPORTS=($(find . -path '*.diff.html-dir/index.html' | sort))
    local DIFFOSCOPE_REPORTS_TEMPLATE=""
    for DIFFOSCOPE_REPORT in "${DIFFOSCOPE_REPORTS[@]}"; do
        # Fix jQuery location from local to a CDN, specifically
        # src="https://code.jquery.com/jquery-3.5.1.min.js" integrity="sha384-ZvpUoO/+PpLXR1lu4jmpXWu80pZlYUAfxl5NsBMWOEPSjUn/6Z/hRTt8+pR6L4N2" crossorigin="anonymous"
        sed -i 's/src="jquery.js"/src="https:\/\/code.jquery.com\/jquery-3.5.1.min.js" integrity="sha384-ZvpUoO\/+PpLXR1lu4jmpXWu80pZlYUAfxl5NsBMWOEPSjUn\/6Z\/hRTt8+pR6L4N2" crossorigin="anonymous"/g' \
            "$DIFFOSCOPE_REPORT"

        DIFFOSCOPE_REPORTS_TEMPLATE+="<a href=\"${DIFFOSCOPE_REPORT}\">${DIFFOSCOPE_REPORT}</a><br>"
    done

    # Generate Change visualisation reports + template string
    local -ar CHANGE_VIS_CSV_FILES=($(find . -path '*.diff.json.csv' | sort))
    local CHANGE_VIS_REPORTS_TEMPLATE=""
    for CHANGE_VIS_CSV_FILE in "${CHANGE_VIS_CSV_FILES[@]}"; do
        local CHANGE_VIS_REPORT="$(basename --suffix '.diff.json.csv' "$CHANGE_VIS_CSV_FILE").change-vis.html"
        cp "$TEMPLATE_CHANGE_VIS" "$CHANGE_VIS_REPORT"
        # Make safe for sed replace, see https://stackoverflow.com/a/2705678
        local CHANGE_VIS_CSV_FILE_ESCAPED=$(printf '%s\n' "$CHANGE_VIS_CSV_FILE" | sed -e 's/[\/&]/\\&/g')
        sed -E -i -e "s/\\\$CHANGE_VIS_CSV_FILE/$CHANGE_VIS_CSV_FILE_ESCAPED/" \
            -e "s/\\\$SOAP_VERSION/$SOAP_VERSION/" \
            -e "s/\\\$DATETIME/$DATETIME/" \
            "$CHANGE_VIS_REPORT"
        CHANGE_VIS_REPORTS_TEMPLATE+="<a href=\"${CHANGE_VIS_REPORT}\">${CHANGE_VIS_REPORT}</a><br>"
    done

    # Generate summary report
    local -r SUMMARY_REPORT="./summary.html"
    cp "$TEMPLATE_SUMMARY" "$SUMMARY_REPORT"
    # Make safe for sed replace, see https://stackoverflow.com/a/2705678
    local -r DIFF_DIR_ESCAPED=$(printf '%s\n' "$(basename "$DIFF_DIR")" | sed -e 's/[\/&]/\\&/g')
    local -r DIFFOSCOPE_REPORTS_TEMPLATE_ESCAPED=$(printf '%s\n' "$DIFFOSCOPE_REPORTS_TEMPLATE" | sed -e 's/[\/&]/\\&/g')
    local -r CHANGE_VIS_REPORTS_TEMPLATE_ESCAPED=$(printf '%s\n' "$CHANGE_VIS_REPORTS_TEMPLATE" | sed -e 's/[\/&]/\\&/g')
    sed -E -i -e "s/\\\$DIFF_DIR/$DIFF_DIR_ESCAPED/" \
        -e "s/\\\$DIFFOSCOPE_REPORTS_TEMPLATE/$DIFFOSCOPE_REPORTS_TEMPLATE_ESCAPED/" \
        -e "s/\\\$CHANGE_VIS_REPORTS_TEMPLATE/$CHANGE_VIS_REPORTS_TEMPLATE_ESCAPED/" \
        -e "s/\\\$SOAP_VERSION/$SOAP_VERSION/" \
        -e "s/\\\$DATETIME/$DATETIME/" \
        "$SUMMARY_REPORT"
}

main "$@"
