#!/bin/bash
set -o errexit -o nounset -o pipefail -o noglob -o xtrace

cleanupBloatedFilePaths() {
    # More recent version of diffoscope (changed somewhere between 137 and 151) emit for nearly every node
    # the full path (instead of just a single elemnt). This requires some post processing to clean up the diffstat
    # First extract diffstat keys and values
    local -r DIFFSTAT_KEYS=($(head -n -1 "${DIFF_JSON}.diffstat" \
        | sed -E -e 's/^[ \t]*([^ \t]+)[ \t]*\|[ \t]*([0-9]+).*$/\1/'))
    local -r DIFFSTAT_VALUES=($(head -n -1 "${DIFF_JSON}.diffstat" \
        | sed -E -e 's/^[ \t]*([^ \t]+)[ \t]*\|[ \t]*([0-9]+).*$/\2/'))

    local -ar DIFFSTAT_KEYS_PATHS=($(
        for DIFFSTAT_KEY in "${DIFFSTAT_KEYS[@]}"; do
            # Check for at least 1 separator
            if [[ "$DIFFSTAT_KEY" = *"::"* ]]; then
                LEAF_NODE="$(awk --field-separator '::' '{print $NF}' <(echo "$DIFFSTAT_KEY"))"
                # Some leaf nodes contain the full path
                if [[ "$LEAF_NODE" = *"aosp/build"*  ]]; then
                    echo "$LEAF_NODE"
                else
                    # One before last is path, last is tool usage
                    awk --field-separator '::' '{printf("%s::%s\n", $(NF-1), $NF)}' <(echo "$DIFFSTAT_KEY")
                fi
            else
                echo "$DIFFSTAT_KEY"
            fi
        done
    ))

    # Convert paths on host to absolute path in image, e.g.
    # /root/aosp/build/.../system.img.raw.mount/system/priv-app/VpnDialogs/VpnDialogs.apk::zipinfo -> /system/priv-app/VpnDialogs/VpnDialogs.apk::zipinfo
    local -ar DIFFSTAT_KEYS_NEW=($(
        for DIFFSTAT_KEY in "${DIFFSTAT_KEYS_PATHS[@]}"; do
            # node contains path of host filesystem
            if [[ "$DIFFSTAT_KEY" =~ .img(.raw)?.mount/  ]]; then
                awk --field-separator '.mount/' '{printf("/%s\n", $2)}' <(echo "$DIFFSTAT_KEY")
            else
                echo "$DIFFSTAT_KEY"
            fi
        done
    ))

    # Determine longest node path for awk printing
    local -i DIFFSTAT_KEY_MAX_LENGTH=0
    for DIFFSTAT_KEY in "${DIFFSTAT_KEYS_NEW[@]}"; do
        DIFFSTAT_KEY_MAX_LENGTH=$(( ${#DIFFSTAT_KEY} > $DIFFSTAT_KEY_MAX_LENGTH ? ${#DIFFSTAT_KEY} : $DIFFSTAT_KEY_MAX_LENGTH ))
    done

    # Regenerate cleaned diffstat file
    (
        local DIFFSTAT_KEY_NEW=""
        local DIFFSTAT_VALUE=""
        for ((i = 0; i < "${#DIFFSTAT_KEYS_NEW[@]}"; i++)); do
            DIFFSTAT_KEY_NEW="${DIFFSTAT_KEYS_NEW[$i]}"
            DIFFSTAT_VALUE="${DIFFSTAT_VALUES[$i]}"

            awk "$(echo "{printf(\" %-${DIFFSTAT_KEY_MAX_LENGTH}s | %10s\n\", \$1, \$2)}")" <(echo "$DIFFSTAT_KEY_NEW" "$DIFFSTAT_VALUE")
        done
        tail -n 1 "${DIFF_JSON}.diffstat"
    ) > "${DIFF_JSON}.diffstat_clean"
}

generateCsvFile() {
    # Convert diffstat to CSV for further processing
    head -n -1 "${DIFF_JSON}.diffstat_clean" \
        | sed -E -e "s/^[ \t]*([^ \t]+)[ \t]*\|[ \t]*([0-9]+).*$/\1,\2/" \
        > "${DIFF_JSON}.diffstat.csv"
}

main() {
    # Argument sanity check
    if [[ "$#" -ne 1 ]]; then
        echo "Usage: $0 <DIFF_DIR>"
        echo "DIFF_DIR: Output directory diffoscope output"
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

    for DIFF_JSON in *.json; do
        # jq filters have a strong write-once smell if you never worked with them before. Thus a small breakdown
        # of the steps involved for this one:
        # * We iterate over all paths in JSON object that lead to a unified diff that is actually present
        #   (i.e. type of property is string). We start with an empty object and add properties for each such path.
        # * Specifically we add 3 properties ("source1", "source2" and "unified_diff" in exactly that order)
        #   * For both "source" propertiers we generate a unique key based on the *keys* of the path
        #     leading to said source by combining these with a ".". For the value we want to concat all
        #     source property values that lie on this path. Note that such a concatination is only a real path
        #     in some instances, more often than not the last "source" value on this path is the tool invocation
        #     on a specific file. Thus we join with "::". Finally we prepend diff markers (e.g. "--- ") to allow automatic processing.
        #     * For each $path we need all prefix arrays that lead to the respective "source" properties.
        #       Note that all (except the last) "source" property doesn't exist on the path directly. Rather for
        #       each intermediate step, after indexing the element in the "details" array, we need to manually append
        #       the respective source property. For example, for the path
        #
        #         details.4.details.2.source1
        #
        #       we need to access the following paths (we leave "source1" out since it's a shared prefix) and concat them
        #
        #         details.4.source1
        #         details.4.details.2.source1
        #
        #      Finally we retrieve the values for all these paths via getpath and concat via join.
        #   * The last property for each 3 tuple is the unified diff, which we simply retrieve via getpath
        # * Finally we join all values with newlines, resultung in a clean set of diffs (i.e. patch without metadata like author, etc.)
        jq -r '
    . as $in
    | reduce (
    leaf_paths | select((. | last) == "unified_diff" and (. | last | type) == "string")
        ) as $path ({}; .
        + { ($path | .[($path | length - 1)] = "source1" | map(tostring) | join(".")) : ( "--- " + ( [ $in | getpath(
        $path[0:range(0; ($path | length) + 1)] | select((. | last) | type == "number") | . += ["source1"]
        ) ] | join("__") ) ) }
        + { ($path | .[($path | length - 1)] = "source2" | map(tostring) | join(".")) : ( "+++ " + ( [ $in | getpath(
        $path[0:range(0; ($path | length) + 1)] | select((. | last) | type == "number") | . += ["source2"]
        ) ] | join("::") ) ) }
        + { ($path | map(tostring) | join(".")): $in | getpath($path) }
    ) | join("\n")
    ' <(cat "${DIFF_JSON}") | \
        diffstat > "${DIFF_JSON}.diffstat"

        cleanupBloatedFilePaths
        generateCsvFile

        # JSON files take considerable space, get rid of them
        rm "${DIFF_JSON}"

    done
}

main "$@"
