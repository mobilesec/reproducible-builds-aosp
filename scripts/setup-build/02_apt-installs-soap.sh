#!/bin/sh

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
    # Ensure package installations does not prompt the user
    export DEBIAN_FRONTEND="noninteractive"
    sudo sed --in-place 's/env_reset/env_keep += "DEBIAN_FRONTEND"/g' "/etc/sudoers"
    # Required for reproducible build scripts
    sudo apt-get --assume-yes install curl jq wget libguestfs-tools

    # Update guestfs appliance, needed for Ubuntu 14.04
    if command -v "update-guestfs-appliance" ; then
        sudo update-guestfs-appliance
    fi
}

main "$@"
