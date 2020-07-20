#!/bin/bash
set -o errexit -o nounset -o pipefail -o xtrace

docker build \
    --target builder \
    --tag "mpoell/rb-aosp:latest" \
    --no-cache=true \
    .
