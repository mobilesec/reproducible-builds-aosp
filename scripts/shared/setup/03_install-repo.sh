#!/bin/bash

# Essentially just follow the instructions from https://source.android.com/setup/build/downloading
mkdir ~/bin
PATH=~/bin:$PATH # Fix PATH immediatly, avoids requirement for new login

curl "https://storage.googleapis.com/git-repo-downloads/repo" > ~/bin/repo
chmod a+x ~/bin/repo
