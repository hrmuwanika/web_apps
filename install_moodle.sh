#!/bin/bash

################################################################################
# Script for installing Moodle v4.0 MariaDB, Nginx and Php 8.3 on Ubuntu 24.04
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
sudo apt -y install ufw
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw status

#--------------------------------------------------
# Install Nginx Web server
#--------------------------------------------------
sudo apt install curl gnupg2 ca-certificates lsb-release ubuntu-keyring -y

curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
| sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null

echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg arch=amd64] \
http://nginx.org/packages/ubuntu `lsb_release -cs` nginx" \
| sudo tee /etc/apt/sources.list.d/nginx.list
sudo apt update
sudo apt install -y nginx
sudo systemctl stop nginx.service
sudo systemctl start nginx.service
sudo systemctl enable nginx.service

#--------------------------------------------------
# Installation of Mariadb server
#--------------------------------------------------
curl -LsS https://downloads.mariadb.com/MariaDB/mariadb_repo_setup | sudo bash -s -- --mariadb-server-version=10.8
sudo apt update
sudo apt install -y mariadb-server mariadb-client
sudo systemctl stop mariadb.service
sudo systemctl start mariadb.service
sudo systemctl enable mariadb.service

# sudo mysql_secure_installation

# sudo nano /etc/mysql/mariadb.conf.d/50-server.cnf 
# add the below statements
# [mysqld] 
# default_storage_engine = innodb
# innodb_large_prefix = 1
# innodb_file_per_table = 1
# innodb_file_format = Barracuda
# innodb_large_prefix = 1

sudo systemctl restart mysql.service

sudo mysql -uroot --password="" -e "CREATE DATABASE moodledb DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -uroot --password="" -e "CREATE USER 'moodleuser'@'localhost' IDENTIFIED BY 'yourpassword';"
sudo mysql -uroot --password="" -e "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,CREATE TEMPORARY TABLES,DROP,INDEX,ALTER ON moodledb.* TO moodleuser@localhost;"
sudo mysql -uroot --password="" -e "FLUSH PRIVILEGES;"
sudo mysqladmin -uroot --password="" reload 2>/dev/null
sudo systemctl restart mysql.service

#--------------------------------------------------
# Installation of PHP
#--------------------------------------------------
sudo apt install -y software-properties-common ca-certificates lsb-release apt-transport-https dirmngr
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

sudo apt install graphviz aspell ghostscript clamav php8.3-fpm php8.3-cli php8.3-pspell php8.3-curl php8.3-gd php8.3-intl php8.3-mysql php8.3-xml \
php8.3-xmlrpc php8.3-ldap php8.3-zip php8.3-soap php8.3-mbstring unzip git curl libpcre3 libpcre3-dev graphviz

sudo nano /etc/php/8.3/fpm/pool.d/www.conf
   # user = nginx
   # group = nginx
   # listen.owner = nginx
   # listen.group = nginx
   
# sudo nano /etc/php/8.3/fpm/php.ini
  # memory_limit = 256M
  # file_uploads = On
  # allow_url_fopen = On
  # short_open_tag = On
  # cgi.fix_pathinfo = 0
  # upload_max_filesize = 100M
  # max_execution_time = 360
  # date.timezone = Africa/Kigali

sudo systemctl restart php8.0-fpm

#--------------------------------------------------
# Installation of Moodle
#--------------------------------------------------
cd /var/www/html/
sudo git clone https://github.com/moodle/moodle.git 
git branch --track MOODLE_400_STABLE origin/MOODLE_400_STABLE
git checkout MOODLE_400_STABLE

sudo chown -R $USER:$USER /var/www/html/moodle

cd /var/www/html/moodle/
sudo cp config-dist.php config.php

sudo nano config.php
    #CFG->dbtype    = 'mysqli';    // 'pgsql', 'mariadb', 'mysqli', 'auroramysql', 'sqlsrv' or 'oci'
    #CFG->dblibrary = 'native';     // 'native' only at the moment
    #CFG->dbhost    = 'localhost';  // eg 'localhost' or 'db.isp.com' or IP
    #CFG->dbname    = 'moodledb';     // database name, eg moodle
    #CFG->dbuser    = 'moodleuser';   // your database username
    #CFG->dbpass    = 'yourpassword';   // your database password
    #CFG->prefix    = 'mdl_';       // prefix to use for all table names
    #CFG->wwwroot   = 'https://moodle.example.com';
    #CFG->dataroot  = '/var/moodledata';
    
sudo chmod -R 755 /var/www/html/moodle

sudo mkdir /var/moodledata
sudo chown -R nginx /var/moodledata
sudo chmod -R  755 /var/moodledata

sudo mkdir -p /var/quarantine
sudo chown -R www-data /var/quarantine

sudo cat <<EOF > /etc/nginx/sites-available/moodle.conf

#########################################################################

server {
    listen 80;
    listen [::]:80;
    
    server_name $WEBSITE_NAME;
    root   /var/www/html/moodle;
    index  index.php;
    
    client_max_body_size 200M;
    
    autoindex off;
    location / {
        try_files $uri $uri/ =404;
    }
    
    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
        expires max;
        log_not_found off;
    }	

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }	

    location /dataroot/ {
    internal;
    alias /var/moodledata/;
    }

    location ~ ^(.+\.php)(.*)$ {
        fastcgi_split_path_info ^(.+\.php)(.*)$;
        fastcgi_index index.php;
        fastcgi_pass unix:/run/php/php8.0-fpm.sock;
        include /etc/nginx/mime.types;
        include fastcgi_params;
        fastcgi_param  PATH_INFO  $fastcgi_path_info;
        fastcgi_param  SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }

    # Hide all dot files but allow "Well-Known URIs" as per RFC 5785
    location ~ /\.(?!well-known).* {
        return 404;
    }

    # This should be after the php fpm rule and very close to the last nginx ruleset.
    # Don't allow direct access to various internal files. See MDL-69333
    location ~ (/vendor/|/node_modules/|composer\.json|/readme|/README|readme\.txt|/upgrade\.txt|db/install\.xml|/fixtures/|/behat/|phpunit\.xml|\.lock|environment\.xml) {
        deny all;
        return 404;
    }
}

#########################################################################
EOF

nginx -t

sudo ln -s /etc/nginx/sites-available/moodle.conf /etc/nginx/sites-enabled/

sudo systemctl reload nginx
sudo systemctl reload php8.0-fpm

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


