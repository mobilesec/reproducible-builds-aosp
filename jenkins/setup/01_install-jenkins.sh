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

main() {
    # Based on https://linuxize.com/post/how-to-install-jenkins-on-ubuntu-18-04/
    sudo apt update
    sudo apt install openjdk-8-jdk

    wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -
    sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'

    sudo apt update
    sudo apt install jenkins

    # Enable access via port 8080
    sudo ufw allow 8080

    # Change Jenkins server to run via dev user
    sudo sed -E -i -e 's/JENKINS_USER=\$NAME/JENKINS_USER=dev/' -e 's/JENKINS_GROUP=\$NAME/JENKINS_GROUP=dev/' "/etc/default/jenkins"

    sudo chown -R dev:dev "/var/lib/jenkins"
    sudo chown -R dev:dev "/var/cache/jenkins"
    sudo chown -R dev:dev "/var/log/jenkins"
}

main "$@"
