#!/bin/bash

apt-get update

# unchanged deps from https://source.android.com/setup/build/initializing for Ubuntu 14.04
apt-get --assume-yes install gnupg flex bison gperf build-essential zip curl zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386  x11proto-core-dev libx11-dev  libgl1-mesa-dev libxml2-utils xsltproc unzip \
# renamed packages since Ubuntu 14.04:
#   'git-core' -> 'git'
#   'lib32ncurses5-dev' -> 'libncurses5-dev',
#   'lib32z-dev' -> 'lib32z1-dev'
apt-get --assume-yes install git libncurses5 libncurses5-dev lib32z1-dev
# Additional dependencies uncovered during build
apt-get --assume-yes install rsync libfontconfig1
# python2.7 required for repo, not installed in Ubuntu 18.04
apt-get --assume-yes install python

# Required for reproducible build scripts
apt-get --assume-yes install curl jq bindfs

# Install temporarily to pull in all runtime dependencies
apt-get --assume-yes install diffoscope
apt-get --assume-yes remove diffoscope
# Required to install more current version of diffoscope
apt-get --assume-yes install python3-pip
