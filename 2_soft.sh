#!/bin/bash

apt-get -y -q install openssh-server
apt-get -y -q install ufw
apt-get -y -q install curl
apt-get -y -q install debconf-utils
apt-get -y -q install apt-transport-https
apt-get -y -q install software-properties-common
apt-get -y -q install mlocate
apt-get -y -q install unzip
apt-get -y -q install mc
apt-get -y -q install gnupg2
apt-get -y -q install lua5.2
apt-get -y -q install socat
apt-get -y -q install certbot
apt-get -y -q install python3-certbot-nginx

