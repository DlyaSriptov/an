#!/bin/bash

systemctl start sshd

ufw default deny incoming
ufw default allow outgoing
ufw allow OpenSSH
ufw allow ssh
ufw allow 22
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 10000/udp
ufw allow 5349/tcp

ufw allow 8080/tcp
ufw allow 8443/tcp
ufw allow 3478
ufw allow 40000:57000/tcp
ufw allow 40000:57000/udp
ufw allow 57001:65535/tcp
ufw allow 57001:65535/udp
ufw allow 1433
ufw allow from 127.0.0.1 to any port 1433
# ufw allow from <Статический Внешний IP> to any
# ufw delete allow 1433
ufw enable
ufw status numbered

iptables -I INPUT -p tcp --match multiport --dports 80,443 -j ACCEPT
iptables -I INPUT -p udp --dport 10000 -j ACCEPT
iptables -I INPUT -p tcp --dport 5349 -j ACCEPT

iptables -I INPUT -p tcp --dport 8080 -j ACCEPT
iptables -I INPUT -p tcp --dport 8443 -j ACCEPT
iptables -I INPUT -p tcp --dport 3478 -j ACCEPT
iptables -I INPUT -p tcp --dport 40000:57000 -j ACCEPT
iptables -I INPUT -p tcp --dport 57001:65535 -j ACCEPT
iptables -I INPUT -p udp --dport 57001:65535 -j ACCEPT
iptables -I INPUT -p tcp --dport 1433 -j ACCEPT

DEBIAN_FRONTEND=noninteractive apt-get  -y -q install iptables-persistent
netfilter-persistent save


