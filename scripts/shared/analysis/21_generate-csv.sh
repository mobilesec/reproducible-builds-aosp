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

    local -ar DIFF_JSON_FILES=($(find -type f -name '*.json' | sort))
    for DIFF_JSON_FILE in "${DIFF_JSON_FILES[@]}"; do
        # jq filters have a strong write-once smell if you never worked with them before. Thus a small breakdown
        # of the steps involved for this one:
        # - We iterate over all paths in JSON object that lead to a unified diff that is actually present
        #   (i.e. type of property is string). We start with an empty object and add properties for each such path.
        # - Specifically we add 3 properties ("source1", "source2" and "unified_diff" in exactly that order)
        #   - For both "source" propertiers we generate a unique key based on the *keys* of the path
        #     leading to said source by combining these with a ".". For the value we want to concat all
        #     source property values that lie on this path. Note that such a concatination is only a real path
        #     in some instances, more often than not the last "source" value on this path is the tool invocation
        #     on a specific file. Thus we join with "::". Finally we prepend diff markers (e.g. "--- ") to allow automatic processing.
        #     - For each $path we need all prefix arrays that lead to the respective "source" properties.
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
        #   - The last property for each 3 tuple is the unified diff, which we simply retrieve via getpath
        # - Finally we join all values with newlines, resultung in a clean set of diffs (i.e. patch without metadata like author, etc.)
        jq -r '
    . as $in
    | reduce (
    leaf_paths | select((. | last) == "unified_diff" and (. | last | type) == "string")
        ) as $path ({}; .
        + { ($path | .[($path | length - 1)] = "source1" | map(tostring) | join(".")) : ( "--- " + ( [ $in | getpath(
        $path[0:range(0; ($path | length) + 1)] | select((. | last) | type == "number") | . += ["source1"]
        ) ] | join("::") ) ) }
        + { ($path | .[($path | length - 1)] = "source2" | map(tostring) | join(".")) : ( "+++ " + ( [ $in | getpath(
        $path[0:range(0; ($path | length) + 1)] | select((. | last) | type == "number") | . += ["source2"]
        ) ] | join("::") ) ) }
        + { ($path | map(tostring) | join(".")): $in | getpath($path) }
    ) | join("\n")
    ' <(cat "${DIFF_JSON_FILE}") > "${DIFF_JSON_FILE}.flattened.diff"

        # More recent version of diffoscope (changed somewhere between 137 and 151) emit for nearly every node
        # the full path (instead of just a single elemnt). This requires some post processing to clean up, specifically:
        # - Remove redundant paths (the second sed substitution greedily consumes nodes untill the last)
        # - Convert paths on host to absolute path in image (grouping after \.img(\.raw)?\.mount\/ capture path in image) , e.g.
        #   /root/aosp/build/.../system.img.raw.mount/system/priv-app/VpnDialogs/VpnDialogs.apk::zipinfo -> system/priv-app/VpnDialogs/VpnDialogs.apk::zipinfo
        # - Since diffstat can't handle spaces (escaping doesn't help either), convert all spaces (from tool invocations) to ␣
        # - Finally, reassemble valid patch file markers by preprending '--- a/' and '+++ b/' (fourth substition)
        sed -E -e '/^--- /{s/^--- //g;s/^.*\.img(\.raw)?\.mount\/(.*)$/\2/g;s/\s/␣/g;s/^/--- a\//g}' \
            -e '/^\+\+\+ /{s/^\+\+\+ //g;s/^.*\.img(\.raw)?\.mount\/(.*)$/\2/g;s/\s/␣/g;s/^/+++ b\//g}' \
            "${DIFF_JSON_FILE}.flattened.diff" > "${DIFF_JSON_FILE}.flattened_clean.diff"

        # Run diffstat on cleaned flat diff file, create machine friendly CSV output, transform ␣ back into real spaces
        diffstat -p 1 -k -t "${DIFF_JSON_FILE}.flattened_clean.diff" \
            | sed -e 's/␣/ /g' > "${DIFF_JSON_FILE}.csv"

        # All diff file versions take considerable space, get rid of them
        rm "${DIFF_JSON_FILE}"
        rm "${DIFF_JSON_FILE}.flattened.diff"
        rm "${DIFF_JSON_FILE}.flattened_clean.diff"

    done
}

main "$@"
