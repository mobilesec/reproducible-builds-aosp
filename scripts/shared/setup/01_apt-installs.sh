#!/bin/bash
set -o errexit -o nounset -o xtrace

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
    sudo apt-get --assume-yes install curl jq bindfs wget diffstat

    # Install temporarily to pull in all runtime dependencies
    #sudo apt-get --assume-yes install diffoscope
    #sudo apt-get --assume-yes remove diffoscope
    # Required to install more current version of diffoscope via pip
    sudo apt-get --assume-yes install python3-pip
}

main "$@"
