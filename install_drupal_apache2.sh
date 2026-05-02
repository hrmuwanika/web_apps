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
sudo ufw allow "Apache Full"
sudo ufw allow 22/tcp

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

sudo apt install -y apache2 

sudo systemctl is-enabled apache2.service
sudo systemctl status apache2.service

sudo apt install -y mysql-server mysql-client 
sudo apt install -y libapache2-mod-php8.3 php8.3 php8.3-common php8.3-cli php8.3-intl php8.3-xmlrpc php8.3-zip php8.3-gd php8.3-tidy php8.3-mbstring php8.3-curl \
php8.3-dev php8.3-bcmath php8.3-pspell php8.3-ldap php8.3-soap php8.3-gmp php8.3-imagick php8.3-redis php8.3-apcu php8.3-mysql php8.3-xml php-pear

sudo systemctl is-enabled mysql.service
sudo systemctl status mysql.service

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

sudo mysql_secure_installation

sudo mysql -u root -p
CREATE USER 'gstutor_dev'@'localhost' IDENTIFIED BY 'abc1234@';
CREATE database gstutor_dev;
GRANT ALL ON gstutor_dev.* TO 'gstutor_dev'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
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

cd /var/www/html/drupal
sudo -u www-data composer install --no-dev

sudo nano /etc/apache2/sites-available/drupal.conf

#####################################################################################################################################################

<VirtualHost *:80>

    ServerName howtoforge.local
    ServerAdmin admin@howtoforge.local

    ErrorLog ${APACHE_LOG_DIR}/howtoforge.local.error.log
    CustomLog ${APACHE_LOG_DIR}/howtoforge.local.access.log combined

</VirtualHost>

<IfModule mod_ssl.c>

    <VirtualHost _default_:80>

        ServerName example.com
        ServerAdmin admin@example.com
        DocumentRoot /var/www/html/drupal

        # Add security
        php_flag register_globals off

        ErrorLog ${APACHE_LOG_DIR}/example.com.error.log
        CustomLog ${APACHE_LOG_DIR}/example.com.access.log combined

        <FilesMatch "\.(cgi|shtml|phtml|php)$">
                SSLOptions +StdEnvVars
        </FilesMatch>

        <Directory /var/www/html/drupal>
                Options FollowSymlinks
                #Allow .htaccess
                AllowOverride All
                Require all granted
                <IfModule security2_module>
                        SecRuleEngine Off
                        # or disable only problematic rules
                </IfModule>
        </Directory>

        <Directory /var/www/html/drupal/>
            RewriteEngine on
            RewriteBase /
            RewriteCond %{REQUEST_FILENAME} !-f
            RewriteCond %{REQUEST_FILENAME} !-d
            RewriteRule ^(.*)$ index.php?q=$1 [L,QSA]
        </Directory>

    </VirtualHost>

</IfModule>

###################################################################################################################################################

sudo a2enmod rewrite ssl headers deflate
sudo a2ensite drupal.conf
sudo apachectl configtest

sudo systemctl restart apache2

################################################################################

sudo chmod 644 /var/www/html/drupal/sites/default/settings.php
sudo nano /var/www/html/drupal/sites/default/settings.php

tee -a /var/www/html/drupal/sites/default/settings.php <<EOF
$settings['trusted_host_patterns'] = ['192\.168\.1\.11'];
EOF

sudo chmod 444 /var/www/html/drupal/sites/default/settings.php

# cd /usr/src
# mysqldump -u root -p gstutor_dev backup.sql
# mysql -u root -p
# use gstutor_dev;
# ALTER USER 'drupaluser'@'localhost' IDENTIFIED BY 'new_password';
