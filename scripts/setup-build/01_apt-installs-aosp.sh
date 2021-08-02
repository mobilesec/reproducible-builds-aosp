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
    # While the above works for Ubuntu (tested on LTS 18.04), Debian (tested on 10) requires the following additional dependencies for building AOSP
    sudo apt-get --assume-yes install rsync libncurses5
    # Minimal docker installation of Ubuntu 18.04 has no JDK installed
    sudo apt-get --assume-yes install openjdk-8-jdk
    # Fix issue with JACK that occurs for Android 7 during build, see https://stackoverflow.com/a/67426405
    sudo sed --in-place -e 's/jdk.tls.disabledAlgorithms=SSLv3, TLSv1, TLSv1.1, RC4, DES, MD5withRSA, \\/jdk.tls.disabledAlgorithms=SSLv3, RC4, DES, MD5withRSA, \\/' '/etc/java-8-openjdk/security/java.security'
}

main "$@"
