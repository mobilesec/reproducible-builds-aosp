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

installDiffoscope() {
    # Required to install more current version of diffoscope via pip
    sudo apt-get --assume-yes install python3-pip

    # Install temporarily to pull in all runtime dependencies
    sudo apt-get --assume-yes install diffoscope
    sudo apt-get --assume-yes remove diffoscope

    # Install more current version via pip, pinned to 151 to ensure consistent behavior
    sudo pip3 install diffoscope==151
    # root user causes installation in /usr/local/bin instead of $HOME/.local/bin

    # diffoscope has a feature to list missing deps, use this to install any deps we may have missed previously
    #APT_DEPS_BY_DIFFOSCOPE_FILE="$( mktemp /tmp/apt-deps-by-diffoscope.XXXXXX )"
    #diffoscope --list-missing-tools debian | grep 'Available-in-Debian-packages' | cut -d: -f2 | sed 's/,//g' > "$APT_DEPS_BY_DIFFOSCOPE_FILE"
    #sudo apt-get --assume-yes install $( cat "$APT_DEPS_BY_DIFFOSCOPE_FILE" )
    #rm "$APT_DEPS_BY_DIFFOSCOPE_FILE"
    # The listed packages only work for a recent version of Debian, not Ubuntu (which is the official AOSP recommendation)
    # thus we replace the automated list with the following manual selection that works on Ubuntu 18.04
    sudo apt-get --assume-yes install apksigner ffmpeg hdf5-tools liblz4-tool ocaml-nox xmlbeans zstd

    #pip3 install $(diffoscope --list-missing-tools debian | grep 'Missing-Python-Modules' | cut -d: -f2 | sed 's/,//g')
    # The above command installs the python rpm package via pip, but running diffoscope emits the following warning:
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

    # Ensure package installations does not prompt the user
    export DEBIAN_FRONTEND="noninteractive"
    sudo sed --in-place 's/env_reset/env_keep += "DEBIAN_FRONTEND"/g' "/etc/sudoers"
    # Required for reproducible build scripts
    sudo apt-get --assume-yes install curl jq wget diffstat libguestfs-tools bc python
    # Update guestfs appliance, needed for Ubuntu 14.04
    if command -v "update-guestfs-appliance" ; then
        sudo update-guestfs-appliance
    fi

    installDiffoscope

    # Install x86 32-bit runtime support, host utilities for older AOSP version need these
    sudo dpkg --add-architecture i386
    sudo apt-get update
    sudo apt-get --assume-yes install libc6:i386 lib32stdc++6
}

main "$@"
