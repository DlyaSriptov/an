#!/bin/bash

nbicsNameDomain=A
#nbicsNameDataBase=A
nbicsPasswordDataBase=A

pwdScan=$(pwd)
hostnameScan=$(hostname)

read -p "Введите имя домена для NBICS: " nbicsNameDomain
#read -p "Введите имя базы данных: " nbicsNameDataBase
read -p "Введите пароль администратора базы данных: " nbicsPasswordDataBase

# ==================================================================

# 1. Устанавливаем SQL Server (модифицированный сторонний скрипт)
# 1.1. Удаляем предыдыдущий SQL Server (если есть)
systemctl stop mssql-server
apt-get -y -q remove mssql-server
apt-get -y -q remove mssql-tools unixodbc-dev

# 1.2. Удаляем предыдущие ключи и репозитории (команды стирания текста не на всех машинах работают)
rm -f /etc/apt/trusted.gpg.d/microsoft-prod.gpg
rm -f /etc/apt/sources.list.d/microsoft-prod.list
rm -f /etc/apt/sources.list.d/microsoft-prod.list.save
sed -i -e '/deb \[arch=amd64,armhf,arm64\] https:\/\/packages.microsoft.com\/ubuntu\/20.04\/mssql-server-2019 focal main/d' /etc/apt/sources.list /etc/apt/sources.list.save
sed -i -e '/# deb-src \[arch=amd64,armhf,arm64\] https:\/\/packages.microsoft.com\/ubuntu\/20.04\/mssql-server-2019 focal main/d' /etc/apt/sources.list /etc/apt/sources.list.save
sed -i -e '/deb \[arch=arm64,armhf,amd64\] https:\/\/packages.microsoft.com\/ubuntu\/20.04\/prod focal main/d' /etc/apt/sources.list /etc/apt/sources.list.save
sed -i -e '/# deb-src \[arch=arm64,armhf,amd64\] https:\/\/packages.microsoft.com\/ubuntu\/20.04\/prod focal main/d' /etc/apt/sources.list /etc/apt/sources.list.save
sed -i -e '/deb \[arch=armhf,arm64,amd64\] https:\/\/packages.microsoft.com\/ubuntu\/20.04\/mssql-server-2022 focal main/d'  /etc/apt/sources.list /etc/apt/sources.list.save
sed -i -e '/# deb-src \[arch=armhf,arm64,amd64\] https:\/\/packages.microsoft.com\/ubuntu\/20.04\/mssql-server-2022 focal main/d' /etc/apt/sources.list /etc/apt/sources.list.save

# 1.3. Вписываем новые ключи и репозитории
curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
repoargs="$(curl https://packages.microsoft.com/config/ubuntu/20.04/mssql-server-2022.list)"
add-apt-repository "${repoargs}"
repoargs="$(curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list)"
add-apt-repository "${repoargs}"

# 1.4. Устанавливаем SQL Server
apt-get -y -q update
apt-get -y -q install mssql-server

# 1.5. Настраиваем SQL Server
MSSQL_SA_PASSWORD='$nbicsPasswordDataBase' MSSQL_PID='Express' /opt/mssql/bin/mssql-conf -n setup accept-eula

# 1.6. Устанавливаем инструменты командной строки
ACCEPT_EULA=Y apt-get install -y mssql-tools unixodbc-dev

# 1.7. Задаём видимость sqlcmd из любых каталогов
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bash_profile
echo 'export PATH="$PATH:/opt/mssql-tools/bin"' >> ~/.bashrc
source ~/.bashrc

ufw reload

systemctl restart mssql-server

# 1.8. Пятишаговый цикл с проверкой подключения к SQL серверу
counter=1
errstatus=1
while [ $counter -le 5 ] && [ $errstatus = 1 ]
do
  echo "Подождите, запускается SQL Server..."
  sleep 3s
  /opt/mssql-tools/bin/sqlcmd -S $hostnameScan -U SA -P $MSSQL_SA_PASSWORD -Q "SELECT @@VERSION" 2>/dev/null
  errstatus=$?
  ((counter++))
done

if [ $errstatus = 1 ]
then
  echo "Нет подключения к SQL Server, установка прервана"
  exit $errstatus
fi
# ==================================================================

# 2. Последовательная проверка каталогов и файлов на существование
#    При необходимости - создание нужных каталогов и файлов
FILE=/home/download
if [ ! -d "$FILE" ]; then
    mkdir /home/download
fi
# ........................................

FILE2=/var/www
if [ ! -d "$FILE2" ]; then
    mkdir /var/www
fi

FILE3=/var/www/html
if [ ! -d "$FILE3" ]; then
    mkdir /var/www/html
fi

cd /var/www/html
# ........................................

# 2.2. Эта проверка инвертирована
FILE4=$nbicsNameDomain
if [ -d "$FILE4" ]; then
    rm -rf $nbicsNameDomain
fi

cd $pwdScan
# ........................................

# 2.3. Проверка файла службы Kestrel на существование 
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
# ........................................

# 2.4. Проверка файла default (для Nginx) на существование, заполнение актуальным текстом
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
# ........................................

# 2.5. Проверка ссылки на файл default
FILE7=/etc/nginx/sites-enabled/default
if [ ! -L "$FILE7" ]; then
    ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
fi
# ........................................

# 2.6. Создание каталогов для для базы данных
#      Предварительная проверка каталогов на существование
FILE8=/var/opt/db
if [ ! -d "$FILE8" ]; then
    mkdir /var/opt/db /var/opt/db/BACKUP /var/opt/db/DATA /var/opt/db/LOG
    chown -R mssql:mssql /var/opt/db/
else
    rm -rf /var/opt/db
    mkdir /var/opt/db /var/opt/db/BACKUP /var/opt/db/DATA /var/opt/db/LOG
    chown -R mssql:mssql /var/opt/db/
