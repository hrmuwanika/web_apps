#!/bin/bash

################################################################################
# Script for installing Moodle v5.2 Postgresql, Nginx and Php 8.3 on Ubuntu 22.04, 24.04
# Authors: Henry Robert Muwanika

# Make a new file:
# sudo nano install_moodle.sh
# Place this content in it and then make the file executable:
# sudo chmod +x install_moodle_nginx.sh
# Execute the script to install Moodle:
# ./install_moodle_nginx.sh
# crontab -u www-data -e
# Add the following line, which will run the cron script every ten minutes 
#  * * * * * /usr/bin/php /var/www/moodle/admin/cli/cron.php  >/dev/null
################################################################################

# Set to "True" to install certbot and have ssl enabled, "False" to use http
ENABLE_SSL="True"
# Set the website name
WEBSITE_NAME="elearning.example.com"
# Provide Email to register ssl certificate
ADMIN_EMAIL="info@example.com"
# Database password
DB_PASS=$(openssl rand -base64 12)

# Moodle Admin Account UI setup configuration
MOODLE_ADMIN_USER="admin"
MOODLE_ADMIN_PASS=$(openssl rand -base64 10)
MOODLE_ADMIN_EMAIL="info@example.com"
MOODLE_SITENAME="E-Learning Academy"

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
sudo apt install -y ca-certificates apt-transport-https software-properties-common lsb-release gnupg2 unzip git curl clamav clamav-daemon ghostscript graphviz aspell

echo "
#--------------------------------------------------
# Installation of PHP
#--------------------------------------------------"
sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

sudo apt install -y php8.3 php8.3-cli php8.3-common php8.3-apcu php8.3-mbstring php8.3-gd php8.3-intl php-pear php8.3-xml php8.3-soap php8.3-bcmath php8.3-mysql php8.3-zip \
php8.3-curl php8.3-tidy php8.3-imagick php8.3-gmp php8.3-fpm php8.3-xmlrpc php8.3-pspell php8.3-exif php8.3-ldap php8.3-pgsql

echo "
#----------------------------------------------------
# Configure PHP.ini for Moodle requirements
#----------------------------------------------------"
sudo sed -ie 's/\;date\.timezone\ =/date\.timezone\ =\ Africa\/Kigali/g' /etc/php/8.3/fpm/php.ini
sudo sed -ie 's/max_execution_time =.*/max_execution_time = 360/' /etc/php/8.3/fpm/php.ini
sudo sed -ie 's/max_input_time =.*/max_input_time = 360/' /etc/php/8.3/fpm/php.ini
sudo sed -ie 's/^;max_input_vars =.*/max_input_vars = 8000/' /etc/php/8.3/fpm/php.ini
sudo sed -ie 's/^;max_input_vars =.*/max_input_vars = 8000/' /etc/php/8.3/cli/php.ini
sudo sed -ie 's/error_reporting = E_ALL \& \~E_DEPRECATED/error_reporting = E_ALL \& \~E_NOTICE \& \~E_DEPRECATED/' /etc/php/8.3/fpm/php.ini
sudo sed -ie 's/short_open_tag = Off/short_open_tag = On/' /etc/php/8.3/fpm/php.ini
sudo sed -ie 's/^upload_max_filesize =.*/upload_max_filesize = 256M/' /etc/php/8.3/fpm/php.ini
sudo sed -ie 's/^upload_max_filesize =.*/upload_max_filesize = 256M/' /etc/php/8.3/cli/php.ini
sudo sed -ie 's/^post_max_size =.*/post_max_size = 256M/' /etc/php/8.3/fpm/php.ini
sudo sed -ie 's/^post_max_size =.*/post_max_size = 256M/' /etc/php/8.3/cli/php.ini
sudo sed -ie 's/memory_limit =.*/memory_limit = 512M/' /etc/php/8.3/fpm/php.ini
sudo sed -ie 's/;cgi.fix_pathinfo =.*/cgi.fix_pathinfo = 1/' /etc/php/8.3/fpm/php.ini
sudo sed -ie 's/;extension=pdo_pgsql.so/extension=pdo_pgsql.so/g' /etc/php/8.3/fpm/php.ini
sudo sed -ie 's/;extension=pgsql.so/extension=pgsql.so/g' /etc/php/8.3/fpm/php.ini

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

# sudo apt -y install postgresql-17 postgresql-contrib

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
sudo mariadb -u root --password="" -e "CREATE DATABASE moodledb DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mariadb -u root --password="" -e "CREATE USER 'moodleuser'@'localhost' IDENTIFIED BY '$DB_PASS';"
sudo mariadb -u root --password="" -e "GRANT ALL PRIVILEGES ON moodledb.* TO 'moodleuser'@'localhost';"
sudo mariadb -u root --password="" -e "FLUSH PRIVILEGES;"

sudo systemctl restart mariadb.service


echo "
#--------------------------------------------------
# Installation of Moodle
#--------------------------------------------------"
cd /opt/
wget https://download.moodle.org/download.php/direct/stable502/moodle-latest-502.tgz
tar xzvf moodle-latest-502.tgz

sudo rm -f /var/www/html/index.html || true
sudo cp -rf moodle/ /var/www/

#  Create the moodledata directory outside your web server's document root
sudo mkdir -p /var/moodledata

# Set the webserver as the owner and group recursively ( for both the files and contents)
sudo chown -R www-data:www-data /var/moodledata

#  Set the  moodledata directory permissions so only the web server can read, write, and access them.
sudo find /var/moodledata -type d -exec chmod 700 {} \;

