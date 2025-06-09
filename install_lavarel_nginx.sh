#!/bin/bash

################################################################################
# Script for installing Laravel Postgresql, Nginx and Php 8.3 on Ubuntu 20.04, 22.04, 24.04
# Authors: Henry Robert Muwanika

# Make a new file:
# sudo nano install_laravel_nginx.sh
# Place this content in it and then make the file executable:
# sudo chmod +x install_laravel_nginx.sh
# Execute the script to install Laravel:
# ./install_laravel_nginx.sh
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
sudo apt update && sudo apt upgrade -y
sudo apt autoremove -y

echo "
#----------------------------------------------------
# Disabling password authentication
#----------------------------------------------------"
sudo apt install -y openssh-server
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sudo systemctl restart sshd

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

sudo apt install -y php8.3 php8.3-common php8.3-cli php8.3-intl php8.3-imap php8.3-xmlrpc php8.3-zip php8.3-gd php8.3-snmp php8.3-mbstring php8.3-curl php8.3-xml php-pear php8.3-mysqli \
php8.3-bcmath php8.3-ldap php8.3-soap unzip git curl php8.3-mysqli php8.3-gmp php8.3-imagick php8.3-fpm php8.3-redis php8.3-apcu imagemagick libpng-dev libjpeg-dev libtiff-dev 

sudo apt autoremove apache2 -y

sudo apt install -y nginx-full
sudo systemctl start nginx.service
sudo systemctl enable nginx.service

sed -ie "s/\;date\.timezone\ =/date\.timezone\ =\ Africa\/Kigali/g" /etc/php/8.3/fpm/php.ini
sed -ie "s/max_execution_time = 30/max_execution_time = 600/" /etc/php/8.3/fpm/php.ini
sed -ie "s/max_input_time = 60/max_input_time = 1000/" /etc/php/8.3/fpm/php.ini
sed -ie "s/;max_input_vars = 1000/max_input_vars = 7000/" /etc/php/8.3/fpm/php.ini
sed -ie "s/error_reporting = E_ALL \& \~E_DEPRECATED/error_reporting = E_ALL \& \~E_NOTICE \& \~E_DEPRECATED/" /etc/php/8.3/fpm/php.ini
sed -ie "s/short_open_tag = Off/short_open_tag = On/" /etc/php/8.3/fpm/php.ini
sed -ie "s/upload_max_filesize = 2M/upload_max_filesize = 500M/" /etc/php/8.3/fpm/php.ini
sed -ie "s/post_max_size = 8M/post_max_size = 500M/" /etc/php/8.3/fpm/php.ini
sed -ie "s/memory_limit = 128M/memory_limit = 512M/" /etc/php/8.3/fpm/php.ini
sed -ie 's/;extension=pdo_pgsql.so/extension=pdo_pgsql.so/g' /etc/php/8.3/fpm/php.ini
sed -ie 's/;extension=pgsql.so/extension=pgsql.so/g' /etc/php/8.3/fpm/php.ini

sudo systemctl restart php8.3-fpm

echo "
#--------------------------------------------------
# Installing PostgreSQL Server
#--------------------------------------------------"
# echo -e "=== Install and configure PostgreSQL ... ==="
# sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
# curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
# sudo apt update

# sudo apt -y install postgresql-16 postgresql-contrib php8.3-pgsql

# echo "=== Starting PostgreSQL service... ==="
# sudo systemctl start postgresql 
# sudo systemctl enable postgresql

# Create the new user with superuser privileges
# sudo -su postgres psql -c "CREATE USER lv_admin WITH PASSWORD 'abc1234@';"
# sudo -su postgres psql -c "CREATE DATABASE laravel_db;"
# sudo -su postgres psql -c "ALTER DATABASE laravel_db OWNER TO lv_admin;"
# sudo -su postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE laravel_db TO lv_admin;"

# sudo systemctl restart postgresql

#--------------------------------------------------
# Install Debian default database MariaDB 
#--------------------------------------------------
sudo apt install -y mariadb-server mariadb-client mariadb-backup
sudo systemctl start mariadb.service
sudo systemctl enable mariadb.service

# sudo mariadb-secure-installation

# Configure Mariadb database
sed -i '/\[mysqld\]/a default_storage_engine = innodb' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/\[mysqld\]/a innodb_file_per_table = 1' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/\[mysqld\]/a innodb_large_prefix = 1' /etc/mysql/mariadb.conf.d/50-server.cnf
sed -i '/\[mysqld\]/a innodb_file_format = Barracuda' /etc/mysql/mariadb.conf.d/50-server.cnf

sudo systemctl restart mariadb.service

sudo mariadb -uroot --password="" -e "CREATE DATABASE laravel_db;"
sudo mariadb -uroot --password="" -e "CREATE USER 'lv_admin'@'localhost' IDENTIFIED BY 'abc1234@';"
sudo mariadb -uroot --password="" -e "GRANT ALL PRIVILEGES ON laravel_db.* TO 'lv_admin'@'localhost';"
sudo mariadb -uroot --password="" -e "FLUSH PRIVILEGES;"

sudo systemctl restart mariadb.service


echo "
#--------------------------------------------------
# Installation of Laravel
#--------------------------------------------------"
curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
chmod +x /usr/local/bin/composer

cd /var/www/html
composer create-project --prefer-dist laravel/laravel laravel

chown -R :www-data /var/www/html/laravel
chmod -R 775 /var/www/html/laravel

cd laravel
php artisan key:generate

php artisan migrate

sudo cat <<EOF > /var/www/html/laravel/.env
APP_URL=http://laravel.example.com
LOG_CHANNEL=stack

DB_CONNECTION=mysql
DB_HOST=127.0.0.1
DB_PORT=3306
DB_DATABASE=laravel_db
DB_USERNAME=lv_admin
DB_PASSWORD=abc1234@
EOF

sudo cat <<EOF > /etc/nginx/conf.d/laravel.conf
server {
    listen 80;
    listen [::]:80;
    
    server_name laravel.example.com;
    root /var/www/html/laravel/public;
    
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";

    index index.html index.htm index.php;

    charset utf-8;
    
    location / {
       try_files \$uri \$uri/ /index.php?$args; 
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;
    
    location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
    
    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }

    location = /robots.txt {
        allow all;
        log_not_found off;
        access_log off;
    }	
    
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        expires max;
        log_not_found off;
    }	  
}
EOF

nginx -t

sudo systemctl restart nginx.service
sudo systemctl restart php8.3-fpm

echo "
#--------------------------------------------------
# Install and configure Firewall
#--------------------------------------------------"
sudo apt install -y ufw

sudo ufw allow 22/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow http
sudo ufw allow https

# Enable UFW
sudo ufw --force enable
sudo ufw reload

sudo apt install -y cron 
sudo systemctl enable cron
sudo systemctl start cron

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

echo "Laravel installation is complete"
echo "Access wordpress on https://$WEBSITE_NAME"


