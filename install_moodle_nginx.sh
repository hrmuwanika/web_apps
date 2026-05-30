#!/bin/bash

#############################################################################################
# Shell script for installing Moodle v5.0 MariaDB, Nginx and Php 8.3 on Ubuntu 22.04/24.04
#############################################################################################

# Exit immediately if a command exits with a non-zero status
set -e

# ==================== CONFIGURATION ====================
ENABLE_SSL="True"
WEBSITE_NAME="elearning.example.com"                      # Ensure this matches your intended URL
ADMIN_EMAIL="info@example.com"
TIMEZONE="Africa/Kigali"
DB_PASS="7pi57KrvHZzFveOr"
# =======================================================

echo "--------------------------------------------------"
echo " Update everything "
echo "--------------------------------------------------"
sudo apt update && sudo apt upgrade -y
sudo apt autoremove -y

echo "--------------------------------------------------"
echo " Enabling root access to SSH "
echo "--------------------------------------------------"
sudo apt install -y openssh-server fail2ban
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sudo systemctl restart ssh

echo "--------------------------------------------------"
echo " Set up the timezone"
echo "--------------------------------------------------"
sudo timedatectl set-timezone "$TIMEZONE"
timedatectl

echo "--------------------------------------------------"
echo " Installation of base packages "
echo "--------------------------------------------------"
sudo apt install -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common
sudo apt install -y nano wget unzip git clamav ffmpeg

sudo add-apt-repository ppa:ondrej/php -y
sudo apt update

# Install php8.3
sudo apt install -y php8.3 php8.3-fpm php8.3-mysql php8.3-cli php8.3-curl php8.3-gd php8.3-xml php8.3-zip php8.3-xmlrpc php8.3-bcmath php8.3-json

# Configure PHP.ini for Moodle requirements
PHP_INI="/etc/php/8.3/fpm/php.ini"
sudo sed -i "s|;date.timezone =|date.timezone = ${TIMEZONE}|g" $PHP_INI
sudo sed -i "s/max_execution_time = 30/max_execution_time = 360/" $PHP_INI
sudo sed -i "s/max_input_time = 60/max_input_time = 360/" $PHP_INI
sudo sed -i "s/;max_input_vars = 1000/max_input_vars = 7000/" $PHP_INI
sudo sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 100M/" $PHP_INI
sudo sed -i "s/post_max_size = 8M/post_max_size = 100M/" $PHP_INI
sudo sed -i "s/memory_limit = 128M/memory_limit = 512M/" $PHP_INI # Moodle 5.0 benefits from 512M

sudo systemctl restart php8.3-fpm

echo "--------------------------------------------------"
echo " Install MariaDB Database"
echo "--------------------------------------------------"
sudo apt install -y mariadb-server mariadb-backup
sudo systemctl start mariadb
sudo systemctl enable mariadb

# Secure installation (you’ll be prompted)
sudo mariadb-secure-installation
# - Set root password
# - Remove anonymous users
# - Disallow root login remotely
# - Remove test database
# - Reload privilege tables

# Create Moodle database and user
sudo mariadb -u root -p <<'SQL'
CREATE DATABASE moodle DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'moodleuser'@'localhost' IDENTIFIED BY '${DB_PASS}';
GRANT ALL PRIVILEGES ON moodle.* TO 'moodleuser'@'localhost';
FLUSH PRIVILEGES;
SQL

# Remove Apache if it snuck in
sudo apt autoremove apache2 -y

echo "--------------------------------------------------"
echo "# Installing Nginx"
echo "--------------------------------------------------"
sudo apt install -y nginx
sudo systemctl start nginx
sudo systemctl enable nginx

echo "--------------------------------------------------"
echo " Download and Extract Moodle"
echo "--------------------------------------------------"
cd /opt
sudo wget https://download.moodle.org/download.php/direct/stable502/moodle-latest-502.tgz
sudo tar -xzvf moodle-latest-502.tgz

sudo rm -rf /var/www/html
sudo mv moodle /var/www/moodle

sudo mkdir -p /var/moodledata
sudo mkdir -p /var/quarantine

# Set strict permissions setup
sudo chown -R www-data:www-data /var/www/moodle
sudo chown -R www-data:www-data /var/moodledata
sudo chown -R www-data:www-data /var/quarantine
sudo chmod -R 755 /var/www/moodle
sudo chmod -R 770 /var/moodledata

echo "--------------------------------------------------"
echo " Download and install mod_jitsi plugin"
echo "--------------------------------------------------"
# Download the latest mod_jitsi plugin
cd /tmp
wget https://github.com/jitsi/moodle-plugins/releases/download/v2.0/jitsi_plugin.zip

# Unpack into Moodle
sudo unzip jitsi_plugin.zip -d /var/www/moodle/local

# Set ownership
sudo chown -R www-data:www-data /var/www/moodle/local/jitsi


echo "--------------------------------------------------"
echo " Configure Nginx Server Block"
echo "--------------------------------------------------"
sudo cat > /etc/nginx/sites-available/moodle.conf <<'NGINX'
server {
    listen 80;
    listen [::]:80;
    server_name $WEBSITE_NAME;

    root /var/www/moodle;
    index index.php index.html index.htm;

    client_max_body_size 0; # Unlimited uploads

    location = /favicon.ico { access_log off; log_not_found off; }
    location = /robots.txt  { access_log off; log_not_found off; }

    location ~* \.(js|css|png|jpg|jpeg|gif|ico)$ {
        try_files $uri /$1 =404;
        expires max;
        log_not_found off;
    }

    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    # PHP
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.3-fpm.sock;
        fastcgi_param MAGE_MODE production;
        fastcgi_param MAGE_ROOT /var/www/moodle;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    # Moodle data
    location ^~ /moodledata/ {
        internal;
        alias /var/moodledata/;
    }
}
NGINX

# Manage links safely
sudo rm -f /etc/nginx/sites-available/default
sudo rm -f /etc/nginx/sites-enabled/default

sudo ln -sf /etc/nginx/sites-available/moodle.conf /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

echo "--------------------------------------------------"
echo "# Install and Configure Firewall"
echo "--------------------------------------------------"
sudo apt install -y ufw
sudo ufw allow 22/tcp
sudo ufw allow http
sudo ufw allow https
sudo ufw --force enable
sudo ufw reload

# Set up Cron
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
\$CFG->directorypermissions = 02777;
\$CFG->admin = 'admin';
require_once(dirname(__FILE__) . '/lib/setup.php');
?>
EOF

sudo chmod 444 /var/www/moodle/config.php
sudo systemctl restart nginx
sudo systemctl restart php8.3-fpm

echo "=================================================================="
echo " Moodle installation setup is complete!"
echo " Complete the UI web-setup at: ${PROTOCOL}://${WEBSITE_NAME}/"
echo "=================================================================="
