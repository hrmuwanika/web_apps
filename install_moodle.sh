#!/bin/bash

################################################################################
# Script for installing Moodle v4.5.2 Postgres, Nginx and Php 8.3 on Ubuntu 24.04
# Authors: Henry Robert Muwanika

# Make a new file:
# sudo nano install_moodle.sh
# Place this content in it and then make the file executable:
# sudo chmod +x install_moodle.sh
# Execute the script to install Moodle:
# ./install_moodle.sh
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
sudo ufw allow OpenSSH
sudo ufw allow http
sudo ufw allow https
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

echo -e "=== Creating the Odoo PostgreSQL User ... ==="
#sudo su - postgres
#psql

#CREATE DATABASE moodledb;
#CREATE USER moodleuser WITH PASSWORD 'abc1234!';
#GRANT ALL PRIVILEGES ON DATABASE moodledb to moodleuser;
#\q
#exit

#--------------------------------------------------
# Installation of PHP
#--------------------------------------------------
sudo apt install -y php php-common php-cli php-intl php-xmlrpc php-soap php-mysql php-zip php-gd php-tidy php-mbstring php-curl php-xml php-pear php-pgsql \
php-bcmath php-fpm php-pspell php-curl php-ldap php-soap unzip git curl libpcre3 libpcre3-dev graphviz aspell ghostscript clamav

# Install Nginx
sudo apt install -y nginx-full
sudo systemctl stop nginx
sudo systemctl start nginx
sudo systemctl enable nginx

tee -a /etc/php/8.3/fpm/php.ini <<EOF

   file_uploads = On
   allow_url_fopen = On
   short_open_tag = On
   max_execution_time = 360
   max_input_vars = 6000
   memory_limit = 256M
   post_max_size = 500M
   cgi.fix_pathinfo = 0
   upload_max_filesize = 500M
   date.timezone = Africa/Kigali
EOF

sudo systemctl reload php8.3-fpm

#--------------------------------------------------
# Installation of Moodle
#--------------------------------------------------
cd /opt/
wget https://download.moodle.org/download.php/direct/stable405/moodle-latest-405.tgz
tar xvf moodle-latest-405.tgz

cp -rf /opt/moodle/* /var/www/html/
sudo chmod 775 -R /var/www/html/
sudo chown nginx:nginx -R /var/www/html/

mkdir -p /var/www/moodledata
sudo chmod 770 -R /var/www/moodledata
sudo chown :nginx -R /var/www/moodledata

sudo cat <<EOF > /etc/nginx/sites-available/moodle.conf

server {
    listen 80;
    listen [::]:80;
    root /var/www/html;
    index  index.php;
    server_name  $WEBSITE_NAME;

    client_max_body_size 200M;
    
    location /dataroot/ {
      internal;
      alias /var/www/moodledata/;
    }

    location / {
    try_files $uri $uri/ =404;        
    }

    location ~ [^/]\.php(/|$) {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    # Improve Moodle performance
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg)$ {
        try_files $uri =404;
        expires max;
        log_not_found off;
    }
}
EOF

#sudo ln -s /etc/nginx/sites-available/moodle.conf /etc/nginx/sites-enabled/
sudo systemctl restart nginx.service
sudo nginx -t

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
  sudo certbot --nginx -d $WEBSITE_NAME -d www.$WEBSITE_NAME --noninteractive --agree-tos --email $ADMIN_EMAIL --redirect
  
  sudo systemctl restart nginx
  
  echo "============ SSL/HTTPS is enabled! ========================"
else
  echo "==== SSL/HTTPS isn't enabled due to choice of the user or because of a misconfiguration! ======"
fi

sudo systemctl restart nginx

echo "Moodle installation is complete"
echo "Access moodle on https://$WEBSITE_NAME/install.php"

