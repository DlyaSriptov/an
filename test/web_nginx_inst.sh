#!/bin/bash

# 2.1. Проверяем, установлен ли веб-сервер Nginx
#      Если нет - удаляем возможные остатки программы, и устанавливаем с нуля
nginxCheckInstall=$(locate --basename '\nginx')

checkVarNginxCheck=`cat <<_EOF_
/etc/nginx
/etc/default/nginx
/etc/init.d/nginx
/etc/logrotate.d/nginx
/etc/ufw/applications.d/nginx
/usr/lib/nginx
/usr/sbin/nginx
/usr/share/nginx
/usr/share/doc/nginx
/var/lib/nginx
/var/log/nginx
_EOF_
`
if [[ ! $nginxCheckInstall = $checkVarNginxCheck ]]
then
    systemctl stop nginx
    systemctl disable nginx
    apt-get -y -q purge nginx nginx-common
    apt-get -y -q autoremove
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
fi
