#!/bin/bash

nbicsNameDomain=A
nbicsPasswordDataBase=A
hostnameScan=$(hostname)

read -p "Введите имя домена для NBICS: " nbicsNameDomain
read -p "Введите пароль администратора SQL Server: " nbicsPasswordDataBase

# ==================================================================

# 1. Устанавливаем SQL Server (модифицированный сторонний скрипт)
# 1.1. Удаляем предыдыдущий SQL Server (если есть)
systemctl stop mssql-server
apt-get -y -q remove mssql-server
apt-get -y -q remove mssql-tools unixodbc-dev
rm -rf /var/opt/mssql

# 1.2. Добавляем ключ и репозиторий для SQL Server
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | tee /etc/apt/trusted.gpg.d/microsoft.asc
add-apt-repository "$(wget -qO- https://packages.microsoft.com/config/ubuntu/20.04/mssql-server-2022.list)"

# 1.3. Обновляем список пакетов и устанавливаем SQL Server
apt-get update
apt-get -y install mssql-server

# 1.4. Настраиваем SQL Server (задаём пароль и лицензию Express)
ACCEPT_EULA=Y MSSQL_SA_PASSWORD='$nbicsPasswordDataBase' MSSQL_PID='Express' /opt/mssql/bin/mssql-conf -n setup

# 1.5. Смотрим статус службы mssql-server (для скрипта это необязательно, но в логах вывода в терминале появится запись об этом)
systemctl status mssql-server --no-pager

# 1.6. Обновляем список пакетов, добавляем ключ и репозиторий для инструментов командной строки
apt-get update
curl https://packages.microsoft.com/keys/microsoft.asc | tee /etc/apt/trusted.gpg.d/microsoft.asc
curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list | tee /etc/apt/sources.list.d/msprod.list

# 1.7. Обновляем список пакетов, устанавливаем инструменты командной строки для SQL Server
apt-get update
ACCEPT_EULA=Y apt-get install -y mssql-tools unixodbc-dev

# 1.8. Делаем видимой из любого каталога команду sqlcmd
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
source ~/.bashrc

# 1.9. Цикл подключения к SQL Server
counter=1
errstatus=1
while [ $counter -le 5 ] && [ $errstatus = 1 ]
do
  echo "Подождите, подключаемся к SQL Server..."
  sleep 3s
  /opt/mssql-tools/bin/sqlcmd -S $hostnameScan -U sa -P '$nbicsPasswordDataBase' -Q "SELECT @@VERSION" 2>/dev/null
  errstatus=$?
  ((counter++))
done

# 1.10. Если подключения не произойдёт - сработает условие, и прервёт установку
if [ $errstatus = 1 ]
then
  echo "Нет подключения к SQL Server, установка прервана"
  exit $errstatus
fi
# ==================================================================

# 2. Устанавливаем DotNET
wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
dpkg -i packages-microsoft-prod.deb
rm -f packages-microsoft-prod.deb
apt-get -y -q update
apt-get -y -q install dotnet-sdk-7.0
apt-get -y -q update
apt-get -y -q install aspnetcore-runtime-7.0
apt-get -y -q install libgdiplus
# ==================================================================

# 3. Удаляем старый каталог с сайтом (если есть)
rm -rf /var/www/html/$nbicsNameDomain
# ==================================================================

# 4. Скачиваем новый каталог с сайтом (если его архива нет)
FILElinks1=/var/www/html/update-school-sample.nbics.net.zip
if [ ! -f "$FILElinks1" ]; then
    wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id=1OZgcIORQVUiB_dovBPPiyB2L3iuIWpuC' -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\n/p')&id=1OZgcIORQVUiB_dovBPPiyB2L3iuIWpuC" -O update-school-sample.nbics.net.zip && rm -rf /tmp/cookies.txt
    mv update-school-sample.nbics.net.zip /var/www/html/
fi
# ==================================================================

# 5. Распаковываем архив с сайтом
unzip /var/www/html/update-school-sample.nbics.net.zip -d /var/www/html/
# ==================================================================

# 6. Меняем настройки в файле appsettings.json
echo -n > /var/www/html/update-school-sample.nbics.net/appsettings.json
cp ./files/appsettings.json /var/www/html/update-school-sample.nbics.net/appsettings.json
sed -i -e "s|NAME_DOMAIN|$nbicsNameDomain|" /var/www/html/update-school-sample.nbics.net/appsettings.json
sed -i -e "s|SA_PASSWORD_BD|$nbicsPasswordDataBase|" /var/www/html/update-school-sample.nbics.net/appsettings.json
sed -i -e "s|NAME_SERVER|$hostnameScan|" /var/www/html/update-school-sample.nbics.net/appsettings.json
sed -i -e "s|NAME_DATABASE|TestDB|" /var/www/html/update-school-sample.nbics.net/appsettings.json
# ==================================================================

# 7. Переименовываем каталог с сайтом
mv /var/www/html/update-school-sample.nbics.net /var/www/html/$nbicsNameDomain
# ==================================================================

