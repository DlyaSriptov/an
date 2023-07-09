#!/bin/bash

peerTubeNameDomain=A
postgresPass=A
emailScan=A
keyScan=$(openssl rand -hex 32)

read -p "Введите имя домена для PeerTube: " peerTubeNameDomain
read -p "Введите адрес электронной почты администратора PeerTube: " emailScan

sudo apt-get -y -q install curl sudo unzip
# ============================================================

# 1. Установка Node.js
curl -sL https://deb.nodesource.com/setup_16.x | sudo -E bash -
# ============================================================

# 2. Установка Yarn
curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -
echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
sudo apt-get -y -q install yarn
# ============================================================

# 3. Установка Python
sudo apt-get -y -q update
sudo apt-get -y -q install python3-dev python-is-python3 # python-is-python2 should also work
python --version # Should be >= 2.x or >= 3.x
# ============================================================

# 4 .Установка общих зависимостей
sudo apt-get -y -q update
sudo apt-get -y -q install certbot nginx ffmpeg postgresql postgresql-contrib openssl g++ make redis-server git cron wget
ffmpeg -version # Should be >= 4.1
g++ -v # Should be >= 5.x
redis-server --version # Should be >= 6.x
# ============================================================

# 5. Запуск служб PostgreSQL и Redis
sudo systemctl start redis postgresql
# ============================================================

# 6. Создание пользователя peertube
sudo mkdir /var/www/peertube
sudo useradd -m -d /var/www/peertube -s /bin/bash -p peertube peertube
# ============================================================

# 7. Ввод пароля для пользователя peertube (вручную)
echo -en "\033[32m Введите пароль для пользователя peertube: \033[0m \n"
sudo passwd peertube
# ============================================================

# 8. Даём права для nginx на каталог www
chown -R www-data:www-data /var/www/
chmod -R 755 /var/www/
# ============================================================

# 9. Переходим в новый каталог и создаём пользователя PostgreSQL  peertube. При появлении запроса нужно ввести пароль для нового пользователя.
echo -en "\033[32m Введите пароль для пользователя базы данных postgres: \033[0m \n"
cd /var/www/peertube
sudo -u postgres psql -c "REVOKE ALL ON DATABASE postgres FROM peertube;"
sudo -u postgres psql -c "REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM peertube;"
sudo -u postgres psql -c "DROP DATABASE peertube_prod;"
sudo -u postgres createuser -P peertube
read -p "Введите, пожалуйста, третий раз пароль пользователя базы данных postgres: " postgresPass 
# ============================================================

# 10. Создаём базу данных PostgreSQL для использования PeerTube.
sudo -u postgres createdb -O peertube -E UTF8 -T template0 peertube_prod
# ============================================================

# 11. Включаем два расширения PostgreSQL, которые нужны PeerTube
sudo -u postgres psql -c "CREATE EXTENSION pg_trgm;" peertube_prod
sudo -u postgres psql -c "CREATE EXTENSION unaccent;" peertube_prod
# ============================================================

# 12. Запрашиваем API PeerTube для получения подробной информации о текущем выпуске PeerTube
VERSION=$(curl -s https://api.github.com/repos/chocobozzz/peertube/releases/latest | grep tag_name | cut -d '"' -f 4) && echo "Latest Peertube version is $VERSION"
# ============================================================

# 13. Открываем каталог peertube, создайте несколько необходимых подкаталогов
cd /var/www/peertube
sudo -u peertube mkdir config storage versions
sudo -u peertube chmod 750 config/
# ============================================================

# 14. Скачиваем последнюю версию клиента Peertube, разархивируем и удаляем оригинальный zip-архив
cd /var/www/peertube/versions
# Releases are also available on https://builds.joinpeertube.org/release
sudo -u peertube wget "https://github.com/Chocobozzz/PeerTube/releases/download/${VERSION}/peertube-${VERSION}.zip"
sudo -u peertube unzip peertube-${VERSION}.zip && sudo -u peertube rm peertube-${VERSION}.zip
# ============================================================

# 15. Устанавливаем PeerTube
cd /var/www/peertube
sudo -u peertube ln -s versions/peertube-${VERSION} ./peertube-latest
cd ./peertube-latest && sudo -H -u peertube yarn install --production --pure-lockfile
# ============================================================

# 16. Копируем файл default.yaml в каталог config. Файл редактировать и обновлять нельзя
cd /var/www/peertube
sudo -u peertube cp peertube-latest/config/default.yaml config/default.yaml
# ============================================================

# 17. Из того же каталога копируем production.yaml в новое место
cd /var/www/peertube
sudo -u peertube cp peertube-latest/config/production.yaml.example config/production.yaml
# ============================================================

# 18. Редактируем файл /var/www/peertube/config/production.yaml
sudo sed -i -e "s|hostname: 'example.com'|hostname: '$peerTubeNameDomain'|" /var/www/peertube/config/production.yaml
sudo sed -i -e "s|peertube: ''|peertube: '$keyScan'|" /var/www/peertube/config/production.yaml
sudo sed -i -e "s|password: 'peertube'|password: '$postgresPass'|" /var/www/peertube/config/production.yaml
sudo sed -i -e "s|email: 'admin@example.com'|email: '$emailScan'|" /var/www/peertube/config/production.yaml
# ============================================================

# 19. Копируем шаблон файла конфигурации NGINX для PeerTube в каталог /etc/nginx/sites-available
sudo cp /var/www/peertube/peertube-latest/support/nginx/peertube /etc/nginx/sites-available/peertube
# ============================================================

# 20. В файле /etc/nginx/sites-available/peertube меняем имя домена (1-я строка), и локальный адрес:порт (2-я строка)
sudo sed -i 's/${WEBSERVER_HOST}/$peerTubeNameDomain/g' /etc/nginx/sites-available/peertube
sudo sed -i 's/${PEERTUBE_HOST}/127.0.0.1:9000/g' /etc/nginx/sites-available/peertube
# ============================================================

# 21. Создаём ссылку на конфиг. файл peertube в каталоге /etc/nginx/sites-enabled
sudo ln -s /etc/nginx/sites-available/peertube /etc/nginx/sites-enabled/peertube
# ============================================================

# 22. Установка сертификата Let's Encrypt
sudo systemctl stop nginx
sudo certbot certonly --standalone --post-hook "systemctl restart nginx"
sudo systemctl reload nginx
# ============================================================

# 23. Скопируйте файл 30-peertube-tcp.conf в каталог с системными настройками
sudo cp /var/www/peertube/peertube-latest/support/sysctl.d/30-peertube-tcp.conf /etc/sysctl.d/
# ============================================================

# 24. Запускаем ранее скопированный файл
sudo sysctl -p /etc/sysctl.d/30-peertube-tcp.conf
# ============================================================

# 25. Завершающие настройки и запуск службы PeerTube
sudo cp /var/www/peertube/peertube-latest/support/systemd/peertube.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable peertube
sudo systemctl start peertube


# cd /var/www/peertube/peertube-latest && NODE_CONFIG_DIR=/var/www/peertube/config NODE_ENV=production npm run reset-password -- -u root
