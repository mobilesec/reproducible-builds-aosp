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

# Adopted from the docker image found in the AOSP tools, i.e. https://android.googlesource.com/platform/build/+/master/tools/docker/Dockerfile
FROM ubuntu:14.04
ARG userid
ARG groupid
ARG username

COPY "./scripts" "/scripts"
RUN apt-get update \
    && apt-get install -y git-core gnupg flex bison gperf build-essential zip curl zlib1g-dev gcc-multilib g++-multilib libc6-dev-i386 lib32ncurses5-dev x11proto-core-dev libx11-dev lib32z-dev ccache libgl1-mesa-dev libxml2-utils xsltproc unzip python openjdk-7-jdk
RUN curl -o jdk8.tgz https://android.googlesource.com/platform/prebuilts/jdk/jdk8/+archive/master.tar.gz \
    && tar -zxf jdk8.tgz linux-x86 \
    && mv linux-x86 /usr/lib/jvm/java-8-openjdk-amd64 \
    && rm -rf jdk8.tgz
RUN apt-get update \
    && sh "./scripts/setup-build/02_apt-installs-soap.sh" \
    && rm -rf "/var/lib/apt/lists/*"

# Run the same installation steps for repo as in official Dockerfile, but with legacy version repo 1
# that should run on Ubuntu 14.04, see https://source.android.com/setup/develop#old-repo-python2
RUN curl -o /usr/local/bin/repo https://storage.googleapis.com/git-repo-downloads/repo-1 \
    && echo "b5caa4be6496419057c5e1b1cdff1e4bdd3c1845eec87bd89ecb2e463a3ee62c  /usr/local/bin/repo" | sha256sum --strict -c - \
    && chmod a+x /usr/local/bin/repo

RUN groupadd --gid $groupid $username \
    && useradd --create-home --uid $userid --gid $groupid $username \
    && echo $username > /root/docker-runtime-username \
    && sudo -u $username mkdir /home/$username/aosp
COPY gitconfig /home/$username/.gitconfig
#RUN chown $userid:$groupid /home/$username/.gitconfig
ENV HOME=/home/$username
ENV USER=$username

CMD /bin/bash -l
