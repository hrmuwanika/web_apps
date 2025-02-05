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
sudo apt install ufw -y
sudo ufw enable -y
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw status

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
# innodb_large_prefix = 1
# innodb_file_per_table = 1
# innodb_file_format = Barracuda

sudo systemctl restart mysql.service

sudo mysql -uroot --password="" -e "CREATE DATABASE moodledb DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -uroot --password="" -e "CREATE USER 'moodleuser'@'localhost' IDENTIFIED BY 'abc1234!';"
sudo mysql -uroot --password="" -e "GRANT ALL PRIVILEGES ON moodledb.* TO 'moodleuser'@'localhost';"
sudo mysql -uroot --password="" -e "FLUSH PRIVILEGES;"

sudo systemctl restart mysql.service

#--------------------------------------------------
# Installation of PHP
#--------------------------------------------------
sudo apt install -y apache2 php php-common php-cli php-intl php-xmlrpc php-soap php-mysql php-zip php-gd php-tidy php-mbstring php-curl php-xml php-pear \
php-bcmath libapache2-mod-php php-pspell php-curl php-ldap php-soap unzip git curl libpcre3 libpcre3-dev graphviz

sudo systemctl start apache2.service
sudo systemctl enable apache2.service
   
# sudo nano /etc/php/8.3/apache2/php.ini
  # memory_limit = 256M
  # upload_max_filesize = 100M
  # max_execution_time = 360
  # date.timezone = Africa/Kigali
  # max_input_vars = 5000

sudo systemctl restart apache2

#--------------------------------------------------
# Installation of Moodle
#--------------------------------------------------
cd /var/www/
wget https://download.moodle.org/download.php/direct/stable405/moodle-latest-405.tgz
tar xvf moodle-latest-405.tgz

sudo mkdir -p /var/www/moodledata
sudo chown -R www-data:www-data /var/www/html/moodle /var/www/moodledata
sudo chmod u+rwx /var/www/html/moodle /var/www/moodledata

sudo mkdir -p /var/quarantine
sudo chown -R www-data /var/quarantine

sudo a2enmod rewrite

sudo nano /etc/apache2/sites-available/moodle.conf

#########################################################################

<VirtualHost *:80>
 DocumentRoot /var/www/html/moodle/
 ServerName moodle.example.com
 ServerAdmin admin@example.com
 
 <Directory /var/www/html/moodle/>
 Options +FollowSymlinks
 AllowOverride All
 Require all granted
 </Directory>

 ErrorLog /var/log/apache2/moodle_error.log
 CustomLog /var/log/apache2/moodle_access.log combined
</VirtualHost>

#########################################################################

sudo a2ensite moodle.conf
sudo apachectl configtest

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
  
  echo "\n============ SSL/HTTPS is enabled! ========================"
else
  echo "\n==== SSL/HTTPS isn't enabled due to choice of the user or because of a misconfiguration! ======"
fi

echo -e "Access moodle https://$WEBSITE_NAME/moodle/install.php"


