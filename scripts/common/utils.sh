getLatestCIBuildNumber() {
    local -r BUILD_TARGET="$1"

    local -r BUILD_NUMBER="$(curl "https://ci.android.com/builds/branches/aosp-master/status.json" \
        | jq -r ".targets[] | select(.name | contains(\"${BUILD_TARGET}\")) | .last_known_good_build" \
    )"

    echo "$BUILD_NUMBER"
}
