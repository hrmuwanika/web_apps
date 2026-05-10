#!/bin/bash

# Ubuntu 20.04, MySQL 5.7.27, 

# Set to "True" to install certbot and have ssl enabled, "False" to use http
ENABLE_SSL="True"
# Set the website name
WEBSITE_NAME="example.com"
# Provide Email to register ssl certificate
ADMIN_EMAIL="info@example.com"

echo "
#--------------------------------------------------
# Update system
#--------------------------------------------------"
sudo apt update && sudo apt upgrade -y
sudo apt autoremove -y

echo "
#--------------------------------------------------
#  Configure UFW to allow web traffic and SSH
#--------------------------------------------------"
sudo apt install -y ufw
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable UFW
sudo ufw --force enable
sudo ufw reload

echo "
#--------------------------------------------------
# Enable root login via SSH
#--------------------------------------------------"
sudo apt install -y openssh-server
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sudo systemctl restart ssh

echo "
#--------------------------------------------------
# Generate SSH key pairs
#--------------------------------------------------"
# ssh-keygen -t rsa -b 4096


sudo apt install -y ca-certificates apt-transport-https software-properties-common

sudo apt install -y apache2 libapache2-mod-php
sudo apt install -y unzip
sudo systemctl is-enabled apache2.service
sudo systemctl status apache2.service

sudo apt install -y php8.4 php8.4-common php8.4-cli php8.4-intl php8.4-xmlrpc php8.4-zip php8.4-gd php8.4-tidy php8.4-mbstring php8.4-curl php-pear \
php8.4-dev php8.4-bcmath php8.4-pspell php8.4-ldap php8.4-soap php8.4-gmp php8.4-imagick php8.4-fpm php8.4-redis php8.4-apcu php8.4-mysql php8.4-xml 

sudo apt install -y build-essential  bzip2 imagemagick composer libsodium23 fail2ban libpng-dev libjpeg-dev libtiff-dev postfix curl unzip git

sudo systemctl start fail2ban
sudo systemctl enable fail2ban

sudo pecl install uploadprogress

sudo cat <<EOF | sudo tee /etc/php/8.4/mods-available/uploadprogress.ini
; configuration for php uploadprogress module
; priority 15
extension=uploadprogress.so
EOF

sudo ln -s /etc/php/8.4/mods-available/uploadprogress.ini /etc/php/8.4/apache2/conf.d/15-uploadprogress.ini

sed -ie "s/\;date\.timezone\ =/date\.timezone\ =\ Africa\/Kigali/g" /etc/php/8.4/apache2/php.ini
sed -ie "s/max_execution_time = 30/max_execution_time = 300/" /etc/php/8.4/apache2/php.ini
sed -ie "s/max_input_time = 60/max_input_time = 1000/" /etc/php/8.4/apache2/php.ini
sed -ie "s/;max_input_vars = 1000/max_input_vars = 7000/" /etc/php/8.4/apache2/php.ini
sed -ie "s/error_reporting = E_ALL \& \~E_DEPRECATED/error_reporting = E_ALL \& \~E_NOTICE \& \~E_DEPRECATED/" /etc/php/8.4/apache2/php.ini
sed -ie "s/short_open_tag = Off/short_open_tag = On/" /etc/php/8.4/apache2/php.ini
sed -ie "s/upload_max_filesize = 2M/upload_max_filesize = 300M/" /etc/php/8.4/apache2/php.ini
sed -ie "s/post_max_size = 8M/post_max_size = 500M/" /etc/php/8.4/apache2/php.ini

sed -ie "s/memory_limit = 128M/memory_limit = 512M/" /etc/php/8.4/apache2/php.ini
sed -ie 's/;cgi.fix_pathinfo = 1/cgi.fix_pathinfo = 0/' /etc/php/8.4/apache2/php.ini
#sed -ie 's/;extension=pdo_pgsql/extension=pdo_pgsql/g' /etc/php/8.4/apache2/php.ini
#sed -ie 's/;extension=pgsql/extension=pgsql/g' /etc/php/8.4/apache2/php.ini

