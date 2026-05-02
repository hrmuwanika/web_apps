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
sudo add-apt-repository ppa:ondrej/php
sudo apt update


sudo apt install -y apache2 mysql-server mysql-client 
sudo apt install -y libapache2-mod-php8.3 php8.3 php8.3-common php8.3-cli php8.3-intl php8.3-xmlrpc php8.3-zip php8.3-gd php8.3-tidy php8.3-mbstring php8.3-curl \
php8.3-dev php8.3-bcmath php8.3-pspell php8.3-ldap php8.3-soap php8.3-gmp php8.3-imagick php8.3-redis php8.3-apcu php8.3-mysql php8.3-xml php-pear

sudo systemctl enable mysql.service
sudo systemctl start mysql.service 

sudo pecl install uploadprogress

sed -ie "s/\;date\.timezone\ =/date\.timezone\ =\ Africa\/Kigali/g" /etc/php/8.3/apache2/php.ini
sed -ie "s/max_execution_time = 30/max_execution_time = 600/" /etc/php/8.3/apache2/php.ini
sed -ie "s/max_input_time = 60/max_input_time = 1000/" /etc/php/8.3/apache2/php.ini
sed -ie "s/;max_input_vars = 1000/max_input_vars = 7000/" /etc/php/8.3/apache2/php.ini
sed -ie "s/error_reporting = E_ALL \& \~E_DEPRECATED/error_reporting = E_ALL \& \~E_NOTICE \& \~E_DEPRECATED/" /etc/php/8.3/apache2/php.ini
sed -ie "s/short_open_tag = Off/short_open_tag = On/" /etc/php/8.3/apache2/php.ini
sed -ie "s/upload_max_filesize = 2M/upload_max_filesize = 500M/" /etc/php/8.3/apache2/php.ini
sed -ie "s/post_max_size = 8M/post_max_size = 500M/" /etc/php/8.3/apache2/php.ini
sed -ie "s/memory_limit = 128M/memory_limit = 512M/" /etc/php/8.3/apache2/php.ini
sed -ie 's/;cgi.fix_pathinfo = 1/cgi.fix_pathinfo = 0/' /etc/php/8.3/apache2/php.ini
#sed -ie 's/;extension=pdo_pgsql/extension=pdo_pgsql/g' /etc/php/8.3/apache2/php.ini
#sed -ie 's/;extension=pgsql/extension=pgsql/g' /etc/php/8.3/apache2/php.ini

sudo tee -a /etc/php/8.3/apache2/php.ini <<EOF
   extension=uploadprogress
   extension=php_openssl
EOF

sudo mysql_secure_installation

sudo mysql -u root -p

## Creating New User for Drupal Database ##
CREATE USER 'drupaluser'@'localhost' IDENTIFIED BY 'abc1234@';

## Create New Database ##
create database gstutor_dev DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

## Grant Privileges to Database ##
GRANT ALL PRIVILEGES ON gstutor_dev.* TO 'drupaluser'@'localhost';

## FLUSH privileges ##
FLUSH PRIVILEGES;

## Exit ##
exit


echo "
#--------------------------------------------------
# Drupal installation
#--------------------------------------------------"
sudo mkdir /var/www/html/drupal

cd /opt && wget https://ftp-origin.drupal.org/files/projects/drupal-10.3.3.tar.gz
sudo tar xzvf drupal-10.3.3.tar.gz -C /var/www/html/drupal --strip-components=1

sudo chown -R www-data:www-data /var/www/html/drupal/
sudo chmod -R 755 /var/www/html/drupal/

sudo nano /etc/apache2/sites-available/drupal.conf

#####################################################################################################################################################

<VirtualHost *:80>
     ServerName example.com
     ServerAlias www.example.com
     ServerAdmin admin@example.com

     DocumentRoot /var/www/html/drupal/

     CustomLog ${APACHE_LOG_DIR}/access.log combined
     ErrorLog ${APACHE_LOG_DIR}/error.log

      <Directory /var/www/html/drupal>
            Options Indexes FollowSymLinks
            AllowOverride All
            Require all granted
            RewriteEngine on
            RewriteBase /
            RewriteCond %{REQUEST_FILENAME} !-f
            RewriteCond %{REQUEST_FILENAME} !-d
            RewriteRule ^(.*)$ index.php?q=$1 [L,QSA]
      </Directory>
</VirtualHost>

###################################################################################################################################################

sudo a2ensite drupal.conf
sudo a2enmod rewrite

sudo systemctl restart apache2



################################################################################

#cd /usr/src
#mysqldump -u root -p gstutor_dev backup.sql
#mysql -u root -p
#use gstutor_dev;
#ALTER USER 'drupaluser'@'localhost' IDENTIFIED BY 'new_password';