# 8. Создаём каталоги для для базы данных (если их нет), скачиваем базу данных, распаковываем её и восстанавливаем
FILE8=/var/opt/db
if [ ! -d "$FILE8" ]; then
    mkdir /var/opt/db /var/opt/db/BACKUP /var/opt/db/DATA /var/opt/db/LOG
    wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id=1px2z-TirY15P_zkjE9KEbot5JYGCL8--' -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\n/p')&id=1px2z-TirY15P_zkjE9KEbot5JYGCL8--" -O TestDB.zip && rm -rf /tmp/cookies.txt
    mv TestDB.zip /var/opt/db/BACKUP
    unzip /var/opt/db/BACKUP/TestDB.zip -d /var/opt/db/BACKUP/
    chown -R mssql:mssql /var/opt/db/

    /opt/mssql-tools/bin/sqlcmd \
    -S $hostnameScan \
    -U SA \
    -P '$nbicsPasswordDataBase' \
    -Q "USE [master] RESTORE DATABASE [TestDB] FROM  DISK = N'/var/opt/db/BACKUP/TestDB.bak' WITH  FILE = 1, MOVE N'VSM_Gusev1_Web' TO N'/var/opt/db/DATA/ExtraSql/TestDB.mdf', MOVE N'VSM_Gusev1_Web_MSGS' TO N'/var/opt/db/DATA/ExtraSql/TestDB.ndf', MOVE N'VSM_Gusev1_Web_1' TO N'/var/opt/db/LOG/ExtraSql/TestDB_1.ldf',  NOUNLOAD,  STATS = 5"
fi
# ==================================================================

# 9. Даём права пользователю на каталог db
chown -R mssql:mssql /var/opt/db/
# ==================================================================

# 10. Проверка файла службы Kestrel на существование
#      Не существует - создать, скопировать туда шаблон и вписать доменное имя
#      Существует - очистить, скопировать туда шаблон и вписать доменное имя
FILE5=/etc/systemd/system/kestrel-"$nbicsNameDomain"-service.service
if [ ! -f "$FILE5" ]; then
    touch /etc/systemd/system/kestrel-"$nbicsNameDomain"-service.service
    cp ./files/kestrel-NAME_DOMAIN-service.service /etc/systemd/system/kestrel-"$nbicsNameDomain"-service.service
    sed -i -e "s|NAME_DOMAIN|$nbicsNameDomain|" /etc/systemd/system/kestrel-"$nbicsNameDomain"-service.service
else
    echo -n > /etc/systemd/system/kestrel-"$nbicsNameDomain"-service.service
    cp ./files/kestrel-NAME_DOMAIN-service.service /etc/systemd/system/kestrel-"$nbicsNameDomain"-service.service
    sed -i -e "s|NAME_DOMAIN|$nbicsNameDomain|" /etc/systemd/system/kestrel-"$nbicsNameDomain"-service.service
fi
# ==================================================================

# 11. Проверка файла default (для Nginx) на существование, заполнение актуальным текстом
FILE6=/etc/nginx/sites-available/default
if [ ! -f "$FILE6" ]; then
    touch /etc/nginx/sites-available/default
    cp ./files/default /etc/nginx/sites-available/default
    sed -i -e "s|NAME_DOMAIN|$nbicsNameDomain|" /etc/nginx/sites-available/default
else
    echo -n > /etc/nginx/sites-available/default
    cp ./files/default /etc/nginx/sites-available/default
    sed -i -e "s|NAME_DOMAIN|$nbicsNameDomain|" /etc/nginx/sites-available/default
fi
# ==================================================================

# 12. Проверка ссылки на файл default
FILE7=/etc/nginx/sites-enabled/default
if [ ! -L "$FILE7" ]; then
    ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
fi
# ==================================================================

# 13. Увеличиваем ограничение на размер файлов для Nginx
sed -i -e "s|client_max_body_size 1000m;||"  /etc/nginx/nginx.conf
sed -i -e '22a\        client_max_body_size 1000m;'  /etc/nginx/nginx.conf
# ==================================================================

# 14. Даём права для nginx на каталог с сайтом
chown -R www-data:www-data /var/www/
chmod -R 755 /var/www/
# ==================================================================

# 15. Перезагружаем службу Nginx
systemctl restart nginx
# ==================================================================


# 16. Запускаем службу Kestrel
systemctl enable kestrel-"$nbicsNameDomain"-service.service
systemctl start kestrel-"$nbicsNameDomain"-service.service

#/opt/mssql-tools/bin/sqlcmd -S $hostnameScan -U sa -P '$nbicsPasswordDataBase'
systemctl stop mssql-server
echo -en "\033[32m ====================================================== \033[0m \n"
echo -en "\033[32m ВНИМАНИЕ! \033[0m \n"
echo -en "\033[32m Вам необходимо ещё два раза ввести пароль администратора SQL Server \033[0m \n"
echo -en "\033[32m ------------------------------------------------------ \033[0m \n"
ACCEPT_EULA=Y MSSQL_PID='Express' MSSQL_LCID=1049 /opt/mssql/bin/mssql-conf setup
