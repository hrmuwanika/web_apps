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
add-apt-repository ppa:ondrej/php
sudo apt update -y

sudo apt install -y php8.3 php8.3-common php8.3-cli php8.3-intl php8.3-imap php8.3-xmlrpc php8.3-zip php8.3-gd php8.3-mbstring php8.3-curl php8.3-xml php-pear  \
php8.3-bcmath php8.3-ldap php8.3-soap unzip wget git curl php8.3-mysqli php8.3-imagick php8.3-redis php8.3-apcu imagemagick 

sudo apt autoremove apache2 -y

sudo apt install -y nginx-full
sudo systemctl start nginx.service
sudo systemctl enable nginx.service

sed -ie "s/\;date\.timezone\ =/date\.timezone\ =\ Africa\/Kigali/g" /etc/php/8.3/cli/php.ini
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
sudo apt install -y composer
composer --version

cd /var/www/html
composer create-project laravel/laravel myproject

cd myproject 
sudo chown -R www-data:www-data /var/www/html/myproject 
sudo chmod -R 775 /var/www/html/myproject/storage 
sudo chmod -R 775 /var/www/html/myproject/bootstrap/cache

sudo cat <<EOF > /etc/nginx/sites-available/lavarel.conf
server {
    listen 80;
    listen 80
    server_name example.com;                            # Replace with your domain(s)

    root /var/www/html/myproject/public;                # Path to your Laravel public directory

    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
    }

    location ~ \.php\$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;                                 # Use your PHP-FPM socket path
        # OR fastcgi_pass 127.0.0.1:8000;                                           # If using TCP port
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    # Optional: Deny access to .env file for security
    location ~ /\.env {
        deny all;
    }

    # Optional: Deny access to other sensitive files/directories
    location ~ /storage/logs/laravel\.log {
        deny all;
    }

    # Optional: Serve static assets directly from Nginx
    location ~* \.(jpg|jpeg|gif|png|css|js|ico|xml)$ {
        expires 5M;
        log_not_found off;
    }
}
EOF

sudo ln -s /etc/nginx/sites-available/lavarel.conf /etc/nginx/sites-enabled/
nginx -t

sudo systemctl restart nginx.service

cd /var/www/html/myproject
php artisan key:generate

sudo nano /var/www/html/myproject/.env
# paste the following
# APP_URL=http://example.com
# LOG_CHANNEL=stack
# DB_CONNECTION=mysql | pgsql
# DB_HOST=127.0.0.1
# DB_PORT=3306 | 5432
# DB_DATABASE=laravel_db
# DB_USERNAME=lv_admin
# DB_PASSWORD=abc1234@

php artisan migrate
php artisan config:clear
php artisan cache:clear
php artisan route:clear
# php artisan serve 

# Laravel queue worker using systemd
sudo cat<<EOF > /etc/systemd/system/laravel.service
[Unit]
Description=Laravel queue worker

[Service]
User=www-data
Group=www-data
Restart=on-failure
ExecStart=/usr/bin/php /var/www/html/myproject/artisan queue:work --daemon --env=production

[Install]
WantedBy=multi-user.target
EOF

# start laravel as a service
systemctl daemon-reload
sudo systemctl enable laravel.service
sudo systemctl start laravel.service

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


