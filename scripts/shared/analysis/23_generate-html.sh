#!/bin/bash
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

    # Navigate to diff dir
    cd "$DIFF_DIR"

    # Generate diffoscope reports template string
    local -ar DIFFOSCOPE_REPORTS=($(find . -path '*.diff.html-dir/index.html'))
    local DIFFOSCOPE_REPORTS_TEMPLATE=""
    for DIFFOSCOPE_REPORT in "${DIFFOSCOPE_REPORTS[@]}"; do
        DIFFOSCOPE_REPORTS_TEMPLATE+="<a href=\"${DIFFOSCOPE_REPORT}\">${DIFFOSCOPE_REPORT}</a><br>"
    done

    # Generate Change visualisation reports + template string
    local -ar CHANGE_VIS_CSV_FILES=($(find . -path '*.diff.json.csv'))
    local CHANGE_VIS_REPORTS_TEMPLATE=""
    for CHANGE_VIS_CSV_FILE in "${CHANGE_VIS_CSV_FILES[@]}"; do
        local CHANGE_VIS_REPORT="$(basename --suffix '.diff.json.csv' "$CHANGE_VIS_CSV_FILE").change-vis.html"
        cp "$TEMPLATE_CHANGE_VIS" "$CHANGE_VIS_REPORT"
        # Make safe for sed replace, see https://stackoverflow.com/a/2705678
        local CHANGE_VIS_CSV_FILE_ESCAPED=$(printf '%s\n' "$CHANGE_VIS_CSV_FILE" | sed -e 's/[\/&]/\\&/g')
        sed -E -i -e "s/\\\$CHANGE_VIS_CSV_FILE/$CHANGE_VIS_CSV_FILE_ESCAPED/" "$CHANGE_VIS_REPORT"
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
        "$SUMMARY_REPORT"
}

main "$@"
