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

set -o errexit -o nounset -o xtrace

main() {
    # Essentially just follow the instructions from https://source.android.com/setup/build/downloading
    mkdir -p "${HOME}/bin"
    export PATH="${HOME}/bin:${PATH}" # Fix PATH immediatly, avoids requirement for new login

    curl "https://storage.googleapis.com/git-repo-downloads/repo" > "${HOME}/bin/repo"
    chmod a+x "${HOME}/bin/repo"
}

main "$@"