fi
# ==================================================================

# 3. Скачиваем архивы с сайтом и базой данных, а также файл SkiaSharp.dll
cd /home/download
FILElinks1=update-school-sample.nbics.net.zip
if [ ! -f "$FILElinks1" ]; then
    wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id=1OZgcIORQVUiB_dovBPPiyB2L3iuIWpuC' -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\n/p')&id=1OZgcIORQVUiB_dovBPPiyB2L3iuIWpuC" -O update-school-sample.nbics.net.zip && rm -rf /tmp/cookies.txt
fi

FILElinks2=TestDB.zip
if [ ! -f "$FILElinks2" ]; then
    wget --load-cookies /tmp/cookies.txt "https://docs.google.com/uc?export=download&confirm=$(wget --quiet --save-cookies /tmp/cookies.txt --keep-session-cookies --no-check-certificate 'https://docs.google.com/uc?export=download&id=1px2z-TirY15P_zkjE9KEbot5JYGCL8--' -O- | sed -rn 's/.*confirm=([0-9A-Za-z_]+).*/\n/p')&id=1px2z-TirY15P_zkjE9KEbot5JYGCL8--" -O TestDB.zip && rm -rf /tmp/cookies.txt
fi 

FILElinks3=SkiaSharp.dll
if [ ! -f "$FILElinks3" ]; then
    wget https://nbics.net/SiteResurses/BaseProject/SkiaSharp.dll
fi 
# ==================================================================

# 4. Распаковываем архивы
# 4.1. Распаковываем архив с сайтом
unzip /home/download/update-school-sample.nbics.net.zip
# ........................................

# 4.2. Распаковываем архив с базой данных
unzip /home/download/TestDB.zip
# ==================================================================

# 5. Переименовываем каталог с сайтом (назначаем ему имя домена)
#    И меняем настройки в файле appsettings.json
# 5.1. Меняем настройки в файле appsettings.json
echo -n > /home/download/update-school-sample.nbics.net/appsettings.json
cd $pwdScan
cp ./files/appsettings.json /home/download/update-school-sample.nbics.net/appsettings.json
cd /home/download
sed -i -e "s|NAME_DOMAIN|$nbicsNameDomain|" ./update-school-sample.nbics.net/appsettings.json
sed -i -e "s|SA_PASSWORD_BD|$nbicsPasswordDataBase|" ./update-school-sample.nbics.net/appsettings.json
sed -i -e "s|NAME_SERVER|$hostnameScan|" ./update-school-sample.nbics.net/appsettings.json
sed -i -e "s|NAME_DATABASE|TestDB|" ./update-school-sample.nbics.net/appsettings.json
# ........................................

# 5.2. Переименовываем каталог с сайтом
mv update-school-sample.nbics.net $nbicsNameDomain
# ==================================================================

# 6. Копируем каталог с сайтом и базу данных и удаляем оригиналы
# 6.1. Копируем каталог с сайтом
cp -r $nbicsNameDomain /var/www/html/"$nbicsNameDomain"
# ........................................

# 6.2. Копируем базу данных
cp TestDB.bak /var/opt/db/BACKUP/
# ........................................

# 6.3. [Позже реализовать цикл проверки копии и оригинала по размеру]
# ........................................

# 6.4. Удаляем распакованные оригиналы
rm -rf $nbicsNameDomain
rm -f TestDB.bak

cd $pwdScan
# ==================================================================

# 7. Увеличиваем ограничение на размер файлов для Nginx
sed -i -e "s|client_max_body_size 1000m;||"  /etc/nginx/nginx.conf
sed -i -e '22a\        client_max_body_size 1000m;'  /etc/nginx/nginx.conf
# ==================================================================

# 8. Даём права для nginx на каталог с сайтом
chown -R www-data:www-data /var/www/
chmod -R 755 /var/www/
# ==================================================================

# 9. Перезагружаем службу Nginx
systemctl restart nginx
# ==================================================================

# 10. Устанавливаем DotNET
wget https://packages.microsoft.com/config/ubuntu/20.04/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
dpkg -i packages-microsoft-prod.deb
rm -f packages-microsoft-prod.deb
apt-get -y -q update
apt-get -y -q install dotnet-sdk-7.0
apt-get -y -q update
apt-get -y -q install aspnetcore-runtime-7.0
apt-get -y -q install libgdiplus
# ==================================================================

# 11. Копируем файл SkiaSharp.dll в нужные каталоги и даём на него права
cp /home/download/SkiaSharp.dll /var/www/html/"$nbicsNameDomain"/
cp /home/download/SkiaSharp.dll /usr/lib/
cd /usr/lib/
chmod +x SkiaSharp.dll
cd $pwdScan
# ==================================================================

/opt/mssql-tools/bin/sqlcmd \
    -S $hostnameScan \
    -U SA \
    -P $MSSQL_SA_PASSWORD \
    -Q "USE [master] RESTORE DATABASE [TestDB] FROM  DISK = N'/var/opt/db/BACKUP/TestDB.bak' WITH  FILE = 1, MOVE N'VSM_Gusev1_Web' TO N'/var/opt/db/DATA/ExtraSql/TestDB.mdf', MOVE N'VSM_Gusev1_Web_MSGS' TO N'/var/opt/db/DATA/ExtraSql/TestDB.ndf', MOVE N'VSM_Gusev1_Web_1' TO N'/var/opt/db/LOG/ExtraSql/TestDB_1.ldf',  NOUNLOAD,  STATS = 5"

# 12. Запускаем службу Kestrel
systemctl enable kestrel-"$nbicsNameDomain"-service.service
systemctl start kestrel-"$nbicsNameDomain"-service.service

 