echo "
#------------------------------------------------
# Install composer
#------------------------------------------------"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === 'c8b085408188070d5f52bcfe4ecfbee5f727afa458b2573b8eaaf77b3419b0bf2768dc67c86944da1544f06fa544fd47') { echo 'Installer verified'.PHP_EOL; } else { echo 'Installer corrupt'.PHP_EOL; unlink('composer-setup.php'); exit(1); }"
php composer-setup.php
php -r "unlink('composer-setup.php');"

sudo mv composer.phar /usr/local/bin/composer

echo "
#--------------------------------------------------
# Mariadb Installation
#--------------------------------------------------"
sudo apt install -y mariadb-server mariadb-client
sudo systemctl start mariadb.service
sudo systemctl enable mariadb.service

# sudo mariadb-secure-installation

sudo mariadb -uroot --password="" -e "CREATE DATABASE drupal_db;"
sudo mariadb -uroot --password="" -e "CREATE USER 'dbadmin'@'localhost' IDENTIFIED BY 'abc1234@';"
sudo mariadb -uroot --password="" -e "GRANT ALL ON drupal_db.* TO dbadmin@localhost WITH GRANT OPTION;"
sudo mariadb -uroot --password="" -e "FLUSH PRIVILEGES;"

sudo systemctl restart mariadb.service


echo "
#--------------------------------------------------
# Drupal installation
#--------------------------------------------------"
cd /opt && wget https://ftp.drupal.org/files/projects/drupal-11.3.9.tar.gz 
tar -zxvf drupal-11.3.9.tar.gz

mkdir /var/www/drupal
sudo cp -rf drupal-11.3.9/* /var/www/drupal
sudo chown -R www-data:www-data /var/www/drupal/
sudo chmod -R 755 /var/www/drupal/

cd /var/www/drupal
sudo -u www-data composer install --no-dev

sudo cat <<EOF > /etc/apache2/sites-available/drupal.conf

<VirtualHost *:80>
     ServerName \$WEBSITE_NAME
     DocumentRoot /var/www/drupal/

     CustomLog ${APACHE_LOG_DIR}/access.log combined
     ErrorLog ${APACHE_LOG_DIR}/error.log

     <Directory /var/www/drupal/>
            Options FollowSymlinks
            AllowOverride All
            Require all granted
    </Directory>

    <Directory /var/www/drupal>
            RewriteEngine on
            RewriteBase /
            RewriteCond %{REQUEST_FILENAME} !-f
            RewriteCond %{REQUEST_FILENAME} !-d
            RewriteRule ^(.*)$ index.php?q=$1 [L,QSA]
   </Directory>
</VirtualHost>
EOF

sudo apachectl configtest

sudo a2dismod mpm_event
sudo a2enmod mpm_prefork
sudo sudo a2enmod php8.3
sudo a2enmod rewrite ssl headers deflate

sudo a2ensite drupal.conf
systemctl restart apache2

sudo a2dissite 000-default.conf
sudo rm /var/www/html/index.html

sudo chmod 644 /var/www/drupal/sites/default/settings.php
# sudo chmod 444 /var/www/drupal/sites/default/settings.php

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
  sudo apt install -y python3-certbot-apache
  sudo certbot --apache -d $WEBSITE_NAME --noninteractive --agree-tos --email $ADMIN_EMAIL --redirect
  
  sudo systemctl restart nginx
  
  echo "============ SSL/HTTPS is enabled! ========================"
else
  echo "==== SSL/HTTPS isn't enabled due to choice of the user or because of a misconfiguration! ======"
fi

# nano /var/www/drupal/sites/default/settings.php
# $settings['trusted_host_patterns'] = ['192\.168\.1\.13'];

echo "Drupal setup completed successfully."

# cd /var/www/drupal/
# composer create-project drupal/cms
