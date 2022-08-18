#!/bin/bash

################################################################################
# Script for installing Moodle v4.0 MariaDB, Nginx and Php 8.1 on Ubuntu 22.04
# Authors: Henry Robert Muwanika

# Make a new file:
# sudo nano install_moodle.sh
# Place this content in it and then make the file executable:
# sudo chmod +x install_moodle.sh
# Execute the script to install Moodle:
# ./install_moodle.sh
#
################################################################################
#
# Set to "True" to install certbot and have ssl enabled, "False" to use http
ENABLE_SSL="True"
# Set the website name
WEBSITE_NAME="example.com"
# Provide Email to register ssl certificate
ADMIN_EMAIL="moodle@example.com"
#
#
#----------------------------------------------------
# Disable password authentication
#----------------------------------------------------
sudo sed -i 's/#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config 
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo service sshd restart
#
#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n============= Update Server ================"
sudo apt update && sudo apt upgrade -y
sudo apt autoremove -y

#--------------------------------------------------
# Firewall
#--------------------------------------------------
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https

#--------------------------------------------------
# Install Nginx Web server
#--------------------------------------------------
sudo apt install -y nginx
sudo systemctl stop nginx.service
sudo systemctl start nginx.service
sudo systemctl enable nginx.service

#--------------------------------------------------
# Installation of Mariadb server
#--------------------------------------------------
sudo apt install -y mariadb-server mariadb-client
sudo systemctl stop mariadb.service
sudo systemctl start mariadb.service
sudo systemctl enable mariadb.service

# sudo mysql_secure_installation

sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf 
# add the below statements
# [mysqld]
# innodb_file_per_table = 1
# innodb_file_format = Barracuda
# innodb_large_prefix = ON

sudo systemctl restart mysql.service

sudo mysql -uroot --password="" -e "CREATE DATABASE moodle DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
sudo mysql -uroot --password="" -e "CREATE USER 'moodle_admin'@'localhost' IDENTIFIED BY 'abc1234!';"
sudo mysql -uroot --password="" -e "GRANT ALL ON moodle.* TO 'moodle_admin'@'localhost' WITH GRANT OPTION;"
sudo mysql -uroot --password="" -e "FLUSH PRIVILEGES;"
sudo mysqladmin -uroot --password="" reload 2>/dev/null
sudo systemctl restart mysql.service

#--------------------------------------------------
# Installation of PHP
#--------------------------------------------------
sudo apt install -y software-properties-common ca-certificates lsb-release apt-transport-https
sudo add-apt-repository ppa:ondrej/php 
sudo apt update

apt install -y php7.4 php7.4-fpm php7.4-common php7.4-mysql php7.4-gmp php7.4-curl php7.4-intl php7.4-mbstring php7.4-soap php7.4-xmlrpc php7.4-gd \
php7.4-xml php7.4-cli php7.4-zip unzip git curl nano

sudo nano /etc/php/7.4/fpm/php.ini
# file_uploads = On
# allow_url_fopen = On
# short_open_tag = On
# memory_limit = 256M
# cgi.fix_pathinfo = 0
# upload_max_filesize = 100M
# max_execution_time = 360
# date.timezone = Africa/Kigali

systemctl restart php7.4-fpm

#--------------------------------------------------
# Installation of Moodle
#--------------------------------------------------
wget https://download.moodle.org/download.php/direct/stable400/moodle-latest-400.tgz
sudo tar -zxvf moodle-latest-400.tgz 
sudo mv moodle /var/www/html/

cd /var/www/html/moodle/
sudo cp config-dist.php config.php
sudo nano config.php

sudo chown -R www-data:www-data /var/www/html/moodle
sudo chmod -R 755 /var/www/html/moodle

sudo mkdir /var/moodledata
sudo chown -R www-data:www-data /var/moodledata
sudo chmod -R  755 /var/moodledata

sudo mkdir -p /var/quarantine
sudo chown -R www-data /var/quarantine

sudo cat <<EOF > /etc/nginx/sites-available/moodle

#########################################################################

server {
    listen 80;
    listen [::]:80;
    root /var/www/html/moodle;
    index  index.php index.html index.htm;
    server_name $WEBSITE_NAME;
    
    client_max_body_size 100M;
    
    autoindex off;
    location / {
        try_files $uri $uri/ =404;
    }
    
    location /dataroot/ {
    internal;
    alias /var/moodledata/;
    }

    location ~ [^/]\.php(/|$) {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php7.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

}

#########################################################################
EOF

nginx -t

sudo ln -s /etc/nginx/sites-available/moodle /etc/nginx/sites-enabled/
sudo systemctl restart nginx.service

sudo systemctl reload nginx
sudo systemctl reload php7.4-fpm

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
  
  sudo systemctl reload nginx
  
  echo "\n============ SSL/HTTPS is enabled! ========================"
else
  echo "\n==== SSL/HTTPS isn't enabled due to choice of the user or because of a misconfiguration! ======"
fi

echo -e "Access moodle https://$WEBSITE_NAME/install.php"