# Set the  moodledata file permissions so only the web server can read and write them.
sudo find /var/moodledata -type f -exec chmod 600 {} \;

echo " 
#-------------------------------------------------------
# Configuring Cron Jobs
#-------------------------------------------------------"
sudo apt install -y cron 
sudo systemctl enable cron
sudo systemctl start cron

# Call the cron.php in the moodle admin directory to run every minute.
echo "* * * * * /usr/bin/php /var/www/moodle/admin/cli/cron.php >/dev/null" | sudo crontab -u www-data -

# Fix permissions on Moodle directory and codebase
sudo find /var/www/moodle -type d -exec chmod 755 {} \;
sudo find /var/www/moodle -type f -exec chmod 644 {} \;

# sudo mkdir -p /var/quarantine
# sudo chown -R www-data:www-data /var/www/moodle
# sudo chown -R www-data:www-data /var/quarantine
# sudo chmod -R 777 /var/moodledata

# nginx needs slash arguments set
sudo sed -i "/require_once(__DIR__ . '\/lib\/setup.php');/i \$CFG->slasharguments = false;" /var/www/moodle/config.php

# Set up the configuration file including the fallback required for the router
# Using tee allows the file to be written in a single (rather long command). 
# Be sure to copy and paste entire block from "sudo" to "EOF"
sudo tee /etc/nginx/sites-available/moodle.conf > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name $WEBSITE_NAME;
    
    # Point root to the public/web folder of Moodle
    root /var/www/moodle/public;
    index index.php index.html index.htm;

    client_max_body_size 100M;
    autoindex off;

    location / {
        # Redirect to Moodle's 5.1 router if file doesn't exist
        try_files \$uri \$uri/ /index.php?\$args /r.php;
    }

    location ~ [^/]\.php(/|$) {
        fastcgi_split_path_info ^(.+\.php)(/.+)\$;
        fastcgi_index index.php;
        include fastcgi_params;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info;
        fastcgi_pass unix:/var/run/php/php8.3-fpm.sock;
    }

    location ~ /\.ht {
        deny all;
    }
}
EOF

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

echo "----------------------------------------------------"
echo "# Installing Composer Dependencies"
echo "----------------------------------------------------"
cd /var/www/moodle
sudo curl -sS https://getcomposer.org/installer | php
sudo mv composer.phar /usr/local/bin/composer
sudo chmod +x /usr/local/bin/composer
sudo composer install --no-dev --classmap-authoritative

echo "
#---------------------------------------------------------
# Running Moodle Automated CLI Installer
#---------------------------------------------------------"
cd /var/www/moodle

# Run the installer from the core directory
sudo -u www-data /usr/bin/php admin/cli/install.php \
    --lang="en" \
    --dbtype="mariadb" \
    --dbhost="localhost" \
    --dbname="moodledb" \
    --dbuser="moodleuser" \
    --dbpass="$DB_PASS" \
    --adminuser="$MOODLE_ADMIN_USER" \
    --adminpass="$MOODLE_ADMIN_PASS" \
    --adminemail="$MOODLE_ADMIN_EMAIL" \
    --agree-license \
    --fullname="$MOODLE_SITENAME" \
    --shortname="Moodle" \
    --wwwroot="${PROTOCOL}://${WEBSITE_NAME}" \
    --dataroot="/var/moodledata" \
    --non-interactive


echo "
#--------------------------------------------------------
# Writing Moodle config.php
#--------------------------------------------------------"
# Adjust generated configuration parameters
sudo chmod 644 /var/www/moodle/config.php

sudo tee /var/www/moodle/config.php <<EOF
<?PHP
// Moodle configuration file

unset(\$CFG);
global \$CFG;
\$CFG = new stdClass();

\$CFG->dbtype    = 'mariadb';            // 'pgsql', 'mariadb', 'mysqli', 'auroramysql', 'sqlsrv' or 'oci'
\$CFG->dblibrary = 'native';             // 'native' only at the moment
\$CFG->dbhost    = 'localhost';          // eg 'localhost' or 'db.isp.com' or IP
\$CFG->dbname    = 'moodledb';           // database name, eg moodle
\$CFG->dbuser    = 'moodleuser';         // your database username
\$CFG->dbpass    = '${DB_PASS}';         // your database password
\$CFG->prefix    = 'mdl_';               // prefix to use for all table names
\$CFG->dboptions = array (
    'dbpersist' => 0,
    'dbport' => '',
    'dbsocket' => '',
    'dbcollation' => 'utf8mb4_unicode_ci',
);

// $CFG->preventexecpath = true;
// $CFG->routerconfigured = true;

\$CFG->wwwroot   = "${PROTOCOL}://${WEBSITE_NAME}";
\$CFG->dataroot  = '/var/moodledata';
\$CFG->admin = 'admin';

\$CFG->directorypermissions = 02777;

\$CFG->slasharguments = false;
require_once(__DIR__ . '/lib/setup.php');

// There is no php closing tag in this file,
// it is intentional because it prevents trailing whitespace problems!
EOF

# Lock down down production configuration write access
sudo chmod 444 /var/www/moodle/config.php

sudo systemctl restart nginx
sudo systemctl restart php8.3-fpm

echo "=================================================================="
echo " Moodle installation setup is complete!"
echo " Complete the UI web-setup at: ${PROTOCOL}://${WEBSITE_NAME}/"
echo " database username: moodleuser"
echo " database password: $DB_PASS"
echo " moodle username: admin"
echo " moodle password: $MOODLE_ADMIN_PASS"
echo "=================================================================="
