#!/bin/bash

################################################################################
# Script for installing Moodle v5.0 Postgresql, Nginx and Php 8.3 on Ubuntu 22.04, 24.04
# Authors: Henry Robert Muwanika

# Make a new file:
# sudo nano install_moodle.sh
# Place this content in it and then make the file executable:
# sudo chmod +x install_moodle_nginx.sh
# Execute the script to install Moodle:
# ./install_moodle_nginx.sh
# crontab -u www-data -e
# Add the following line, which will run the cron script every ten minutes 
#  */2 * * * * /usr/bin/php /var/www/moodle/admin/cli/cron.php  >/dev/null
################################################################################

# Set to "True" to install certbot and have ssl enabled, "False" to use http
ENABLE_SSL="True"
# Set the website name
WEBSITE_NAME="elearning.example.com"
# Provide Email to register ssl certificate
ADMIN_EMAIL="info@example.com"
# Database password
DB_PASS="7pi57KrvHZzFvemr"

echo "
#----------------------------------------------------
# Update Server
#----------------------------------------------------"
sudo apt update && sudo apt upgrade -y
sudo apt autoremove -y

echo "
#----------------------------------------------------
# Enabling root access 
#----------------------------------------------------"
sudo apt install -y openssh-server
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sudo systemctl restart ssh

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
#-------------------------------------------------------
# Installation of dependencies
#-------------------------------------------------------"
sudo apt install -y ca-certificates apt-transport-https software-properties-common lsb-release gnupg2 unzip git curl clamav ffmpeg 

echo "
#--------------------------------------------------
# Installation of PHP
#--------------------------------------------------"
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

sudo apt install -y php8.3 php8.3-cli php8.3-common php8.3-apcu php8.3-mbstring php8.3-gd php8.3-intl php8.3-zip php-pear \
php8.3-xml php8.3-soap php8.3-bcmath php8.3-mysql php8.3-zip php8.3-curl php8.3-tidy php8.3-imagick php8.3-gmp php8.3-fpm \
php8.3-xmlrpc php8.3-pspell php8.3-ldap

echo "
#----------------------------------------------------
# Configure PHP.ini for Moodle requirements
#----------------------------------------------------"
sed -ie "s/\;date\.timezone\ =/date\.timezone\ =\ Africa\/Kigali/g" /etc/php/8.3/fpm/php.ini
sed -ie "s/max_execution_time = 30/max_execution_time = 300/" /etc/php/8.3/fpm/php.ini
sed -ie "s/max_input_time = 60/max_input_time = 360/" /etc/php/8.3/fpm/php.ini
sed -ie "s/;max_input_vars = 1000/max_input_vars = 10000/" /etc/php/8.3/fpm/php.ini
sed -ie "s/error_reporting = E_ALL \& \~E_DEPRECATED/error_reporting = E_ALL \& \~E_NOTICE \& \~E_DEPRECATED/" /etc/php/8.3/fpm/php.ini
sed -ie "s/short_open_tag = Off/short_open_tag = On/" /etc/php/8.3/fpm/php.ini
sed -ie "s/upload_max_filesize = 2M/upload_max_filesize = 120M/" /etc/php/8.3/fpm/php.ini
sed -ie "s/post_max_size = 8M/post_max_size = 120M/" /etc/php/8.3/fpm/php.ini
sed -ie "s/memory_limit = 128M/memory_limit = 512M/" /etc/php/8.3/fpm/php.ini
sed -ie 's/;extension=pdo_pgsql.so/extension=pdo_pgsql.so/g' /etc/php/8.3/fpm/php.ini
sed -ie 's/;extension=pgsql.so/extension=pgsql.so/g' /etc/php/8.3/fpm/php.ini

sudo systemctl restart php8.3-fpm

echo "
#--------------------------------------------------
# Installation of Nginx
#--------------------------------------------------"
sudo apt autoremove apache2 -y

sudo apt install -y nginx
sudo systemctl start nginx.service
sudo systemctl enable nginx.service

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
# sudo -su postgres psql -c "CREATE USER moodleuser WITH PASSWORD 'abc1234@';"
# sudo -su postgres psql -c "CREATE DATABASE moodledb;"
# sudo -su postgres psql -c "ALTER DATABASE moodledb OWNER TO moodleuser;"
# sudo -su postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE moodledb TO moodleuser;"

# sudo systemctl restart postgresql

echo "
#--------------------------------------------------
# Install Debian default database MariaDB 
#--------------------------------------------------"
sudo apt install -y mariadb-server mariadb-client mariadb-backup
sudo systemctl start mariadb.service
sudo systemctl enable mariadb.service

# sudo mariadb-secure-installation

sudo systemctl restart mariadb.service

