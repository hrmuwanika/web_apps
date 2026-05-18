#!/bin/bash

################################################################################
#  Requirements for installation of Bagisto ecommerce
#  Php: 8.4 or higher
#  Composer: latest
#  Database: MariaDB 10.3
#  Node.js: 24.x (for PWA)
#  NPM/Yarn: Latest
#  Web server: Nginx 
#  OS: Ubuntu 20.04, 22.04, 24.04
# 

# Make a new file:
# sudo nano install_laravel_bagisto.sh
# Place this content in it and then make the file executable:
# sudo chmod +x install_laravel_bagisto.sh
# Execute the script to install Bagisto:
# ./install_laravel_bagisto.sh
################################################################################

# Set to "True" to install certbot and have ssl enabled, "False" to use http
ENABLE_SSL="True"
# Set the website name
WEBSITE_NAME="example.com"
# Provide Email to register ssl certificate
ADMIN_EMAIL="info@example.com"

echo "
#--------------------------------------------------
# Updating the Ubuntu Server
#--------------------------------------------------"
sudo apt update && sudo apt upgrade -y
sudo apt autoremove -y

echo "
#----------------------------------------------------
# SSH authentication
#----------------------------------------------------"
sudo apt install -y openssh-server
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sudo systemctl restart ssh

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
# Set up the timezones
#--------------------------------------------------"
timedatectl set-timezone Africa/Kigali
timedatectl

echo "
#--------------------------------------------------
# Installation of PHP
#--------------------------------------------------"
sudo apt install -y curl gpg ca-certificates apt-transport-https software-properties-common lsb-release gnupg2 git unzip

sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

sudo apt install -y php8.5 php8.5-common php8.5-cli php8.5-opcache php8.5-mysql php8.5-xml php8.5-curl php8.5-zip php8.5-mbstring php8.5-gd php8.5-intl php8.5-bcmath \
php8.5-xml php-pear php8.5-fpm php8.5-pgsql php8.5-tokenizer 

sudo systemctl enable php8.5-fpm
sudo systemctl start php8.5-fpm

echo "
#------------------------------------------------
# Install composer
#------------------------------------------------"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === 'c8b085408188070d5f52bcfe4ecfbee5f727afa458b2573b8eaaf77b3419b0bf2768dc67c86944da1544f06fa544fd47') { echo 'Installer verified'.PHP_EOL; } else { echo 'Installer corrupt'.PHP_EOL; unlink('composer-setup.php'); exit(1); }"
php composer-setup.php
php -r "unlink('composer-setup.php');"

sudo mv composer.phar /usr/local/bin/composer

sudo apt autoremove apache2 -y

sed -ie "s/\;date\.timezone\ =/date\.timezone\ =\ Africa\/Kigali/g" /etc/php/8.5/cli/php.ini
sed -ie "s/max_execution_time = 30/max_execution_time = 360/" /etc/php/8.5/cli/php.ini
sed -ie "s/max_input_time = 60/max_input_time = 360/" /etc/php/8.5/fpm/php.ini
sed -ie "s/upload_max_filesize = 2M/upload_max_filesize = 110M/" /etc/php/8.5/fpm/php.ini
sed -ie "s/post_max_size = 8M/post_max_size = 100M/" /etc/php/8.5/fpm/php.ini
sed -ie "s/memory_limit = 128M/memory_limit = 512M/" /etc/php/8.5/cli/php.ini
sed -ie 's/;cgi.fix_pathinfo = 1/cgi.fix_pathinfo = 0/' /etc/php/8.5/cli/php.ini
sed -ie "s/error_reporting = E_ALL \& \~E_DEPRECATED/error_reporting = E_ALL \& \~E_NOTICE \& \~E_DEPRECATED/" /etc/php/8.5/fpm/php.ini
sed -ie 's/;extension=pdo_pgsql.so/extension=pdo_pgsql.so/g' /etc/php/8.5/cli/php.ini
sed -ie 's/;extension=pgsql.so/extension=pgsql.so/g' /etc/php/8.5/cli/php.ini

echo "
#--------------------------------------------------
# Installing PostgreSQL Server
#--------------------------------------------------"
# sudo apt install -y postgresql-16 postgresql-client postgresql-contrib php8.4-pgsql

# echo "=== Starting PostgreSQL service... ==="
# sudo systemctl start postgresql 
# sudo systemctl enable postgresql

# Create the new user with superuser privileges
# sudo -su postgres psql -c "CREATE USER laravel_user WITH PASSWORD 'abc1234@';"
# sudo -su postgres psql -c "CREATE DATABASE laravel_db;"
# sudo -su postgres psql -c "ALTER DATABASE laravel_db OWNER TO laravel_user;"
# sudo -su postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE laravel_db TO laravel_user;"

