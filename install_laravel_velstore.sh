#!/bin/bash

################################################################################
# Script for installing Laravel Postgresql, Nginx and Php 8.3 on Ubuntu 20.04, 22.04, 24.04
# Authors: Henry Robert Muwanika

# Make a new file:
# sudo nano install_laravel_velstore.sh
# Place this content in it and then make the file executable:
# sudo chmod +x install_laravel_velstore.sh
# Execute the script to install Laravel:
# ./install_laravel_velstore.sh
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
add-apt-repository ppa:ondrej/php
sudo apt update -y

sudo apt install -y php8.3 php8.3-common php8.3-cli php8.3-intl php8.3-imap php8.3-xmlrpc php8.3-zip php8.3-gd php8.3-mbstring php8.3-curl php8.3-xml php-pear  \
php8.3-bcmath php8.3-ldap php8.3-soap php8.3-fpm unzip wget git curl php8.3-mysqli php8.3-imagick php8.3-redis php8.3-apcu imagemagick 

sudo apt autoremove apache2 -y

sudo apt install -y nginx-full
sudo systemctl start nginx.service
sudo systemctl enable nginx.service

sudo systemctl start php8.3-fpm.service
sudo systemctl enable php8.3-fpm.service

sed -ie "s/\;date\.timezone\ =/date\.timezone\ =\ Africa\/Kigali/g" /etc/php/8.3/cli/php.ini
sed -ie "s/max_execution_time = 30/max_execution_time = 360/" /etc/php/8.3/cli/php.ini
sed -ie "s/memory_limit = 128M/memory_limit = 1G/" /etc/php/8.3/cli/php.ini
sed -ie 's/;cgi.fix_pathinfo = 1/cgi.fix_pathinfo = 0/' /etc/php/8.3/cli/php.ini
sed -ie 's/;extension=pdo_pgsql.so/extension=pdo_pgsql.so/g' /etc/php/8.3/cli/php.ini
sed -ie 's/;extension=pgsql.so/extension=pgsql.so/g' /etc/php/8.3/cli/php.ini

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
# sudo -su postgres psql -c "CREATE USER velstore_user WITH PASSWORD 'abc1234@';"
# sudo -su postgres psql -c "CREATE DATABASE velstore_db;"
# sudo -su postgres psql -c "ALTER DATABASE velstore_db OWNER TO velstore_user;"
# sudo -su postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE velstore_db TO velstore_user;"

# sudo systemctl restart postgresql

#--------------------------------------------------
# Install Debian default database MariaDB 
#--------------------------------------------------
sudo apt install -y mariadb-server mariadb-client mariadb-backup
sudo systemctl start mariadb.service
sudo systemctl enable mariadb.service

# sudo mariadb-secure-installation

sudo systemctl restart mariadb.service

sudo mariadb -uroot --password="" -e "CREATE DATABASE velstore_db;"
sudo mariadb -uroot --password="" -e "CREATE USER 'velstore_user'@'localhost' IDENTIFIED BY 'abc1234@';"
sudo mariadb -uroot --password="" -e "GRANT ALL PRIVILEGES ON velstore_db.* TO 'velstore_user'@'localhost';"
sudo mariadb -uroot --password="" -e "FLUSH PRIVILEGES;"

sudo systemctl restart mariadb.service

echo "
#--------------------------------------------------
# Installation of Nodejs, Npm and composer
#--------------------------------------------------"
sudo apt install -y nodejs npm composer

cd /var/www/html
rm index*

echo "
#--------------------------------------------------
# Installation of Velstore
#--------------------------------------------------"
composer create-project velstorelabs/velstore 

sudo chown -R www-data:www-data /var/www/html/velstore
sudo chmod -R 775 /var/www/html/velstore/storage 
sudo chmod -R 775 /var/www/html/velstore/bootstrap/cache

cd velstore
cp .env.example .env

sed -i 's/DB_DATABASE=/DB_DATABASE=velstore_db/g' .env
sed -i 's/DB_USERNAME=/DB_USERNAME=velstore_user/g' .env
sed -i 's/DB_PASSWORD=/DB_PASSWORD=abc1234@/g' .env

php artisan install:velstore --with-import
# php artisan serve --host=74.55.34.34 --port=8000

# Laravel queue worker using systemd
sudo cat<<EOF > /etc/systemd/system/velstore.service
[Unit]
Description=Laravel queue worker

[Service]
User=www-data
Group=www-data
Restart=on-failure
ExecStart=/usr/bin/php /var/www/html/velstore/artisan queue:work --daemon --env=production

[Install]
WantedBy=multi-user.target
EOF

# start laravel as a service
systemctl daemon-reload
sudo systemctl enable velstore.service
sudo systemctl start velstore.service

sudo rm /etc/nginx/sites-available/default
sudo rm /etc/nginx/sites-enabled/default

sudo cat <<EOF > /etc/nginx/sites-available/laravel.conf
server {
    listen 80;
    listen [::]:80;
    server_name example.com;
    root /var/www/html/velstore/public;                       # Path to your Laravel public directory

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    index index.php;
    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~* ^\/(?!cache).*\.(?:jpg|jpeg|gif|png|ico|cur|gz|svg|svgz|mp4|ogg|ogv|webm|htc|webp|woff|woff2)$ {
      expires max;
      access_log off;
      add_header Cache-Control "public";
    }
    
    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }
 
    error_page 404 /index.php;

    location ~ ^/index\.php(/|\$) {
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_hide_header X-Powered-By;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/laravel.conf /etc/nginx/sites-enabled/
nginx -t

sudo systemctl restart nginx.service

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
sudo systemctl restart php8.3-fpm
echo "Velstore installation is complete"
echo "Access Laravel on https://$WEBSITE_NAME"


