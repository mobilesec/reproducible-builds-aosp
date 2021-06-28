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

FROM android-build-trusty
ARG username

COPY "./scripts" "/scripts"
# Run the same installation steps for repo as in official Dockerfile, but with legacy version repo 1
# that should run on Ubuntu 14.04, see https://source.android.com/setup/develop#old-repo-python2
RUN curl -o /usr/local/bin/repo https://storage.googleapis.com/git-repo-downloads/repo-1 \
    && echo "b5caa4be6496419057c5e1b1cdff1e4bdd3c1845eec87bd89ecb2e463a3ee62c  /usr/local/bin/repo" | sha256sum --strict -c - \
    && chmod a+x /usr/local/bin/repo
RUN apt-get update \
    && sh "./scripts/shared/setup-build/02_apt-installs-soap.sh" \
    && rm -rf "/var/lib/apt/lists/*"
RUN sudo -u $username mkdir /home/$username/aosp

CMD /bin/bash -l
