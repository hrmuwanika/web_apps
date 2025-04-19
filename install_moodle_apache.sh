#!/bin/bash

################################################################################
# Script for installing Moodle v4.5.2 MariaDB, Apache2 and Php 8.3 on Ubuntu 24.04
# Authors: Henry Robert Muwanika

# Make a new file:
# sudo nano install_moodle.sh
# Place this content in it and then make the file executable:
# sudo chmod +x install_moodle.sh
# Execute the script to install Moodle:
# ./install_moodle.sh
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
# Install and configure Firewall
#--------------------------------------------------
sudo apt install -y ufw

sudo ufw allow 22/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow http
sudo ufw allow https
sudo ufw --force enable
sudo ufw reload

#--------------------------------------------------
# Set up the timezones
#--------------------------------------------------
# set the correct timezone on ubuntu
timedatectl set-timezone Africa/Kigali
timedatectl

#--------------------------------------------------
# Install Debian default database MariaDB 
#--------------------------------------------------
sudo apt install -y mariadb-server mariadb-client
sudo systemctl start mariadb.service
sudo systemctl enable mariadb.service

# sudo mariadb-secure-installation

# Configure Mariadb database
sed -i '/\[mysqld\]/a default_storage_engine = innodb' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/\[mysqld\]/a innodb_file_per_table = 1' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/\[mysqld\]/a innodb_large_prefix = 1' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/\[mysqld\]/a innodb_file_format = Barracuda' /etc/mysql/mariadb.conf.d/50-server.cnf

sudo systemctl restart mariadb.service

sudo mariadb -uroot --password="" -e "CREATE DATABASE moodledb DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mariadb -uroot --password="" -e "CREATE USER 'moodleuser'@'localhost' IDENTIFIED BY 'abc1234@';"
sudo mariadb -uroot --password="" -e "GRANT ALL PRIVILEGES ON moodledb.* TO 'moodleuser'@'localhost';"
sudo mariadb -uroot --password="" -e "FLUSH PRIVILEGES;"

sudo systemctl restart mariadb.service

#--------------------------------------------------
# Installation of PHP
#--------------------------------------------------
sudo apt install -y apache2 php php-common php-cli php-intl php-xmlrpc php-soap php-mysql php-zip php-gd php-tidy php-mbstring php-curl php-xml php-pear \
php-bcmath libapache2-mod-php php-pspell php-curl php-ldap php-soap unzip git curl libpcre3 libpcre3-dev graphviz aspell ghostscript clamav postfix \
php-gmp php-imagick php-fpm php-redis php-apcu php-opcache bzip2 zip unzip imagemagick ffmpeg libsodium23

sudo systemctl start apache2.service
sudo systemctl enable apache2.service

tee -a /etc/php/8.3/apache2/php.ini <<EOF
   file_uploads = On
   allow_url_fopen = On
   short_open_tag = On
   max_execution_time = 600
   memory_limit = 512M
   post_max_size = 500M
   upload_max_filesize = 500M
   max_input_time = 1000
   date.timezone = Africa/Kigali
EOF

sudo sed -i 's/.*max_input_vars =.*/max_input_vars = 6000/' /etc/php/8.3/apache2/php.ini
sudo sed -i 's/.*max_input_vars =.*/max_input_vars = 6000/' /etc/php/8.3/cli/php.ini

sudo systemctl restart apache2

#--------------------------------------------------
# Installation of Moodle
#--------------------------------------------------
cd /opt/
# wget https://download.moodle.org/download.php/direct/stable405/moodle-latest-405.tgz
wget https://download.moodle.org/download.php/direct/stable500/moodle-latest-500.tgz
tar xvf moodle-latest-500.tgz

cp -rf /opt/moodle/* /var/www/html

sudo mkdir -p /var/www/moodledata
sudo chown -R www-data:www-data /var/www/moodledata
sudo find /var/www/moodledata -type d -exec chmod 700 {} \; 
sudo find /var/www/moodledata -type f -exec chmod 600 {} \;

sudo chown -R www-data:www-data /var/www/html
sudo find /var/www/html -type d -exec chmod 755 {} \; 
sudo find /var/www/html -type f -exec chmod 644 {} \;

sudo mkdir -p /var/quarantine
sudo chown -R www-data:www-data /var/quarantine

sudo cat <<EOF > /etc/apache2/sites-available/moodle.conf

<VirtualHost *:80>
 DocumentRoot /var/www/html
 ServerName $WEBSITE_NAME
 ServerAlias www.$WEBSITE_NAME
 ServerAdmin admin@$WEBSITE_NAME
 
 <Directory /var/www/html>
 Options -Indexes +FollowSymLinks +MultiViews
 AllowOverride All
 Require all granted
 </Directory>

 ErrorLog \${APACHE_LOG_DIR}/error.log
 CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF

a2dissite 000-default.conf
sudo a2ensite moodle.conf
sudo apachectl configtest
sudo systemctl restart apache2

sudo a2enmod rewrite
sudo a2enmod ssl
sudo systemctl restart apache2

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
  
  sudo certbot --apache -d $WEBSITE_NAME --noninteractive --agree-tos --email $ADMIN_EMAIL --redirect
  
  sudo systemctl restart apache2
  
  echo "============ SSL/HTTPS is enabled! ========================"
else
  echo "==== SSL/HTTPS isn't enabled due to choice of the user or because of a misconfiguration! ======"
fi

rm /var/www/html/index.html

sudo apt install -y cron 
sudo systemctl enable cron
sudo systemctl start cron

sudo chmod -R 644 /var/www/html/config.php

sudo systemctl restart apache2

echo "Moodle installation is complete"
echo "Access moodle on https://$WEBSITE_NAME/install.php"

