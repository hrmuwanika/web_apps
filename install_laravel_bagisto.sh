#!/bin/bash

################################################################################
#  Requirements for installation of Bagisto ecommerce
#  Php: 8.2 or higher
#  Composer: latest
#  Database: MariaDB 10.3
#  Node.js: 18.x (for PWA)
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
timedatectl set-timezone Africa/Kigali
timedatectl

echo "
#--------------------------------------------------
# Installation of PHP
#--------------------------------------------------"
sudo apt install -y ca-certificates apt-transport-https software-properties-common lsb-release gnupg2

add-apt-repository ppa:ondrej/php
sudo apt update -y

sudo apt install -y php8.3-fpm php8.3-common php8.3-mysql php8.3-xml php8.3-xmlrpc php8.3-curl php8.3-gd php8.3-imagick php8.3-cli php8.3-dev php8.3-imap \
php8.3-mbstring php8.3-opcache php8.3-soap php8.3-zip php8.3-intl php8.3-bcmath unzip wget git curl

sudo apt autoremove apache2 -y

sudo apt install -y nginx-full
sudo systemctl start nginx.service
sudo systemctl enable nginx.service

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

# sudo apt -y install postgresql-16 postgresql-client postgresql-contrib php8.3-pgsql

# echo "=== Starting PostgreSQL service... ==="
# sudo systemctl start postgresql 
# sudo systemctl enable postgresql

# Create the new user with superuser privileges
# sudo -su postgres psql -c "CREATE USER bagisto_user WITH PASSWORD 'abc1234@';"
# sudo -su postgres psql -c "CREATE DATABASE bagisto_db;"
# sudo -su postgres psql -c "ALTER DATABASE bagisto_db OWNER TO bagisto_user;"
# sudo -su postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE bagisto_db TO bagisto_user;"

# sudo systemctl restart postgresql

#--------------------------------------------------
# Install Debian default database MariaDB 
#--------------------------------------------------
sudo apt install -y mariadb-server mariadb-client mariadb-backup
sudo systemctl start mariadb.service
sudo systemctl enable mariadb.service

# sudo mariadb-secure-installation

sudo systemctl restart mariadb.service

sudo mariadb -uroot --password="" -e "CREATE DATABASE bagisto_db;"
sudo mariadb -uroot --password="" -e "CREATE USER 'bagisto_user'@'localhost' IDENTIFIED BY 'abc1234@';"
sudo mariadb -uroot --password="" -e "GRANT ALL PRIVILEGES ON bagisto_db.* TO 'bagisto_user'@'localhost';"
sudo mariadb -uroot --password="" -e "FLUSH PRIVILEGES;"

sudo systemctl restart mariadb.service

echo "
#--------------------------------------------------
# Installation of Nodejs,Npm and composer
#--------------------------------------------------"
sudo apt install -y nodejs npm composer

cd /var/www/html
rm index*

echo "
#--------------------------------------------------
# Clone the Bagisto repository
#--------------------------------------------------"
git clone https://github.com/bagisto/bagisto.git 

sudo chown -R www-data:www-data /var/www/html/bagisto
sudo chmod -R 775 /var/www/html/bagisto/storage 

# Navigate to project directory
cd bagisto 

# Install php dependencies
composer install

# Copy environment file
cp .env.example .env
#sed -i "s/DB_CONNECTION=sqlite/DB_CONNECTION=pgsql/g" .env
#sed -i "s/# DB_HOST=127.0.0.1/DB_HOST=127.0.0.1/g" .env
#sed -i "s/# DB_PORT=3306/DB_PORT=5432/g" .env
sed -i 's/DB_DATABASE=/DB_DATABASE=bagisto_db/g' .env
sed -i 's/DB_USERNAME=/DB_USERNAME=bagisto_user/g' .env
sed -i 's/DB_PASSWORD=/DB_PASSWORD=abc1234@/g' .env
sed -i 's/QUEUE_CONNECTION=sync/QUEUE_CONNECTION=database/g' .env

# Generate application key
php artisan key:generate
sudo chmod -R 775 /var/www/html/bagisto/bootstrap/cache

php artisan bagisto:install

# run migrations and seeders
php artisan migrate
php artisan db:seed
php artisan vendor:publish --all
php artisan storage:link
# php artisan serve --host=74.55.34.34 --port=8000

# Laravel queue worker using systemd
sudo cat<<EOF > /etc/systemd/system/laravel.service
[Unit]
Description=Laravel WebSocket Server
After=network.target

[Service]
User=www-data
Group=www-data
Restart=always
WorkingDirectory=/var/www/html/bagisto
ExecStart=/usr/bin/php /var/www/html/bagisto/artisan queue:work --sleep=3 --tries=3

[Install]
WantedBy=multi-user.target
EOF

# start laravel as a service
systemctl daemon-reload
sudo systemctl enable laravel.service
sudo systemctl start laravel.service

sudo rm /etc/nginx/sites-available/default
sudo rm /etc/nginx/sites-enabled/default

sudo cat <<EOF > /etc/nginx/sites-available/laravel.conf
server {
    listen 80;
    listen [::]:80;
    server_name localhost;
    root /var/www/html/bagisto/public;                       # Path to your Laravel public directory

    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
    
    index index.php;
    charset utf-8;
     
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    error_page 404 /index.php;
    
    location ~ \.php\$ {
        fastcgi_pass localhost:8000;
        fastcgi_param SCRIPT_FILENAME \$realpath_root\$fastcgi_script_name;
        include fastcgi_params;
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
  sudo apt install -y certbot python3-certbot-nginx
  sudo certbot --nginx -d $WEBSITE_NAME --noninteractive --agree-tos --email $ADMIN_EMAIL --redirect
  
  sudo systemctl restart nginx
  
  echo "============ SSL/HTTPS is enabled! ========================"
else
  echo "==== SSL/HTTPS isn't enabled due to choice of the user or because of a misconfiguration! ======"
fi

sudo systemctl restart nginx

echo "Laravel installation is complete"
echo "Access Laravel on https://$WEBSITE_NAME"


