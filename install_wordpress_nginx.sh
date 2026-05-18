#!/bin/bash

################################################################################
# Script for installing Wordpress Mariadb, Nginx and Php 8.4 on Ubuntu 20.04, 22.04, 24.04
# Authors: Henry Robert Muwanika

# Make a new file:
# sudo nano install_wordpress_nginx.sh
# Place this content in it and then make the file executable:
# sudo chmod +x install_wordpress_nginx.sh
# Execute the script to install Moodle:
# ./install_wordpress_nginx.sh

################################################################################

# Set to "True" to install certbot and have ssl enabled, "False" to use http
ENABLE_SSL="True"
# Set the website name
WEBSITE_NAME="example.com"
# Provide Email to register ssl certificate
ADMIN_EMAIL="info@example.com"

echo "
#--------------------------------------------------
# Update Server
#--------------------------------------------------"
echo "============= Update Server ================"
sudo apt update -y && sudo apt upgrade -y
sudo apt autoremove -y

echo "
#----------------------------------------------------
# Enabling password authentication
#----------------------------------------------------"
sudo apt install -y openssh-server
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sudo systemctl restart ssh

echo "
#--------------------------------------------------
# Generate SSH key pairs
#--------------------------------------------------"
# ssh-keygen -t rsa -b 4096

echo "
#--------------------------------------------------
# Set up the timezones
#--------------------------------------------------"
# set the correct timezone on ubuntu
timedatectl set-timezone Africa/Kigali
timedatectl

echo "
#--------------------------------------------------
# Installation of PHP
#--------------------------------------------------"
sudo apt install -y ca-certificates apt-transport-https software-properties-common lsb-release gnupg2
apt -y install software-properties-common
add-apt-repository ppa:ondrej/php
sudo apt update -y

sudo apt install -y php8.4 php8.4-common php8.4-cli php8.4-intl php8.4-xmlrpc php8.4-zip php8.4-gd php8.4-tidy php8.4-mbstring php8.4-curl php-pear \
php8.4-dev php8.4-bcmath php8.4-pspell php8.4-ldap php8.4-soap php8.4-gmp php8.4-imagick php8.4-fpm php8.4-redis php8.4-apcu php8.4-mysql php8.4-xml \
php8.4-imap php8.4-snmp 

sudo apt autoremove apache2 -y

sudo apt install -y nginx
sudo systemctl is-active nginx
sudo systemctl is-enabled nginx

sed -ie "s/\;date\.timezone\ =/date\.timezone\ =\ Africa\/Kigali/g" /etc/php/8.4/fpm/php.ini
sed -ie "s/max_execution_time = 30/max_execution_time = 1200/" /etc/php/8.4/fpm/php.ini
sed -ie "s/max_input_time = 60/max_input_time = 1000/" /etc/php/8.4/fpm/php.ini
sed -ie "s/;max_input_vars = 1000/max_input_vars = 10000/" /etc/php/8.4/fpm/php.ini
sed -ie "s/error_reporting = E_ALL \& \~E_DEPRECATED/error_reporting = E_ALL \& \~E_NOTICE \& \~E_DEPRECATED/" /etc/php/8.4/fpm/php.ini
sed -ie "s/short_open_tag = Off/short_open_tag = On/" /etc/php/8.4/fpm/php.ini
sed -ie "s/upload_max_filesize = 2M/upload_max_filesize = 500M/" /etc/php/8.4/fpm/php.ini
sed -ie "s/post_max_size = 8M/post_max_size = 500M/" /etc/php/8.4/fpm/php.ini
sed -ie "s/memory_limit = 128M/memory_limit = 512M/" /etc/php/8.4/fpm/php.ini

sudo systemctl restart php8.4-fpm

echo "
#--------------------------------------------------
# Installing Mariadb Server
#--------------------------------------------------"
sudo apt install -y mariadb-server mariadb-client mariadb-backup
sudo systemctl is-active mariadb
sudo systemctl is-enabled mariadb

# sudo mariadb-secure-installation

sudo systemctl restart mariadb.service