echo "
#-----------------------------------------------------------------
# Database configuration 
#-----------------------------------------------------------------"
sudo mariadb -uroot --password="" -e "CREATE DATABASE moodledb DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mariadb -uroot --password="" -e "CREATE USER 'moodleuser'@'localhost' IDENTIFIED BY '$DB_PASS';"
sudo mariadb -uroot --password="" -e "GRANT ALL PRIVILEGES ON moodledb.* TO 'moodleuser'@'localhost';"
sudo mariadb -uroot --password="" -e "FLUSH PRIVILEGES;"

sudo systemctl restart mariadb.service


echo "
#--------------------------------------------------
# Installation of Moodle
#--------------------------------------------------"
cd /opt/
wget https://download.moodle.org/download.php/direct/stable502/moodle-latest-502.tgz
tar xzvf moodle-latest-502.tgz

rm /var/www/html/index.html
cp -rf moodle/ /var/www/

sudo mkdir -p /var/moodledata
sudo chown -R www-data:www-data /var/www/moodle
sudo chown -R www-data:www-data /var/moodledata
sudo chmod -R 755 /var/www/moodle
sudo chmod -R 777 /var/moodledata

sudo mkdir -p /var/quarantine
sudo chown -R www-data:www-data /var/quarantine

sudo cat > /etc/nginx/sites-available/moodle.conf << 'NGINX'
server {
    listen 80;
    listen [::]:80;
    server_name  elearning.example.com;
    
    # Point root directly to the public folder of Moodle
    root /var/www/moodle/public;
    index  index.php index.html index.htm;
    
    client_max_body_size 100M;
    autoindex off;
    
    location / {
    try_files $uri $uri/ /r.php$is_args$args;
    }

    # Deny access to internal files and dataroot
    location /dataroot/ {
      internal;
    }

    # Pass PHP scripts to FastCGI server
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock; 
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
NGINX

sudo rm /etc/nginx/sites-available/default
sudo rm /etc/nginx/sites-enabled/default
sudo ln -s /etc/nginx/sites-available/moodle.conf /etc/nginx/sites-enabled/

nginx -t

sudo systemctl restart nginx.service
sudo systemctl restart php8.3-fpm

echo "
#--------------------------------------------------
# Install and configure Firewall
#--------------------------------------------------"
sudo apt install -y ufw

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable UFW
sudo ufw --force enable
sudo ufw reload

sudo apt install -y cron 
sudo systemctl enable cron
sudo systemctl start cron

echo "--------------------------------------------------"
echo "# Certbot SSL Installation"
echo "--------------------------------------------------"
# Base Protocol Choice
PROTOCOL="http"

if [ "$ENABLE_SSL" = "True" ] && [ "$WEBSITE_NAME" != "example.com" ] && [ "$WEBSITE_NAME" != "elearning.example.com" ]; then
    sudo apt-get remove certbot -y || true
    sudo apt install -y snapd
    sudo snap install core && sudo snap refresh core
    sudo snap install --classic certbot
    sudo ln -sf /snap/bin/certbot /usr/bin/certbot
    
    # Run Certbot non-interactively
    sudo certbot --nginx -d "$WEBSITE_NAME" --noninteractive --agree-tos --email "$ADMIN_EMAIL" --redirect
    PROTOCOL="https"
    echo "============ SSL/HTTPS is enabled! ========================"
else
    echo "==== SSL/HTTPS skipped (using default example configs or manual choice) ======"
fi

# sudo cp /var/www/moodle/config-dist.php /var/www/moodle/config.php
echo "--------------------------------------------------"
echo "# Writing Moodle config.php"
echo "--------------------------------------------------"
sudo tee /var/www/moodle/config.php <<EOF
<?PHP
unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();
\$CFG->dbtype    = 'mariadb';
\$CFG->dblibrary = 'native';
\$CFG->dbhost    = 'localhost';
\$CFG->dbname    = 'moodledb';
\$CFG->dbuser    = 'moodleuser';
\$CFG->dbpass    = '${DB_PASS}';
\$CFG->prefix    = 'mdl_';
\$CFG->dboptions = array(
    'dbpersist' => false,
    'dbsocket'  => false,
    'dbport'    => '',   
);

\$CFG->slasharguments = 1; 
\$CFG->preventexecpath = true;
\$CFG->wwwroot   = "${PROTOCOL}://${WEBSITE_NAME}";
\$CFG->dataroot  = '/var/moodledata';
\$CFG->routerconfigured = true;
\$CFG->directorypermissions = 02777;
\$CFG->admin = 'admin';
require_once(dirname(__FILE__) . '/lib/setup.php');
?>
EOF

sudo chmod 444 /var/www/moodle/config.php

cd /var/www/moodle
composer install --no-dev --classmap-authoritative

sudo systemctl restart nginx
sudo systemctl restart php8.3-fpm

echo "=================================================================="
echo " Moodle installation setup is complete!"
echo " Complete the UI web-setup at: ${PROTOCOL}://${WEBSITE_NAME}/"
echo "=================================================================="
