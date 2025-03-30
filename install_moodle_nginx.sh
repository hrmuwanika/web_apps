#!/bin/bash

################################################################################
# Script for installing Moodle v4.5.2 Postgresql, Nginx and Php 8.3 on Ubuntu 24.04
# Authors: Henry Robert Muwanika

# Make a new file:
# sudo nano install_moodle.sh
# Place this content in it and then make the file executable:
# sudo chmod +x install_moodle_nginx.sh
# Execute the script to install Moodle:
# ./install_moodle_nginx.sh
# crontab -e
# * * * * * /usr/bin/php /var/www/html/admin/cli/cron.php
################################################################################

# Set to "True" to install certbot and have ssl enabled, "False" to use http
ENABLE_SSL="True"
# Set the website name
WEBSITE_NAME="example.com"
# Provide Email to register ssl certificate
ADMIN_EMAIL="moodle@example.com"

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo "============= Update Server ================"
sudo apt update && sudo apt upgrade -y
sudo apt autoremove -y

#----------------------------------------------------
# Disabling password authentication
#----------------------------------------------------
echo "Disabling password authentication ... "
sudo sed -i 's/#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config 
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo service sshd restart

#--------------------------------------------------
# Set up the timezones
#--------------------------------------------------
# set the correct timezone on ubuntu
timedatectl set-timezone Africa/Kigali
timedatectl

#--------------------------------------------------
# Installation of PHP
#--------------------------------------------------
sudo apt install -y php php-common php-cli php-intl php-xmlrpc php-soap php-mysql php-zip php-gd php-tidy php-mbstring php-curl php-xml php-pear \
php-bcmath php-pspell php-curl php-ldap php-soap unzip git curl libpcre3 libpcre3-dev graphviz aspell ghostscript clamav postfix php-gmp php-imagick \
php-fpm php-redis php-apcu php-opcache bzip2 zip unzip imagemagick ffmpeg libsodium23

sudo apt autoremove apache2 -y
sudo apt install -y nginx
sudo systemctl start nginx.service
sudo systemctl enable nginx.service

tee -a /etc/php/8.3/fpm/php.ini <<EOF
   file_uploads = On
   allow_url_fopen = On
   short_open_tag = On
   max_execution_time = 600
   memory_limit = 512M
   post_max_size = 500M
   upload_max_filesize = 500M
   max_input_time = 1000
   date.timezone = Africa/Kigali
   max_input_vars = 7000
EOF

sudo systemctl restart php8.3-fpm

#--------------------------------------------------
# Installing PostgreSQL Server
#--------------------------------------------------
# echo -e "=== Install and configure PostgreSQL ... ==="
# sudo apt -y install postgresql postgres-contrib php-pgsql

# echo "=== Starting PostgreSQL service... ==="
# sudo systemctl start postgresql 
# sudo systemctl enable postgresql

# Create the new user with superuser privileges
# sudo -u postgres psql -c "CREATE USER moodleuser WITH PASSWORD 'abc1234!';"
# sudo -u postgres psql -c "CREATE DATABASE moodledb;"
# sudo -u postgres psql -c "ALTER DATABASE moodledb OWNER TO moodleuser;"
# sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE moodledb TO moodleuser;"

# sudo systemctl restart postgresql

#--------------------------------------------------
# Install Debian default database MariaDB 
#--------------------------------------------------
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

sudo mariadb -uroot --password="" -e "CREATE DATABASE moodledb DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mariadb -uroot --password="" -e "CREATE USER 'moodleuser'@'localhost' IDENTIFIED BY 'abc1234!';"
sudo mariadb -uroot --password="" -e "GRANT ALL PRIVILEGES ON moodledb.* TO 'moodleuser'@'localhost';"
sudo mariadb -uroot --password="" -e "FLUSH PRIVILEGES;"

sudo systemctl restart mariadb.service

#--------------------------------------------------
# Installation of Moodle
#--------------------------------------------------
cd /opt/
wget https://download.moodle.org/download.php/direct/stable405/moodle-latest-405.tgz
tar xvf moodle-latest-405.tgz

rm -rf /var/www/html/*
cp -rf /opt/moodle/* /var/www/html/

sudo mkdir -p /var/www/moodledata
sudo chown -R www-data:www-data /var/www/moodledata
sudo chmod -R 775 /var/www/moodledata

sudo chown -R www-data:www-data /var/www/html
sudo chmod -R 755 /var/www/html

sudo mkdir -p /var/quarantine
sudo chown -R www-data:www-data /var/quarantine

sudo cat > /etc/nginx/sites-available/moodle.conf <<NGINX
server {
    listen 80;
    listen [::]:80;
    root /var/www/html;
    index  index.php;
    server_name  moodle.example.com;

    # Log files
    access_log /var/log/nginx/moodle.access.log;
    error_log /var/log/nginx/moodle.error.log;
    
    client_max_body_size 100M;

    if (!-e $request_filename) {
       rewrite ^(.*\.php)(/)(.*)$ $1?file=/$3 last;
    }
    
    location / {
       try_files \$uri \$uri/ /index.php?$args; 
    }
    
    location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
    fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    include fastcgi_params;
    }

    location /dataroot/ {
      internal;
      alias /var/www/moodledata/;
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
NGINX

sudo rm /etc/nginx/sites-available/default
sudo rm /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/moodle.conf /etc/nginx/sites-enabled/

nginx -t

sudo systemctl restart nginx.service
sudo systemctl restart php8.3-fpm

#--------------------------------------------------
# Install and configure Firewall
#--------------------------------------------------
sudo apt install -y ufw
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw enable 
sudo ufw reload

#--------------------------------------------------
# Enable ssl with certbot
#--------------------------------------------------

if [ $ENABLE_SSL = "True" ] && [ $ADMIN_EMAIL != "moodle@example.com" ]  && [ $WEBSITE_NAME != "example.com" ];then
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

echo "Moodle installation is complete"
echo "Access moodle on https://$WEBSITE_NAME/install.php"



