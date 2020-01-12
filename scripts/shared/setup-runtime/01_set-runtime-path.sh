#!/bin/bash
set -ex

# Should be loaded by any sensible .profile with the next login shell anyway,
# but this enables us to continue operating in the same shell instance
export PATH="${HOME}/.local/bin:${PATH}"
export PATH="${HOME}/bin:${PATH}"
