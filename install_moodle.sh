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

# Variables
# Set to "True" to install certbot and have ssl enabled, "False" to use http
ENABLE_SSL="True"
# Set the website name
WEBSITE_NAME="example.com"
# Provide Email to register ssl certificate
ADMIN_EMAIL="moodle@example.com"
PHP_VERSION="8.3"

#----------------------------------------------------
# Disabling password authentication
#----------------------------------------------------
echo "Disabling password authentication ... "
sudo sed -i 's/#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config 
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo service sshd restart
#
#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo "============= Update Server ================"
sudo apt update && sudo apt upgrade -y
sudo apt autoremove && sudo apt autoclean -y

#--------------------------------------------------
# Install and configure Firewall
#--------------------------------------------------
sudo apt install ufw -y
ufw default allow outgoing
ufw default deny incoming
sudo ufw allow OpenSSH
sudo ufw allow 'Apache Full'
ufw enable -y

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

# sudo mysql_secure_installation

# Configure Mariadb database
sed -i '/\[mysqld\]/a default_storage_engine = innodb' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/\[mysqld\]/a innodb_file_per_table = 1' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/\[mysqld\]/a innodb_large_prefix = 1' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/\[mysqld\]/a innodb_file_format = Barracuda' /etc/mysql/mariadb.conf.d/50-server.cnf

sudo systemctl restart mysql.service

sudo mysql -uroot --password="" -e "CREATE DATABASE moodledb DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -uroot --password="" -e "CREATE USER 'moodleuser'@'localhost' IDENTIFIED BY 'abc1234!';"
sudo mysql -uroot --password="" -e "GRANT ALL PRIVILEGES ON moodledb.* TO 'moodleuser'@'localhost';"
sudo mysql -uroot --password="" -e "FLUSH PRIVILEGES;"

sudo systemctl restart mysql.service

#--------------------------------------------------
# Installation of PHP
#--------------------------------------------------
sudo apt install -y software-properties-common ca-certificates lsb-release apt-transport-https 

sudo apt install -y apache2 libapache2-mod-php php php-gmp php-bcmath php-gd php-json php-mysql php-curl php-mbstring php-intl php-imagick php-xml \
php-zip php-fpm php-redis php-apcu php-opcache php-ldap php-soap bzip2 imagemagick ffmpeg libsodium23 php-common php-cli php-tidy php-pear php-pspell \
php-mysqlnd

sudo apt install -y unzip git curl libpcre3 libpcre3-dev graphviz aspell ghostscript clamav

a2enconf php8.3-fpm
a2dismod php8.3
a2dismod mpm_prefork
a2enmod mpm_event

sudo systemctl enable apache2.service
sudo systemctl start apache2.service
sudo systemctl enable php8.3-fpm.service
sudo systemctl start php8.3-fpm.service

# Configure PHP
echo "=== Configuring PHP... ==="
sudo sed -i "s/.memory_limit =.*/memory_limit = 512M/" /etc/php/${PHP_VERSION}/apache2/php.ini
sudo sed -i "s/.max_execution_time =.*/max_execution_time = 360/" /etc/php/${PHP_VERSION}/apache2/php.ini
sudo sed -i "s/.*max_input_vars =.*/max_input_vars = 7000/" /etc/php/${PHP_VERSION}/apache2/php.ini
sudo sed -i "s/.*upload_max_filesize =.*/upload_max_filesize = 500M/" /etc/php/${PHP_VERSION}/apache2/php.ini
sudo sed -i "s/.*post_max_size =.*/post_max_size = 500M/" /etc/php/${PHP_VERSION}/apache2/php.ini
sudo sed -i "s/^date.timezone=.*/date.timezone = Africa/Kigali/" /etc/php/${PHP_VERSION}/apache2/php.ini

sudo systemctl restart apache2

#--------------------------------------------------
# Installation of Moodle
#--------------------------------------------------
cd /opt
wget https://download.moodle.org/download.php/direct/stable405/moodle-4.5.2.tgz
tar xvf moodle-4.5.2.tgz

sudo cp -R /opt/moodle /var/www/html/

sudo mkdir -p /var/www/moodledata
sudo chown -R www-data:www-data /var/www/html/
sudo chown -R www-data:www-data /var/www/moodledata/
sudo chmod -R 777 /var/www/moodledata/ 
sudo chmod -R 777 /var/www/html/

sudo mkdir -p /var/quarantine
sudo chown -R www-data:www-data /var/quarantine

sudo cat <<EOF > /etc/apache2/sites-available/moodle.conf 

#########################################################################

<VirtualHost *:80>
 DocumentRoot /var/www/html/
 ServerName $WEBSITE_NAME
 ServerAlias www.$WEBSITE_NAME
 ServerAdmin admin@$WEBSITE_NAME
 
 <Directory /var/www/html/>
 Options -Indexes +FollowSymLinks +MultiViews
 AllowOverride All
 Require all granted
 </Directory>

 ErrorLog ${APACHE_LOG_DIR}/error.log
 CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>

#########################################################################
EOF

sudo a2dissite 000-default.conf
sudo a2ensite moodle.conf
sudo a2enmod rewrite

apachectl -t
sudo systemctl reload apache2

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

sudo systemctl restart apache2

echo "Moodle installation is complete"
echo "Access moodle on https://$WEBSITE_NAME/install.php"


