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
        echo "Usage: $0 <DIFFS_DIR>"
        echo "DIFFS_DIR: Outer diff directory with all each analysis as subfolder"
        exit 1
    fi
    local -r DIFFS_DIR="$1"
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
    local -r TEMPLATE_REPORT_OVERVIEW="${SCRIPT_BASE}html-template/report-overview.html"

    # Navigate to diffs dir
    cd "$DIFFS_DIR"

    # Generate SOAP reports template string
    local -ar SOAP_REPORTS=($(find . -path '*__*/summary.html' | sort))
    local SOAP_REPORTS_TEMPLATE=""
    for SOAP_REPORT in "${SOAP_REPORTS[@]}"; do
        SOAP_REPORTS_TEMPLATE+="<a href=\"${SOAP_REPORT}\">${SOAP_REPORT}</a><br>"
    done

    # Generate overview report
    local -r OVERVIEW_REPORT="./report-overview.html"
    cp "$TEMPLATE_REPORT_OVERVIEW" "$OVERVIEW_REPORT"
    # Make safe for sed replace, see https://stackoverflow.com/a/2705678
    local -r SOAP_REPORTS_TEMPLATE_ESCAPED=$(printf '%s\n' "$SOAP_REPORTS_TEMPLATE" | sed -e 's/[\/&]/\\&/g')
    sed -E -i -e "s/\\\$SOAP_REPORTS_TEMPLATE/$SOAP_REPORTS_TEMPLATE_ESCAPED/" "$OVERVIEW_REPORT"
}

main "$@"
