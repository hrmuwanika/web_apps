#!/bin/bash

################################################################################
# Script for installing Moodle v5.0 MariaDB, Apache2 and Php 8.3 on Ubuntu 20.04, 22.04, 24.04
# Authors: Henry Robert Muwanika

# Make a new file:
# sudo nano install_moodle.sh
# Place this content in it and then make the file executable:
# sudo chmod +x install_moodle_apache.sh
# Execute the script to install Moodle:
# ./install_moodle_apache.sh
# crontab -e
# Add the following line, which will run the cron script every ten minutes 
# */10 * * * * /usr/bin/php /var/www/html/admin/cli/cron.php
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
sudo apt install -y openssh-server
sudo sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
sudo systemctl restart sshd

#--------------------------------------------------
# Install and configure Firewall
#--------------------------------------------------
sudo apt install -y ufw

sudo ufw allow 22/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow http
sudo ufw allow https

sudo ufw --force enable
sudo ufw reload

#--------------------------------------------------
# Set up the timezones
#--------------------------------------------------
# set the correct timezone on ubuntu
timedatectl set-timezone Africa/Kigali
timedatectl

#--------------------------------------------------
# Install Debian default database MariaDB 
#--------------------------------------------------
sudo apt-key adv --fetch-keys 'https://mariadb.org/mariadb_release_signing_key.asc'
sudo add-apt-repository 'deb [arch=amd64,arm64,ppc64el] https://mariadb.mirror.liquidtelecom.com/repo/10.11/ubuntu focal main'
sudo update

sudo apt install -y mariadb-server mariadb-client mariadb-backup
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
sudo mariadb -uroot --password="" -e "CREATE USER 'moodleuser'@'localhost' IDENTIFIED BY 'abc1234@';"
sudo mariadb -uroot --password="" -e "GRANT ALL PRIVILEGES ON moodledb.* TO 'moodleuser'@'localhost';"
sudo mariadb -uroot --password="" -e "FLUSH PRIVILEGES;"

sudo systemctl restart mariadb.service

#--------------------------------------------------
# Installation of PHP
#--------------------------------------------------
sudo apt install -y ca-certificates apt-transport-https software-properties-common lsb-release 
apt -y install software-properties-common
add-apt-repository ppa:ondrej/php
sudo apt update -y

sudo apt install -y apache2 php8.3 php8.3-common php8.3-cli php8.3-intl php8.3-xmlrpc php8.3-mysql php8.3-zip php8.3-gd php8.3-tidy php8.3-mbstring php8.3-curl php8.3-xml php-pear \
php8.3-bcmath libapache2-mod-php8.3 php8.3-pspell php8.3-curl php8.3-ldap php8.3-soap unzip git curl libpcre3 libpcre3-dev graphviz aspell ghostscript clamav postfix \
php8.3-gmp php8.3-imagick php8.3-fpm php8.3-redis php8.3-apcu bzip2 unzip imagemagick ffmpeg libsodium23 fail2ban libpng-dev libjpeg-dev libtiff-dev 

sudo systemctl start apache2.service
sudo systemctl enable apache2.service

sudo systemctl start fail2ban.service
sudo systemctl enable fail2ban.service

sed -i "s/\;date\.timezone\ =/date\.timezone\ =\ Africa\/Kigali/g" /etc/php/8.3/apache2/php.ini
sed -i "s/max_execution_time = 30/max_execution_time = 600/" /etc/php/8.3/apache2/php.ini
sed -i "s/max_input_time = 60/max_input_time = 1000/" /etc/php/8.3/apache2/php.ini
sed -i "s/;max_input_vars = 1000/max_input_vars = 7000/" /etc/php/8.3/apache2/php.ini
sed -i "s/error_reporting = E_ALL \& \~E_DEPRECATED/error_reporting = E_ALL \& \~E_NOTICE \& \~E_DEPRECATED/" /etc/php/8.3/apache2/php.ini
sed -i "s/short_open_tag = Off/short_open_tag = On/" /etc/php/8.3/apache2/php.ini
sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 448M/" /etc/php/8.3/apache2/php.ini
sed -i "s/post_max_size = 8M/post_max_size = 448M/" /etc/php/8.3/apache2/php.ini
sed -i "s/memory_limit = 128M/memory_limit = 448M/" /etc/php/8.3/apache2/php.ini
sed -i "s/\;date\.timezone\ =/date\.timezone\ =\ Africa\/Kigali/g" /etc/php/8.3/cli/php.ini
sed -i "s/max_execution_time = 30/max_execution_time = 600/" /etc/php/8.3/cli/php.ini
sed -i "s/max_input_time = 60/max_input_time = 1000/" /etc/php/8.3/cli/php.ini
sed -i "s/;max_input_vars = 1000/max_input_vars = 7000/" /etc/php/8.3/cli/php.ini
sed -i "s/error_reporting = E_ALL \& \~E_DEPRECATED/error_reporting = E_ALL \& \~E_NOTICE \& \~E_DEPRECATED/" /etc/php/8.3/cli/php.ini
sed -i "s/short_open_tag = Off/short_open_tag = On/" /etc/php/8.3/cli/php.ini
sed -i "s/memory_limit = 128M/memory_limit = 448M/" /etc/php/8.3/cli/php.ini
sed -i 's/;opcache.enable=1/opcache.enable=1/g' /etc/php/8.3/apache2/php.ini
sed -i 's/;opcache.memory_consumption=128/opcache.memory_consumption=128/g' /etc/php/8.3/apache2/php.ini
sed -i 's/;opcache.interned_strings_buffer=8/opcache.interned_strings_buffer=16/g' /etc/php/8.3/apache2/php.ini
sed -i 's/;opcache.max_accelerated_files=10000/opcache.max_accelerated_files=20000/g' /etc/php/8.3/apache2/php.ini
sed -i 's/;opcache.max_wasted_percentage=5/opcache.max_wasted_percentage=5/g' /etc/php/8.3/apache2/php.ini
sed -i 's/;opcache.validate_timestamps=1/opcache.validate_timestamps=1/g' /etc/php/8.3/apache2/php.ini
sed -i 's/;opcache.revalidate_freq=2/opcache.revalidate_freq=10/g' /etc/php/8.3/apache2/php.ini

