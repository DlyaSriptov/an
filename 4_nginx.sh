#!/bin/bash

systemctl stop nginx
systemctl disable nginx
apt-get -y -q purge nginx nginx-common
# apt-get -y -q autoremove
rm -rf /etc/nginx
rm -rf /etc/default/nginx
rm -rf /etc/init.d/nginx
rm -rf /etc/logrotate.d/nginx
rm -rf /etc/ufw/applications.d/nginx
rm -rf /usr/lib/nginx
rm -rf /usr/sbin/nginx
rm -rf /usr/share/nginx
rm -rf /usr/share/doc/nginx
rm -rf /var/lib/nginx
rm -rf /var/log/nginx
    
apt-get -y -q install nginx
systemctl enable nginx


echo -n "Cтатус работы веб-сервера Nginx будет показан через: "
for ((i=5; i > 0; i--))
do
    sleep 1
    echo -n  "$i "
done
systemctl status nginx