sudo mariadb -uroot --password="" -e "CREATE DATABASE wordpress_db;"
sudo mariadb -uroot --password="" -e "CREATE USER 'dbadmin'@'localhost' IDENTIFIED BY 'abc1234@';"
sudo mariadb -uroot --password="" -e "GRANT ALL PRIVILEGES ON wordpress_db.* TO 'dbadmin'@'localhost';"
sudo mariadb -uroot --password="" -e "FLUSH PRIVILEGES;"

sudo systemctl restart mariadb.service

echo "
#--------------------------------------------------
# Installation of Wordpress
#--------------------------------------------------"
cd /opt && wget https://wordpress.org/latest.tar.gz
sudo tar -zvxf latest.tar.gz

sudo rm index.html index.nginx-debian.html

sudo cp -rf wordpress/ /var/www/
sudo chown -R www-data:www-data /var/www/wordpress
sudo find /var/www/wordpress -type d -exec chmod 755 {} \;
sudo find /var/www/wordpress -type f -exec chmod 644 {} \;
#sudo chmod -R 755 /var/www/wordpress

sudo cat > /etc/nginx/sites-available/wordpress.conf <<'NGINX'
server {
  listen 80;
  listen [::]:80;
  server_name example.com;
  
  root /var/www/wordpress;
  index index.php index.html index.htm index.nginx-debian.html;

  location / {
    try_files $uri $uri/ /index.php?$args;
  }

  location ~* /wp-sitemap.*\.xml {
    try_files $uri $uri/ /index.php$is_args$args;
  }

  client_max_body_size 100M;

  location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/run/php/php8.4-fpm.sock;
    fastcgi_buffer_size 128k;
    fastcgi_buffers 4 128k;
    fastcgi_intercept_errors on;
  }

  gzip on;
  gzip_comp_level 6;
  gzip_min_length 1000;
  gzip_proxied any;
  gzip_disable "msie6";
  gzip_types application/atom+xml application/geo+json application/javascript application/x-javascript application/json application/ld+json application/manifest+json application/rdf+xml application/rss+xml application/xhtml+xml application/xml font/eot font/otf font/ttf image/svg+xml text/css text/javascript text/plain text/xml;

  location ~* \.(?:css(\.map)?|js(\.map)?|jpe?g|png|gif|ico|cur|heic|webp|tiff?|mp3|m4a|aac|ogg|midi?|wav|mp4|mov|webm|mpe?g|avi|ogv|flv|wmv)$ {
    expires 90d;
    access_log off;
  }

  location ~* \.(?:svgz?|ttf|ttc|otf|eot|woff2?)$ {
    add_header Access-Control-Allow-Origin "*";
    expires 90d;
    access_log off;
  }

  location ~ /\.ht {
    access_log off;
    log_not_found off;
    deny all;
  }
}
NGINX

sudo rm /etc/nginx/sites-available/default
sudo rm /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/wordpress.conf /etc/nginx/sites-enabled/

nginx -t

sudo systemctl restart nginx.service
sudo systemctl restart php8.4-fpm

echo "
#--------------------------------------------------
# Install and configure Firewall
#--------------------------------------------------"
sudo apt install -y ufw

sudo ufw allow 22/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable UFW
sudo ufw --force enable
sudo ufw reload


echo "
#--------------------------------------------------
# Enable ssl with certbot
#--------------------------------------------------"

if [ $ENABLE_SSL = "True" ] && [ $ADMIN_EMAIL != "info@example.com" ]  && [ $WEBSITE_NAME != "example.com" ];then
  sudo apt install -y snapd
  sudo apt-get remove certbot
  
  sudo snap install core
  sudo snap refresh core
  sudo snap install --classic certbot
  sudo ln -s /snap/bin/certbot /usr/bin/certbot
  sudo apt install -y python3-certbot-nginx
  sudo certbot --nginx -d $WEBSITE_NAME --noninteractive --agree-tos --email $ADMIN_EMAIL --redirect
  
  sudo systemctl restart nginx
  
  echo "============ SSL/HTTPS is enabled! ========================"
else
  echo "==== SSL/HTTPS isn't enabled due to choice of the user or because of a misconfiguration! ======"
fi

sudo systemctl restart nginx

echo "Wordpress installation is complete"
echo "Access wordpress on https://$WEBSITE_NAME"



