#!/bin/bash

sudo apt update

# unchanged deps from https://source.android.com/setup/build/initializing for Ubuntu 14.04
sudo apt install gnupg flex bison gperf build-essential zip curl zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386  x11proto-core-dev libx11-dev  libgl1-mesa-dev libxml2-utils xsltproc unzip \
# renamed packages since Ubuntu 14.04:
#   'git-core' -> 'git'
#   'lib32ncurses5-dev' -> 'libncurses5-dev',
#   'lib32z-dev' -> 'lib32z1-dev'
sudo apt install git libncurses5-dev lib32z1-dev
# Additional dependencies uncovered during build
sudo apt install rsync libfontconfig1
# python2.7 required for repo, not installed in Ubuntu 18.04
sudo apt install python

# Required for reproducible build scripts
sudo apt install curl jq
