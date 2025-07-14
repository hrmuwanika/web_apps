#!/bin/bash

# ##### Laravel app development #####
# Laravel installer v5.14.0
# Composer v2.8.9
# Php v8.2 or higher
# Postgresql v16
# Nodejs v18 or higher
# PNPM - for dependency management
# with Laravel backend (PostgreSQL) and Next.js frontend

echo "======== Install required dependencies ==========="
sudo apt update && sudo apt upgrade -y

echo "================ Install node, npm, composer ===================="
sudo apt install -y ufw wget curl git unzip 

curl -fsSL https://deb.nodesource.com/setup_24.x | sudo -E bash -
sudo apt update
sudo apt install nodejs -y

echo "============== ufw firewall configuration ======================="
sudo ufw allow 22/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 8000/tcp
sudo ufw allow 3000/tcp
sudo ufw --force enable
sudo ufw reload

echo "================================ Install php8.4 ========================================================================="
sudo add-apt-repository ppa:ondrej/php
sudo apt update
sudo apt install -y php8.4 php8.4-common php8.4-cli php8.4-opcache php8.4-mysql php8.4-xml php8.4-curl php8.4-zip php8.4-mbstring php8.4-gd php8.4-intl php8.4-bcmath \
php8.4-xml php-pear php8.4-fpm php8.4-pgsql php8.4-tokenizer

# Install composer
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php composer-setup.php --install-dir=/usr/local/bin --filename=composer

# Laravel installer
/bin/bash -c "$(curl -fsSL https://php.new/install/linux/8.4)"
composer global require laravel/installer

sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
sudo apt update

echo "================== install postgresql v16 ================================="
sudo apt install -y postgresql-16 postgresql-client postgresql-contrib

sudo systemctl start postgresql 
sudo systemctl enable postgresql

# Setup PostgreSQL database
sudo -su postgres psql -c "CREATE USER dev_user WITH PASSWORD 'abc1234@';"
sudo -su postgres psql -c "CREATE DATABASE laradev_db;"
sudo -su postgres psql -c "ALTER DATABASE laradev_db OWNER TO dev_user;"
sudo -su postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE laradev_db TO dev_user;"

sudo apt install -y nginx-full

sudo systemctl start nginx.service
sudo systemctl enable nginx.service

cd /var/www/html/
rm -rf *
