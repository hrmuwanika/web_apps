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
#
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
# Install and configure Firewall
#--------------------------------------------------
sudo apt install -y ufw
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable 
sudo ufw reload

#--------------------------------------------------
# Set up the timezones
#--------------------------------------------------
# set the correct timezone on ubuntu
timedatectl set-timezone Africa/Kigali
timedatectl

#--------------------------------------------------
# Installing PostgreSQL Server
#--------------------------------------------------
echo -e "=== Install and configure PostgreSQL ... ==="
if [ $INSTALL_POSTGRESQL_SIXTEEN = "True" ]; then
    echo -e "=== Installing postgreSQL V16 due to the user it's choice ... ==="
    sudo apt -y install postgresql-16
else
    echo -e "=== Installing the default postgreSQL version based on Linux version ... ==="
    sudo apt -y install postgresql postgresql-server-dev-all
fi

echo "=== Starting PostgreSQL service... ==="
sudo systemctl start postgresql 
sudo systemctl enable postgresql

# Create the new user with superuser privileges
# sudo su - postgres
# psql
# CREATE DATABASE moodledb
#    OWNER = moodleuser
#    ENCODING = 'UTF8'
#    LC_COLLATE = 'en_US.UTF-8'
#    LC_CTYPE = 'en_US.UTF-8'
#    TABLESPACE = pg_default;
    
# CREATE USER moodleuser WITH PASSWORD 'abc1234!';
# GRANT ALL PRIVILEGES ON DATABASE moodledb to moodleuser;
# \q
# exit

#--------------------------------------------------
# Installation of PHP
#--------------------------------------------------
sudo apt install php php-fpm php-intl php-mysql php-curl php-cli php-zip php-xml php-gd php-common php-mbstring php-xmlrpc php-json php-sqlite3 php-soap php-zip php-pgsql \
php-bcmath php-pspell php-ldap -y
sudo apt install unzip git curl libpcre3 libpcre3-dev graphviz aspell ghostscript clamav -y

sudo apt install nginx -y
sudo systemctl start nginx.service
sudo systemctl enable nginx.service

tee -a /etc/php/8.3/fpm/php.ini <<EOF
   
   cgi.fix_pathinfo = 0
   max_execution_time = 360
   max_input_vars = 6000
   memory_limit = 256M
   post_max_size = 500M
   upload_max_filesize = 500M
   date.timezone = Africa/Kigali
EOF

sudo systemctl restart php8.3-fpm

#--------------------------------------------------
# Installation of Moodle
#--------------------------------------------------
cd /opt/
wget https://download.moodle.org/download.php/direct/stable405/moodle-latest-405.tgz
tar xvf moodle-latest-405.tgz

rm -rf /var/www/html/*
cp -rf /opt/moodle/* /var/www/html/

sudo mkdir -p /var/www/moodledata/
sudo chown -R www-data:www-data /var/www/html/
sudo chown -R www-data:www-data /var/www/moodledata/
sudo chmod -R 755 /var/www/moodledata/
sudo chmod -R 755 /var/www/html/

rm -rf /etc/nginx/sites-available/*
rm -rf /etc/nginx/sites-enabled/*
sudo cat <<EOF > /etc/nginx/sites-available/moodle.conf
server {
    listen 80;
    server_name example.com;

    root /var/www/html;
    index index.php;

    location / {
                # First attempt to serve request as file, then
                # as directory, then fall back to displaying a 404.    
                # try_files  / =404;
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        #fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        #include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }

    # Static file caching
    location ~* \.(jpg|jpeg|gif|png|ico|css|js)$ {
        expires 30d; # Adjust caching duration as needed
        add_header Cache-Control "public, must-revalidate, proxy-revalidate";
    }

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-XSS-Protection "1; mode=block";
    add_header X-Content-Type-Options "nosniff";
    add_header Referrer-Policy "strict-origin-when-cross-origin";
    add_header Permissions-Policy "geolocation=(), microphone=(), camera=()"; # Adjust as needed
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload";

    # Prevent access to sensitive files
    location ~ /(config.php|version.php|admin/cli/|backupdata/) {
        deny all;
    }

    # Handle large file uploads
    client_max_body_size 100M; # Adjust as needed

    # HTTPS configuration (if using HTTPS)
    # listen 443 ssl http2;
    # server_name moodle.example.com;

    # ssl_certificate /etc/letsencrypt/live/moodle.example.com/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/moodle.example.com/privkey.pem;

    # ssl_protocols TLSv1.2 TLSv1.3;
    # ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384';
    # ssl_prefer_server_ciphers off;

    # location / {
    #     try_files $uri $uri/ /index.php?$args;
    # }
}
EOF

sudo ln -s /etc/nginx/sites-available/moodle.conf /etc/nginx/sites-enabled/

sudo apt autoremove apache2
sudo systemctl restart nginx.service
sudo systemctl restart php8.3-fpm

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
  sudo certbot --nginx -d $WEBSITE_NAME --noninteractive --agree-tos --email $ADMIN_EMAIL --redirect
  
  sudo systemctl restart nginx
  
  echo "============ SSL/HTTPS is enabled! ========================"
else
  echo "==== SSL/HTTPS isn't enabled due to choice of the user or because of a misconfiguration! ======"
fi

sudo systemctl restart nginx

echo "Moodle installation is complete"
echo "Access moodle on https://$WEBSITE_NAME/install.php"



