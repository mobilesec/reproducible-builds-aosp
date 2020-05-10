#!/bin/bash
set -o errexit -o nounset -o pipefail -o xtrace

# Essentially just follow the instructions from https://source.android.com/setup/build/downloading
mkdir -p "${HOME}/bin"
export PATH="${HOME}/bin:${PATH}" # Fix PATH immediatly, avoids requirement for new login

curl "https://storage.googleapis.com/git-repo-downloads/repo" > "${HOME}/bin/repo"
chmod a+x "${HOME}/bin/repo"
