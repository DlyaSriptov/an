#!/bin/bash

domainNameForJitsi=A
jitsiLoginOrganizer=A
jitsiPasswordOrganizer=A

pwdScan=$(pwd)

read -p "Введите имя домена для Jitsi: " domainNameForJitsi
read -p "Введите логин организатора конференции: " jitsiLoginOrganizer
read -p "Введите пароль организатора конференции: " jitsiPasswordOrganizer

# 1. Удаляем остатки Jitsi (если есть)
apt-get -y -q purge jigasi prosody jitsi-meet jitsi-meet-web-config jitsi-meet-prosody jitsi-meet-turnserver jitsi-meet-web jicofo jitsi-videobridge2 jitsi-videobridge
# apt-get -y -q autoremove

rm -rf /etc/prosody
rm -rf /var/lib/prosody
rm -f /etc/apt/sources.list.d/jitsi-stable.list
rm -f /usr/share/keyrings/jitsi-keyring.gpg
sed -i -e "s|deb http://packages.prosody.im/debian focal main||" /etc/apt/sources.list

# 2. Имя компьютера сопоставляем с доменным именем
hostnamectl set-hostname $domainNameForJitsi

# 3. Добавляем репозиторий и ключ для Prosody
echo deb http://packages.prosody.im/debian $(lsb_release -sc) main | sudo tee -a /etc/apt/sources.list
wget https://prosody.im/files/prosody-debian-packages.key -O- | sudo apt-key add -

# 4. Добавляем ключ и репозиторий для Jitsi Meet
curl https://download.jitsi.org/jitsi-key.gpg.key | sudo sh -c 'gpg --dearmor > /usr/share/keyrings/jitsi-keyring.gpg'
echo 'deb [signed-by=/usr/share/keyrings/jitsi-keyring.gpg] https://download.jitsi.org stable/' | sudo tee /etc/apt/sources.list.d/jitsi-stable.list > /dev/null
apt update

# 5. Блокируем псевдографические диалоги
#    Вместо них в опросник подставляем имя домена, остальные вопросы игнорируются вообще
echo "jitsi-videobridge jitsi-videobridge/jvb-hostname string $domainNameForJitsi" | debconf-set-selections
export DEBIAN_FRONTEND=noninteractive

# 6. Устанавливаем jitsi-meet
apt-get -y -q install jitsi-meet

# Команды для автоматического ввода электронной почты в файл install-letsencrypt-cert.sh, но они ещё не доработаны
#sed -i -e 's/EMAIL=$1/EMAIL=$jitsiEmail/' /usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh
#sed -i -e 's/You need to agree to the ACME server\'s Subscriber Agreement (https:\/\/letsencrypt.org\/documents\/LE-SA-v1.1.1-August-1-2016.pdf) /Ваш E-Mail:/' /usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh
#sed -i -e 's/"by providing an email address for important account notifications"/$EMAIL/' /usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh
#sed -i -e 's/echo -n "Enter your email and press [ENTER]: "/#echo -n "Enter your email and press [ENTER]: "/' /usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh
#sed -i -e 's/read EMAIL/#read EMAIL/' /usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh

# 7. Запускаем скрипт создания сертификата
/usr/share/jitsi-meet/scripts/install-letsencrypt-cert.sh

# 8. Устанавливаем необходимые библитеки для настройки аутентификации пользователя
apt-get -y -q install liblua5.1-0-dev liblua5.2-dev liblua50-dev
apt-get -y install libunbound-dev
luarocks install luaunbound
chmod a+x /etc/jitsi/jicofo/

# 9. Нстраиваем аутентификацию пользователя
# 9.1. В файле /etc/prosody/conf.avail/<ДОМЕНННОЕ_ИМЯ>.cfg.lua 
cd /etc/prosody/conf.avail/

sed -i -e 's/authentication = "jitsi-anonymous" -- do not delete me/authentication = "internal_hashed" -- do not delete me/' $domainNameForJitsi.cfg.lua
echo 'VirtualHost "guest.'$domainNameForJitsi'"' >> $domainNameForJitsi.cfg.lua
echo '    authentication = "anonymous"' >> $domainNameForJitsi.cfg.lua
echo '    c2s_require_encryption = false' >> $domainNameForJitsi.cfg.lua

# 9.2. В файле /etc/jitsi/meet/<ДОМЕНННОЕ_ИМЯ>-config.js
cd /etc/jitsi/meet/

sed -i -e "s/domain: '$domainNameForJitsi',/domain: '$domainNameForJitsi',anonymousdomain: 'guest.$domainNameForJitsi',/" $domainNameForJitsi-config.js

cd $pwdScan

# 9.3. В файле /etc/jitsi/jicofo/jicofo.conf
sed -i -e '16a\  authentication: { '  /etc/jitsi/jicofo/jicofo.conf
sed -i -e '17a\    enabled: true'  /etc/jitsi/jicofo/jicofo.conf
sed -i -e '18a\    type: XMPP'  /etc/jitsi/jicofo/jicofo.conf
sed -i -e "19a\    login-url: $domainNameForJitsi"  /etc/jitsi/jicofo/jicofo.conf
sed -i -e '20a\  }'  /etc/jitsi/jicofo/jicofo.conf

# 9.3. Воодим заранее заданные доменное имя, а также логин и пароль организатора конференции
prosodyctl register $jitsiLoginOrganizer $domainNameForJitsi $jitsiPasswordOrganizer

# 10. Перезагружаем службы
sudo systemctl restart prosody jicofo jitsi-videobridge2
