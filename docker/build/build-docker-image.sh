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

set -o errexit -o nounset -o pipefail -o xtrace

# Guard against usage with root
if [[ "$EUID" -eq 0 ]]; then
    echo "Execute build script with regular user, container is built and run via non-root user!"
    exit 1
fi

cp "$HOME/.gitconfig" "gitconfig"

docker build \
    --build-arg userid=$(id -u) \
    --build-arg groupid=$(id -g) \
    --build-arg username=$(id -un) \
    --file=docker/build/Dockerfile \
    --tag "mobilesec/rb-aosp-build:latest" \
    --no-cache=true \
    .

rm "gitconfig"
