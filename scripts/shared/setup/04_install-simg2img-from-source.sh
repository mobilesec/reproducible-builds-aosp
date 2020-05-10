#!/bin/bash
set -o errexit -o nounset -o pipefail -o xtrace

main() {
    cd "${HOME}"

    # Clone and build android-simg2img, a utility for decompressing a sparse Android image to a raw partition image
    local -r SIMG2IMG_DIR="android-simg2img"
    git clone "https://github.com/anestisb/android-simg2img" "${SIMG2IMG_DIR}"
    (cd "${SIMG2IMG_DIR}" && make)
    cp "${SIMG2IMG_DIR}/simg2img" "${HOME}/bin"
    rm -rf "${SIMG2IMG_DIR}"
}

main "$@"
