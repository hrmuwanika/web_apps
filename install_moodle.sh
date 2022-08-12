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
# default_storage_engine = innodb
# innodb_file_per_table = 1
# innodb_file_format = Barracuda
# innodb_large_prefix = 1

sudo systemctl restart mysql.service

sudo mysql -uroot --password="" -e "CREATE DATABASE moodle DEFAULT CHARACTER SET utf8 COLLATE utf8_unicode_ci;"
sudo mysql -uroot --password="" -e "GRANT ALL PRIVILEGES ON moodle.* TO 'moodle_admin'@'localhost' IDENTIFIED WITH mysql_native_password BY 'abc1234!';"
sudo mysql -uroot --password="" -e "FLUSH PRIVILEGES;"
sudo mysqladmin -uroot --password="" reload 2>/dev/null
sudo systemctl restart mysql.service

#--------------------------------------------------
# Installation of PHP
#--------------------------------------------------
sudo apt install -y software-properties-common
sudo add-apt-repository ppa:ondrej/php 
sudo apt update

sudo apt install -y graphviz aspell ghostscript clamav php8.1-fpm php8.1-cli php8.1-pspell php8.1-curl php8.1-gd php8.1-intl php8.1-mysql \
php8.1-xml php8.1-xmlrpc php8.1-ldap php8.1-zip php8.1-soap php8.1-mbstring

sudo sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php/8.1/fpm/php.ini
sudo sed -i s/"memory_limit = 128M"/"memory_limit = 256M"/g /etc/php/8.1/fpm/php.ini
sudo sed -i s/"upload_max_filesize = 2M"/"upload_max_filesize = 100M"/g /etc/php/8.1/fpm/php.ini
sudo sed -i s/"max_execution_time = 30"/"max_execution_time = 360"/g /etc/php/8.1/fpm/php.ini
sudo sed -i s/";date.timezone =/date.timezone = Africa\/Kigali"/g /etc/php/8.1/fpm/php.ini

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
sudo chown -R nginx /var/moodledata
sudo chmod -R 0770 /var/moodledata

sudo cat <<EOF > /etc/nginx/sites-available/moodle

#########################################################################

server {
    listen 80;
    listen [::]:80;
    root /var/www/html/moodle;
    index  index.php index.html index.htm;
    server_name $WEBSITE_NAME;

    location / {
    try_files $uri $uri/ =404;        
    }
 
    location /dataroot/ {
    internal;
    alias /var/moodledata/;
    }

    location ~ [^/]\.php(/|$) {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.1-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

}

#########################################################################
EOF

sudo ln -s /etc/nginx/sites-available/moodle /etc/nginx/sites-enabled/
sudo service nginx restart

sudo mkdir -p /var/quarantine
sudo chown -R www-data /var/quarantine

#--------------------------------------------------
# Enable ssl with certbot
#--------------------------------------------------

if [ $ENABLE_SSL = "True" ] && [ $ADMIN_EMAIL != "moodle@example.com" ]  && [ $WEBSITE_NAME != "example.com" ];then
  sudo apt install snapd -y
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
