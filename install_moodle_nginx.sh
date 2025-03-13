#!/bin/bash

################################################################################
# Script for installing Moodle v4.5.2 Postgresql, Nginx and Php 8.3 on Ubuntu 24.04
# Authors: Henry Robert Muwanika

# Make a new file:
# sudo nano install_moodle.sh
# Place this content in it and then make the file executable:
# sudo chmod +x install_moodle_nginx.sh
# Execute the script to install Moodle:
# ./install_moodle_nginx.sh
# crontab -e
# * * * * * /usr/bin/php /var/www/html/admin/cli/cron.php
################################################################################

# Set to "True" to install certbot and have ssl enabled, "False" to use http
ENABLE_SSL="True"
# Set the website name
WEBSITE_NAME="example.com"
# Provide Email to register ssl certificate
ADMIN_EMAIL="moodle@example.com"

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo "============= Update Server ================"
sudo apt update && sudo apt upgrade -y
sudo apt autoremove -y

#----------------------------------------------------
# Disabling password authentication
#----------------------------------------------------
echo "Disabling password authentication ... "
sudo sed -i 's/#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config 
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo service sshd restart

#--------------------------------------------------
# Set up the timezones
#--------------------------------------------------
# set the correct timezone on ubuntu
timedatectl set-timezone Africa/Kigali
timedatectl

#--------------------------------------------------
# Installation of PHP
#--------------------------------------------------
sudo apt install -y software-properties-common ca-certificates lsb-release apt-transport-https
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

sudo apt install -y php php-fpm php-common php-gmp php-curl php-intl php-mbstring php-soap php-xmlrpc php-gd php-xml php-cli php-zip unzip git curl \
php-json php-sqlite3 php-bcmath php-pspell php-ldap libpcre3 libpcre3-dev graphviz aspell ghostscript clamav 

sudo apt install -y nginx-full 
sudo systemctl start nginx.service
sudo systemctl enable nginx.service

sudo sed -i 's,^memory_limit =.*$,memory_limit = 256M,' /etc/php/8.3/fpm/php.ini
sudo sed -i 's,^;max_input_vars =.*$,max_input_vars = 7000,' /etc/php8.3/fpm/php.ini
sudo sed -i 's,^;cgi.fix_pathinfo=.*$,cgi.fix_pathinfo = 0,' /etc/php/8.3/fpm/php.ini
sudo sed -i 's,^upload_max_filesize =.*$,upload_max_filesize = 100M,' /etc/php/8.3/fpm/php.ini
sudo sed -i 's,^max_execution_time =.*$,max_execution_time = 600,' /etc/php/8.3/fpm/php.ini
sudo sed -i "s/\;date\.timezone\ =/date\.timezone\ =\ Africa\/Kigali/g" /etc/php/8.3/fpm/php.ini

sudo systemctl restart php8.3-fpm

#--------------------------------------------------
# Installing PostgreSQL Server
#--------------------------------------------------
echo -e "=== Install and configure PostgreSQL ... ==="
if [ $INSTALL_POSTGRESQL_SIXTEEN = "True" ]; then
    echo -e "=== Installing postgreSQL V16 due to the user it's choice ... ==="
    sudo apt -y install postgresql-16 postgresql-contrib php-pgsql
fi

echo "=== Starting PostgreSQL service... ==="
sudo systemctl start postgresql 
sudo systemctl enable postgresql

# Create the new user with superuser privileges
# sudo su - postgres
# psql
# CREATE USER moodleuser WITH PASSWORD 'abc1234';
# CREATE DATABASE moodledb;
# GRANT ALL PRIVILEGES ON DATABASE moodledb to moodleuser;
# \q
# exit

#--------------------------------------------------
# Installation of Moodle
#--------------------------------------------------
cd /opt/
wget https://download.moodle.org/download.php/direct/stable405/moodle-latest-405.tgz
tar xvf moodle-latest-405.tgz

rm -rf /var/www/html/*
cp -rf /opt/moodle/* /var/www/html/

sudo mkdir -p /var/www/moodledata
sudo chown -R www-data:www-data /var/www/moodledata
sudo find /var/www/moodledata -type d -exec chmod 700 {} \; 
sudo find /var/www/moodledata -type f -exec chmod 600 {} \;

sudo chown -R www-data:www-data /var/www/html
sudo find /var/www/html -type d -exec chmod 755 {} \; 
sudo find /var/www/html -type f -exec chmod 644 {} \;

sudo mkdir -p /var/quarantine
sudo chown -R www-data:www-data /var/quarantine

sudo cat > /etc/nginx/sites-available/moodle.conf <<NGINX
server {
    listen 80;
    listen [::]:80;
    root /var/www/html;
    index  index.php index.html index.htm;
    server_name  example.com www.example.com;

    access_log /var/log/nginx/moodle.access.log;
    error_log  /var/log/nginx/moodle.error.log  warn;

    client_max_body_size 100M;
    autoindex off;
    location / {
     try_files $uri $uri/ =404;
    }

    location /dataroot/ {
      internal;
      alias /var/www/moodledata/;
    }


    location ~ [^/]\.php(/|$) {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

}
NGINX

sudo rm /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/moodle.conf /etc/nginx/sites-enabled/

nginx -t

sudo systemctl restart nginx.service
sudo systemctl restart php8.3-fpm

#--------------------------------------------------
# Install and configure Firewall
#--------------------------------------------------
sudo apt install -y ufw
sudo ufw allow 22/tcp
sudo ufw allow "Nginx Full"
sudo ufw enable 
sudo ufw reload

#--------------------------------------------------
# Enable ssl with certbot
#--------------------------------------------------

if [ $ENABLE_SSL = "True" ] && [ $ADMIN_EMAIL != "moodle@example.com" ]  && [ $WEBSITE_NAME != "example.com" ];then
  sudo apt install -y snapd
sudo apt-get remove certbot
  
  sudo snap install core
  sudo snap refresh core
  sudo snap install --classic certbot
  sudo ln -s /snap/bin/certbot /usr/bin/certbot
  sudo certbot --nginx -d $WEBSITE_NAME --noninteractive --agree-tos --email $ADMIN_EMAIL --redirect
  
  sudo systemctl restart nginx
  
  echo "============ SSL/HTTPS is enabled! ========================"
else
  echo "==== SSL/HTTPS isn't enabled due to choice of the user or because of a misconfiguration! ======"
fi

sudo systemctl restart nginx

echo "Moodle installation is complete"
echo "Access moodle on https://$WEBSITE_NAME/install.php"