# sudo systemctl restart postgresql

#--------------------------------------------------
# Install Debian default database MariaDB 
#--------------------------------------------------
sudo apt install -y mariadb-server mariadb-client mariadb-backup
sudo systemctl start mariadb.service
sudo systemctl enable mariadb.service

# sudo mariadb-secure-installation

sudo systemctl restart mariadb.service

sudo mariadb -uroot --password="" -e "CREATE DATABASE laravel_db;"
sudo mariadb -uroot --password="" -e "CREATE USER 'laravel_user'@'localhost' IDENTIFIED BY 'abc1234@';"
sudo mariadb -uroot --password="" -e "GRANT ALL PRIVILEGES ON laravel_db.* TO 'laravel_user'@'localhost';"
sudo mariadb -uroot --password="" -e "FLUSH PRIVILEGES;"

sudo systemctl restart mariadb.service

echo "
#--------------------------------------------------
# Installation of Nodejs, Npm, Supervisor and Nginx
#--------------------------------------------------"
curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt update
sudo apt install nodejs npm -y

sudo apt install -y nginx
sudo systemctl start nginx.service
sudo systemctl enable nginx.service

echo "
#--------------------------------------------------
# Clone the Bagisto repository
#--------------------------------------------------"
cd /var/www/
git clone https://github.com/liberu-real-estate/real-estate-laravel.git
cd real-estate-laravel

composer install

sudo chown -R www-data:www-data /var/www/real-estate-laravel
sudo chmod -R 775 /var/www/real-estate-laravel/storage 

# Copy environment file
cp .env.example .env
#sed -i "s/DB_CONNECTION=sqlite/DB_CONNECTION=pgsql/g" .env
#sed -i "s/# DB_HOST=127.0.0.1/DB_HOST=127.0.0.1/g" .env
#sed -i "s/# DB_PORT=3306/DB_PORT=5432/g" .env
sed -i 's/DB_DATABASE=/DB_DATABASE=laravel_db/g' .env
sed -i 's/DB_USERNAME=/DB_USERNAME=laravel_user/g' .env
sed -i 's/DB_PASSWORD=/DB_PASSWORD=abc1234@/g' .env

# Generate application key
php artisan key:generate

# Edit .env with your database credentials, then:
php artisan migrate --seed

npm install && npm run build

# run migrations and seeders
# php artisan migrate
# php artisan db:seed
# php artisan vendor:publish --all
# php artisan serve --host=74.55.34.34 --port=8000

# Laravel queue worker using systemd
sudo cat<<EOF > /etc/systemd/system/laravel.service
[Unit]
Description=Laravel Application Server
After=network.target

[Service]
User=www-data
Group=www-data
Restart=always
WorkingDirectory=/var/www/real-estate-laravel
ExecStart=/usr/bin/php /var/www/real-estate-laravel/artisan queue:work --sleep=3 --tries=3
#ExecStart=/usr/bin/php artisan serve --host=0.0.0.0 --port=8000
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# start laravel as a service
sudo systemctl daemon-reload
sudo systemctl enable laravel.service
sudo systemctl start laravel.service

sudo cat > /etc/nginx/sites-available/laravel.conf <<'NGINX'
server {
    listen 80;
    listen [::]:80;
    server_name example.com;
    root /var/www/real-estate-laravel/public;

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";

    index index.php;

    charset utf-8;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;

    location ~ ^/index\.php(/|$) {
        fastcgi_pass unix:/var/run/php/php8.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $realpath_root$fastcgi_script_name;
        include fastcgi_params;
        fastcgi_hide_header X-Powered-By;
    }

    location ~ /\.(?!well-known).* {
        deny all;
    }
}
NGINX

sudo ln -s /etc/nginx/sites-available/laravel.conf /etc/nginx/sites-enabled/

sudo unlink /etc/nginx/sites-enabled/default
sudo rm /etc/nginx/sites-available/default
sudo rm /etc/nginx/sites-enabled/default

sudo nginx -t

sudo systemctl reload nginx

echo "
#--------------------------------------------------
# Generate SSL certificate
#--------------------------------------------------"
# sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt

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
  sudo apt install -y certbot python3-certbot-nginx
  sudo certbot --nginx -d $WEBSITE_NAME --noninteractive --agree-tos --email $ADMIN_EMAIL --redirect
    
  echo "============ SSL/HTTPS is enabled! ========================"
else
  echo "==== SSL/HTTPS isn't enabled due to choice of the user or because of a misconfiguration! ======"
fi

sudo systemctl restart nginx.service
sudo systemctl restart php8.4-fpm

echo "Laravel & Bagisto installation is complete"
echo "Access Laravel on https://$WEBSITE_NAME"