tee -a /etc/php/8.3/apache2/php.ini <<EOF
   file_uploads = On
   allow_url_fopen = On
EOF

sudo systemctl restart apache2

#--------------------------------------------------
# Installation of Moodle
#--------------------------------------------------
cd /opt/
# wget https://download.moodle.org/download.php/direct/stable405/moodle-latest-405.tgz
# tar xvf moodle-latest-405.tgz
wget https://download.moodle.org/download.php/direct/stable500/moodle-latest-500.tgz
tar xvf moodle-latest-500.tgz

mv moodle/ /var/www/html

sudo mkdir -p /var/www/moodledata
sudo chown -R www-data:www-data /var/www/moodledata
sudo find /var/www/moodledata -type d -exec chmod 700 {} \; 
sudo find /var/www/moodledata -type f -exec chmod 600 {} \;

sudo chown -R www-data:www-data /var/www/html/moodle
sudo find /var/www/html/moodle -type d -exec chmod 755 {} \; 
sudo find /var/www/html/moodle -type f -exec chmod 644 {} \;

sudo mkdir -p /var/quarantine
sudo chown -R www-data:www-data /var/quarantine

sudo cat <<EOF > /etc/apache2/sites-available/moodle.conf

<VirtualHost *:80>
  # The ServerName directive sets the request scheme, hostname and port that
        # the server uses to identify itself. This is used when creating
        # redirection URLs. In the context of virtual hosts, the ServerName
        # specifies what hostname must appear in the request's Host: header to
        # match this virtual host. For the default virtual host (this file) this
        # value is not decisive as it is used as a last resort host regardless.
        # However, you must set it for any further virtual host explicitly.
        ServerName \$WEBSITE_NAME

        ServerAdmin webmaster@localhost
        DocumentRoot /var/www/html/moodle

        # Available loglevels: trace8, ..., trace1, debug, info, notice, warn,
        # error, crit, alert, emerg.
        # It is also possible to configure the loglevel for particular
        # modules, e.g.
        #LogLevel info ssl:warn

        ErrorLog \${APACHE_LOG_DIR}/error.log
        CustomLog \${APACHE_LOG_DIR}/access.log combined

        # For most configuration files from conf-available/, which are
        # enabled or disabled at a global level, it is possible to
        # include a line for only one particular virtual host. For example the
        # following line enables the CGI configuration for this host only
        # after it has been globally disabled with "a2disconf".
        #Include conf-available/serve-cgi-bin.conf
 </VirtualHost>
EOF

a2dissite 000-default.conf
sudo a2ensite moodle.conf
sudo apachectl configtest
sudo systemctl restart apache2

sudo a2enmod rewrite
sudo a2enmod ssl
sudo systemctl restart apache2

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
  
  sudo certbot --apache -d $WEBSITE_NAME --noninteractive --agree-tos --email $ADMIN_EMAIL --redirect
  
  sudo systemctl restart apache2
  
  echo "============ SSL/HTTPS is enabled! ========================"
else
  echo "==== SSL/HTTPS isn't enabled due to choice of the user or because of a misconfiguration! ======"
fi

rm /var/www/html/index.html

sudo apt install -y cron 
sudo systemctl enable cron
sudo systemctl start cron

# sudo cp /var/www/html/moodle/config-dist.php /var/www/html/moodle/config.php
sudo cat <<EOF > /var/www/html/moodle/config.php 
<?PHP
unset(\$CFG);                                // Ignore this line
global \$CFG;                                // This is necessary here for PHPUnit execution
\$CFG = new stdClass();
\$CFG->dbtype    = 'mariadb';
\$CFG->dblibrary = 'native';
\$CFG->dbhost    = 'localhost';
\$CFG->dbname    = 'moodledb';
\$CFG->dbuser    = 'moodleuser';
\$CFG->dbpass    = 'abc1234@';
\$CFG->prefix    = 'mdl_';
\$CFG->dboptions = array(
    'dbpersist' => false,
    'dbsocket'  => false,
    'dbport'    => '',   
);

\$CFG->slasharguments = 0; 
\$CFG->preventexecpath = true;
\$CFG->wwwroot   = 'https://<^>example.com<^>';
\$CFG->dataroot  = '/var/www/moodledata';
\$CFG->directorypermissions = 0777;
\$CFG->admin = 'admin';
require_once(dirname(__FILE__) . '/lib/setup.php');
?>
EOF

sudo chmod -R 444 /var/www/html/moodle/config.php
sudo systemctl restart apache2

echo "Moodle installation is complete"
echo "Access moodle on https://$WEBSITE_NAME/install.php"

