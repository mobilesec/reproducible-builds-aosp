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

installDiffoscope() {
    # Required to install more current version of diffoscope via pip
    sudo apt-get --assume-yes install python3-pip

    # Install temporarily to pull in all runtime dependencies
    sudo apt-get --assume-yes install diffoscope
    sudo apt-get --assume-yes remove diffoscope

    # Install more current version via pip, pinned to 151 to ensure consistent behavior
    pip3 install diffoscope==151

    # diffoscope has a feature to list missing deps, use this to install any deps we may have missed previously
    local -a APT_DEPS_BY_DIFFOSCOPE
    read -r -a APT_DEPS_BY_DIFFOSCOPE <<< "$(diffoscope --list-missing-tools debian | grep 'Available-in-Debian-packages' | cut -d: -f2 | sed 's/,//g')"
    declare -r APT_DEPS_BY_DIFFOSCOPE
    sudo apt-get --assume-yes install "${APT_DEPS_BY_DIFFOSCOPE[@]}"
    #pip3 install $(diffoscope --list-missing-tools debian | grep 'Missing-Python-Modules' | cut -d: -f2 | sed 's/,//g')
    # The above command installs the rpm package via pip, but running diffoscope emits the following warning:
    # UserWarning: The RPM Python bindings are not currently available via PyPI.
}

main() {
    # We want these scripts to work with a wide range of Debian based systems, thus all commands requiring elevated
    # privileges utilize sudo (to support Ubuntu based build system), event though it is a pointless noop in some
    # environments, like a Docker container running Debian.
    if ! command -v sudo; then
        apt-get update

        apt-get --assume-yes install sudo
    fi

    sudo apt-get update

    # unchanged deps from https://source.android.com/setup/build/initializing for Ubuntu 18.04
    sudo apt-get --assume-yes install git-core gnupg flex bison build-essential zip curl zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386 lib32ncurses5-dev x11proto-core-dev libx11-dev lib32z1-dev libgl1-mesa-dev libxml2-utils xsltproc unzip fontconfig
    # Even though the latest version of repo is based on Python 3, the `#!/usr/bin/env python` shebang only works on Ubuntu via Python 2,
    # see https://askubuntu.com/questions/1189360/how-to-make-python-shebang-use-python3
    sudo apt-get --assume-yes install python
    # While Ubuntu LTS has rsync preinstalled, Debian does not and AOSP needs it
    sudo apt-get --assume-yes install rsync

    # Required for reproducible build scripts
    sudo apt-get --assume-yes install curl jq wget diffstat libguestfs-tools
    installDiffoscope
}

main "$@"
