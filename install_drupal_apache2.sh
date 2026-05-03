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
# Disable root login via SSH
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

sudo apt install -y php-cli php-fpm php-json php-common php-mysql php-zip php-gd php-intl php-mbstring php-curl php-xml php-pear php-tidy php-soap php-bcmath php-xmlrpc 

sudo pecl install uploadprogress

sudo cat <<EOF | sudo tee /etc/php/8.3/mods-available/uploadprogress.ini
; configuration for php uploadprogress module
; priority 15
extension=uploadprogress.so
EOF

sudo ln -s /etc/php/8.3/mods-available/uploadprogress.ini /etc/php/8.3/apache2/conf.d/15-uploadprogress.ini

sed -ie "s/\;date\.timezone\ =/date\.timezone\ =\ Africa\/Kigali/g" /etc/php/8.3/apache2/php.ini
sed -ie "s/max_execution_time = 30/max_execution_time = 300/" /etc/php/8.3/apache2/php.ini
sed -ie "s/max_input_time = 60/max_input_time = 1000/" /etc/php/8.3/apache2/php.ini
sed -ie "s/;max_input_vars = 1000/max_input_vars = 7000/" /etc/php/8.3/apache2/php.ini
sed -ie "s/error_reporting = E_ALL \& \~E_DEPRECATED/error_reporting = E_ALL \& \~E_NOTICE \& \~E_DEPRECATED/" /etc/php/8.3/apache2/php.ini
sed -ie "s/short_open_tag = Off/short_open_tag = On/" /etc/php/8.3/apache2/php.ini
sed -ie "s/upload_max_filesize = 2M/upload_max_filesize = 300M/" /etc/php/8.3/apache2/php.ini
sed -ie "s/post_max_size = 8M/post_max_size = 500M/" /etc/php/8.3/apache2/php.ini

sed -ie "s/memory_limit = 128M/memory_limit = 512M/" /etc/php/8.3/apache2/php.ini
sed -ie 's/;cgi.fix_pathinfo = 1/cgi.fix_pathinfo = 0/' /etc/php/8.3/apache2/php.ini
#sed -ie 's/;extension=pdo_pgsql/extension=pdo_pgsql/g' /etc/php/8.3/apache2/php.ini
#sed -ie 's/;extension=pgsql/extension=pgsql/g' /etc/php/8.3/apache2/php.ini


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

# Configure Mariadb database
sed -i '/\[mysqld\]/a default_storage_engine = innodb' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/\[mysqld\]/a innodb_file_per_table = 1' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/\[mysqld\]/a innodb_large_prefix = 1' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/\[mysqld\]/a innodb_file_format = Barracuda' /etc/mysql/mariadb.conf.d/50-server.cnf

sudo systemctl restart mariadb.service

sudo mariadb -uroot --password="" -e "CREATE DATABASE gstutor_dev;"
sudo mariadb -uroot --password="" -e "CREATE USER 'gstutor_dev'@'localhost' IDENTIFIED BY 'abc1234@';"
sudo mariadb -uroot --password="" -e "GRANT ALL ON gstutor_dev.* TO gstutor_dev@localhost WITH GRANT OPTION;"
sudo mariadb -uroot --password="" -e "FLUSH PRIVILEGES;"

sudo systemctl restart mariadb.service


echo "
#--------------------------------------------------
# Drupal installation
#--------------------------------------------------"
sudo mkdir /var/www/html/drupal
cd /opt && sudo wget https://ftp.drupal.org/files/projects/drupal-9.5.9.zip
sudo unzip drupal-9.5.9.zip 
sudo cp -rf drupal-9.5.9/* /var/www/html/drupal/

sudo chown -R www-data:www-data /var/www/html/drupal/
sudo chmod -R 755 /var/www/html/drupal/

cd /var/www/html/drupal
sudo -u www-data composer install --no-dev

sudo cat <<EOF > /etc/apache2/sites-available/drupal.conf

<VirtualHost *:80>
     ServerName example.com
     ServerAlias www.example.com
     ServerAdmin admin@example.com
     DocumentRoot /var/www/html/drupal/

     CustomLog ${APACHE_LOG_DIR}/access.log combined
     ErrorLog ${APACHE_LOG_DIR}/error.log

     <Directory /var/www/html/drupal/>
            Options FollowSymlinks
            AllowOverride All
            Require all granted
    </Directory>

    <Directory /var/www/html/drupal>
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

sudo chmod 644 /var/www/html/drupal/sites/default/settings.php
sudo nano /var/www/html/drupal/sites/default/settings.php

# sudo tee -a /var/www/html/drupal/sites/default/settings.php <<EOF
# $settings['trusted_host_patterns'] = ['192\.168\.1\.11'];
# EOF

sudo chmod 444 /var/www/html/drupal/sites/default/settings.php

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

# cd /usr/src
# mysqldump -u root -p gstutor_dev backup.sql
# mysql -u root -p
# use gstutor_dev;
# ALTER USER 'drupaluser'@'localhost' IDENTIFIED BY 'new_password';
