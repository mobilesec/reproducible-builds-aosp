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

    # Install more current version via pip
    pip3 install diffoscope

    # diffoscope has a feature to list missing deps, use this to install any deps we may have missed previously
    sudo apt-get --assume-yes install $(diffoscope --list-missing-tools debian | grep 'Available-in-Debian-packages' | cut -d: -f2 | sed 's/,//g')
    #pip3 install $(diffoscope --list-missing-tools debian | grep 'Missing-Python-Modules' | cut -d: -f2 | sed 's/,//g')
    # The above command installs the rpm package via pip, but running diffoscope emits the following warning:
    # UserWarning: The RPM Python bindings are not currently available via PyPI.
}

main() {
    # We want these scripts to work with a wide range of Debian based systems, thus all commands requiring elevated
    # privileges utilize sudo (to support Ubuntu based build system), event though it is a pointless noop in some
    # environments, like a Docker container running Debian.
    set +o errexit # Disable early exit
    command -v sudo
    if [ "$?" -ne 0 ]; then
        apt-get update

        apt-get --assume-yes install sudo
    fi
    set -o errexit # Re-enable early exit

    sudo apt-get update

    # unchanged deps from https://source.android.com/setup/build/initializing for Ubuntu 14.04
    sudo apt-get --assume-yes install gnupg flex bison gperf build-essential zip curl zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386  x11proto-core-dev libx11-dev  libgl1-mesa-dev libxml2-utils xsltproc unzip \
    # renamed packages since Ubuntu 14.04:
    #   'git-core' -> 'git'
    #   'lib32ncurses5-dev' -> 'libncurses5-dev',
    #   'lib32z-dev' -> 'lib32z1-dev'
    sudo apt-get --assume-yes install git libncurses5 libncurses5-dev lib32z1-dev
    # Additional dependencies uncovered during build
    sudo apt-get --assume-yes install rsync libfontconfig1
    # python2.7 required for repo, not installed in Ubuntu 18.04
    sudo apt-get --assume-yes install python

    # Required for reproducible build scripts
    sudo apt-get --assume-yes install curl jq wget diffstat libguestfs-tools
    installDiffoscope
}

main "$@"
