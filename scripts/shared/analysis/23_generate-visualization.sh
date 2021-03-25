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

generateVisualization() {
    local -r CSV_INPUT_FILE="$1"

    VISUALIZATION_REPORT_FILE="$(basename --suffix '.csv' "$CSV_INPUT_FILE").visualization.html"
    cp "$TEMPLATE_VISUALIZATION" "$VISUALIZATION_REPORT_FILE"
    # Make safe for sed replace, see https://stackoverflow.com/a/2705678
    CSV_INPUT_FILE_ESCAPED=$(printf '%s\n' "$CSV_INPUT_FILE" | sed -e 's/[\/&]/\\&/g')
    sed -E -i -e "s/\\\$CSV_INPUT_FILE/$CSV_INPUT_FILE_ESCAPED/" \
        -e "s/\\\$SOAP_VERSION/$SOAP_VERSION/" \
        -e "s/\\\$DATETIME/$DATETIME/" \
        "$VISUALIZATION_REPORT_FILE"
    ARTIFACT_REPORTS_TEMPLATE+="(<a href=\"${VISUALIZATION_REPORT_FILE}\">Hierarchical visualization report</a>)"
}

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
    local -r TEMPLATE_VISUALIZATION="${SCRIPT_BASE}html-template/visualization.html"
    local -r TEMPLATE_SUMMARY="${SCRIPT_BASE}html-template/summary.html"
    local -r SOAP_VERSION_FILE="${SCRIPT_BASE}.version"
    # Report Info
    local -r SOAP_VERSION=$(cat "$SOAP_VERSION_FILE")
    local -r DATETIME=$(date -u)

    # Navigate to diff dir
    cd "$DIFF_DIR"

    # Iterate artifacts, use diffoscope HTML reports as starting point
    local -a DIFFOSCOPE_HTML_REPORTS
    mapfile -t DIFFOSCOPE_HTML_REPORTS < <(find . -path '*.diffoscope.html-dir/index.html' | sort)
    declare -r DIFFOSCOPE_HTML_REPORTS
    local ARTIFACT_REPORTS_TEMPLATE=$'<ul>'
    for DIFFOSCOPE_HTML_REPORT in "${DIFFOSCOPE_HTML_REPORTS[@]}"; do
        local BASE_FILENAME 
        BASE_FILENAME="$(dirname "$(dirname "${DIFFOSCOPE_HTML_REPORT}")")/$(basename -s '.diffoscope.html-dir' "$(dirname "${DIFFOSCOPE_HTML_REPORT}")")"
        if [[ "$BASE_FILENAME" == *"-apex_payload.img" ]]; then
            BASE_FILENAME="$(dirname "${BASE_FILENAME}")/$(basename -s '-apex_payload.img' "${BASE_FILENAME}")"
        fi

        # Start artifact HTML template code
        ARTIFACT_REPORTS_TEMPLATE+="<li>${BASE_FILENAME}"
        local DS_CONTENT
        DS_CONTENT="$(tail --lines=+2 "${BASE_FILENAME}.metric.diff-score.csv")"
        if [[ "$DS_CONTENT" == ",0" ]] || [[ "$DS_CONTENT" == $',0\n,0' ]]; then
            ARTIFACT_REPORTS_TEMPLATE+=" (No Changes)"
        fi
        ARTIFACT_REPORTS_TEMPLATE+="<ul>"

        # Fix jQuery location from local to a CDN, specifically
        # src="https://code.jquery.com/jquery-3.5.1.min.js" integrity="sha384-ZvpUoO/+PpLXR1lu4jmpXWu80pZlYUAfxl5NsBMWOEPSjUn/6Z/hRTt8+pR6L4N2" crossorigin="anonymous"
        sed -i 's/src="jquery.js"/src="https:\/\/code.jquery.com\/jquery-3.5.1.min.js" integrity="sha384-ZvpUoO\/+PpLXR1lu4jmpXWu80pZlYUAfxl5NsBMWOEPSjUn\/6Z\/hRTt8+pR6L4N2" crossorigin="anonymous"/g' \
            "$DIFFOSCOPE_HTML_REPORT"
        ARTIFACT_REPORTS_TEMPLATE+="<li><a href=\"${DIFFOSCOPE_HTML_REPORT}\">Detailed diffoscope HTML report</a></li>"

        # Generate DS links
        local METRIC_DS_FILE="${BASE_FILENAME}.metric.diff-score.csv"
        local METRIC_MDS_FILE="${BASE_FILENAME}.metric.major-diff-score.csv"
        local DS_VISUALIZATION_GENERATED=false
        if [[ -f "${METRIC_MDS_FILE}" ]]; then
            ARTIFACT_REPORTS_TEMPLATE+="<li><a href=\"${METRIC_MDS_FILE}\">Major Diff-Score (MDS) CSV</a> "
            generateVisualization "$METRIC_MDS_FILE"
            DS_VISUALIZATION_GENERATED=true
            ARTIFACT_REPORTS_TEMPLATE+=$'</li>'
        fi
        if [[ -f "${METRIC_DS_FILE}" ]]; then
            ARTIFACT_REPORTS_TEMPLATE+="<li><a href=\"${METRIC_DS_FILE}\">Diff-Score (DS) CSV</a> "
            if [[ "$DS_VISUALIZATION_GENERATED" == false ]]; then
                generateVisualization "$METRIC_DS_FILE"
            fi
            ARTIFACT_REPORTS_TEMPLATE+=$'</li>'
        fi

        # Generate WS links
        local METRIC_WS_ALL_FILE="${BASE_FILENAME}.metric.weight-score.all.csv"
        local METRIC_WS_CHANGED_FILE="${BASE_FILENAME}.metric.weight-score.changed.csv"
        local METRIC_MWS_CHANGED_FILE="${BASE_FILENAME}.metric.major-weight-score.changed.csv"
        local WS_VISUALIZATION_GENERATED=false
        if [[ -f "${METRIC_MWS_CHANGED_FILE}" ]]; then
            ARTIFACT_REPORTS_TEMPLATE+="<li>Major Weight-Score (MWS) "
            ARTIFACT_REPORTS_TEMPLATE+="(<a href=\"${METRIC_MWS_CHANGED_FILE}\">Changed File Sizes CSV</a> "
            generateVisualization "$METRIC_MWS_CHANGED_FILE"
            WS_VISUALIZATION_GENERATED=true
            ARTIFACT_REPORTS_TEMPLATE+=$')</li>'
        fi
        if [[ -f "${METRIC_WS_ALL_FILE}" ]] && [[ -f "${METRIC_WS_CHANGED_FILE}" ]]; then
            ARTIFACT_REPORTS_TEMPLATE+="<li>Weight-Score (WS) "
            ARTIFACT_REPORTS_TEMPLATE+="(<a href=\"${METRIC_WS_ALL_FILE}\">All File Sizes CSV</a>; "
            ARTIFACT_REPORTS_TEMPLATE+="<a href=\"${METRIC_WS_CHANGED_FILE}\">Changed File Sizes CSV</a> "
            if [[ "$WS_VISUALIZATION_GENERATED" == false ]]; then
                generateVisualization "$METRIC_WS_CHANGED_FILE"
            fi
            ARTIFACT_REPORTS_TEMPLATE+=$')</li>'
        fi

        ARTIFACT_REPORTS_TEMPLATE+=$'</ul></li>'

    done
    ARTIFACT_REPORTS_TEMPLATE+="</ul>"

    # Generate summary report
    local -r SUMMARY_REPORT="./summary.html"
    cp "$TEMPLATE_SUMMARY" "$SUMMARY_REPORT"
    # Make safe for sed replace, see https://stackoverflow.com/a/2705678
    local -r DIFF_DIR_ESCAPED=$(printf '%s\n' "$(basename "$DIFF_DIR")" | sed -e 's/[\/&]/\\&/g')
    local -r ARTIFACT_REPORTS_TEMPLATE_ESCAPED=$(printf '%s\n' "$ARTIFACT_REPORTS_TEMPLATE" | sed -e 's/[\/&]/\\&/g')
    sed -E -i -e "s/\\\$DIFF_DIR/$DIFF_DIR_ESCAPED/" \
        -e "s/\\\$ARTIFACT_REPORTS_TEMPLATE/$ARTIFACT_REPORTS_TEMPLATE_ESCAPED/" \
        -e "s/\\\$SOAP_VERSION/$SOAP_VERSION/" \
        -e "s/\\\$DATETIME/$DATETIME/" \
        "$SUMMARY_REPORT"
}

main "$@"
