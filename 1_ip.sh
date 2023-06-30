#!/bin/bash

netconfIpMask=A
netconfGateway=A
netconfDns=A

# Вводим данные (IP-адрес/Маска, Шдюз, Серверы DNS)
read -p "IP-address/subnet mask: " netconfIpMask
read -p "Gateway: " netconfGateway
read -p "DNS Servers: " netconfDns

# Автоматическая запись введённых данных в файл 01-netcfg.yaml
sed -i -e 's/dhcp4: yes/dhcp4: no/' /etc/netplan/01-netcfg.yaml
sed -i -e "8a\      addresses: [$netconfIpMask]"  /etc/netplan/01-netcfg.yaml
sed -i -e "9a\      gateway4: $netconfGateway"  /etc/netplan/01-netcfg.yaml
sed -i -e "10a\      nameservers:"  /etc/netplan/01-netcfg.yaml
sed -i -e "11a\        addresses: [$netconfDns]"  /etc/netplan/01-netcfg.yaml

# Применяем настройки сети
netplan --debug generate
netplan --debug apply 

