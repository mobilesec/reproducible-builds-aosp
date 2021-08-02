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

FROM ubuntu:20.04
ARG userid
ARG groupid
ARG username

COPY "./scripts" "/scripts"
COPY "./html-template" "/html-template"
COPY "./.version" "/.version"
RUN apt-get update \
    && sh "./scripts/setup-analysis/01_apt-installs.sh" \
    && rm -rf "/var/lib/apt/lists/*"

# user setup, inspired from AOSP Dockerfile (see https://android.googlesource.com/platform/build/+/master/tools/docker/Dockerfile ) 
RUN groupadd --gid $groupid $username \
    && useradd --create-home --uid $userid --gid $groupid $username \
    && echo $username > /root/docker-runtime-username \
    && sudo -u $username mkdir /home/$username/aosp
COPY gitconfig /home/$username/.gitconfig
ENV HOME=/home/$username
ENV USER=$username

CMD /bin/bash -l
