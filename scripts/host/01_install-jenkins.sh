#!/bin/bash

# Based on https://linuxize.com/post/how-to-install-jenkins-on-ubuntu-18-04/

sudo apt update
sudo apt install openjdk-8-jdk

wget -q -O - https://pkg.jenkins.io/debian/jenkins.io.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'

sudo apt update
sudo apt install jenkins

# Enable access via port 8080
sudo ufw allow 8080

# Grant jenkins user the dev user group
# usermod -a -G dev jenkins

# Change Jenkins server to run via dev user
sudo sed -E -i -e 's/JENKINS_USER=\$NAME/JENKINS_USER=dev/' -e 's/JENKINS_GROUP=\$NAME/JENKINS_GROUP=dev/' "/etc/default/jenkins"

sudo chown -R dev:dev "/var/lib/jenkins"
sudo chown -R dev:dev "/var/cache/jenkins"
sudo chown -R dev:dev "/var/log/jenkins"
