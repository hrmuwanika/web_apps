#!/bin/bash

# Set to "True" to install certbot and have ssl enabled, "False" to use http
ENABLE_SSL="True"
# Set the website name
WEBSITE_NAME="example.com"
# Provide Email to register ssl certificate
ADMIN_EMAIL="info@example.com"

echo "
#--------------------------------------------------
# Update system
#--------------------------------------------------"
sudo apt update && sudo apt upgrade -y
sudo apt autoremove -y

echo "
#--------------------------------------------------
# Enable root login via SSH
#--------------------------------------------------"
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
# Nginx installation
#--------------------------------------------------"
sudo apt install -y nginx
sudo systemctl enable nginx.service
sudo systemctl start nginx.service

echo "
#--------------------------------------------------
# # PHP 8.4 installation
#--------------------------------------------------"
sudo apt install -y php8.4 php8.4-common php8.4-cli php8.4-intl php8.4-xmlrpc php8.4-zip php8.4-gd php8.4-tidy php8.4-mbstring php8.4-curl php-pear \
php8.4-dev php8.4-bcmath php8.4-pspell php8.4-ldap php8.4-soap php8.4-gmp php8.4-imagick php8.4-fpm php8.4-redis php8.4-apcu php8.4-mysql php8.4-xml 

sudo systemctl start php8.4-fpm
sudo systemctl enable php8.4-fpm

sudo apt install -y build-essential  bzip2 imagemagick composer libsodium23 fail2ban libpng-dev libjpeg-dev libtiff-dev postfix curl unzip git

sudo systemctl start fail2ban
sudo systemctl enable fail2ban

sudo pecl install uploadprogress

sed -ie "s/\;date\.timezone\ =/date\.timezone\ =\ Africa\/Kigali/g" /etc/php/8.4/fpm/php.ini
sed -ie "s/max_execution_time = 30/max_execution_time = 600/" /etc/php/8.4/fpm/php.ini
sed -ie "s/max_input_time = 60/max_input_time = 1000/" /etc/php/8.4/fpm/php.ini
sed -ie "s/;max_input_vars = 1000/max_input_vars = 7000/" /etc/php/8.4/fpm/php.ini
sed -ie "s/error_reporting = E_ALL \& \~E_DEPRECATED/error_reporting = E_ALL \& \~E_NOTICE \& \~E_DEPRECATED/" /etc/php/8.4/fpm/php.ini
sed -ie "s/short_open_tag = Off/short_open_tag = On/" /etc/php/8.4/fpm/php.ini
sed -ie "s/upload_max_filesize = 2M/upload_max_filesize = 500M/" /etc/php/8.4/fpm/php.ini
sed -ie "s/post_max_size = 8M/post_max_size = 500M/" /etc/php/8.4/fpm/php.ini
sed -ie "s/memory_limit = 128M/memory_limit = 512M/" /etc/php/8.4/fpm/php.ini
sed -ie 's/;cgi.fix_pathinfo = 1/cgi.fix_pathinfo = 0/' /etc/php/8.4/fpm/php.ini
#sed -ie 's/;extension=pdo_pgsql/extension=pdo_pgsql/g' /etc/php/8.4/fpm/php.ini
#sed -ie 's/;extension=pgsql/extension=pgsql/g' /etc/php/8.4/fpm/php.ini

sudo tee -a /etc/php/8.4/fpm/php.ini <<EOF
   extension=uploadprogress
   extension=php_openssl
EOF

sudo systemctl restart nginx
sudo systemctl restart php8.4-fpm

echo "
#------------------------------------------------
# Install composer
#------------------------------------------------"
php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
php -r "if (hash_file('sha384', 'composer-setup.php') === 'c8b085408188070d5f52bcfe4ecfbee5f727afa458b2573b8eaaf77b3419b0bf2768dc67c86944da1544f06fa544fd47') { echo 'Installer verified'.PHP_EOL; } else { echo 'Installer corrupt'.PHP_EOL; unlink('composer-setup.php'); exit(1); }"
php composer-setup.php
php -r "unlink('composer-setup.php');"

sudo mv composer.phar /usr/local/bin/composer

# echo "
#--------------------------------------------------
# Installing PostgreSQL Server
#--------------------------------------------------"
# sudo sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
# curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg
# sudo apt update

# sudo apt -y install postgresql-16 postgresql-contrib php8.3-pgsql

# echo "=== Starting PostgreSQL service... ==="
# sudo systemctl start postgresql 
# sudo systemctl enable postgresql

# Create the new user with superuser privileges
# sudo -su postgres psql -c "CREATE USER drupaluser WITH PASSWORD 'abc1234@';"
# sudo -su postgres psql -c "CREATE DATABASE drupaldb;"
# sudo -su postgres psql -c "ALTER DATABASE drupaldb OWNER TO drupaluser;"
# sudo -su postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE drupaldb TO drupaluser;"

# sudo systemctl restart postgresql

echo "
#--------------------------------------------------
# Mariadb Installation
#--------------------------------------------------"
sudo apt install -y mariadb-server mariadb-client
sudo systemctl start mariadb.service
sudo systemctl enable mariadb.service

# sudo mariadb-secure-installation

sudo systemctl restart mariadb.service

sudo mariadb -uroot --password="" -e "CREATE DATABASE drupal_db;"
sudo mariadb -uroot --password="" -e "CREATE USER 'dbadmin'@'localhost' IDENTIFIED BY 'abc1234@';"
sudo mariadb -uroot --password="" -e "GRANT ALL ON drupal_db.* TO dbadmin@localhost WITH GRANT OPTION;"
sudo mariadb -uroot --password="" -e "FLUSH PRIVILEGES;"

sudo systemctl restart mariadb.service

echo "
#--------------------------------------------------
# Drupal installation
#--------------------------------------------------"
cd /opt && wget https://ftp.drupal.org/files/projects/drupal-11.3.9.tar.gz 
tar -zxvf drupal-11.3.9.tar.gz

mkdir /var/www/drupal
sudo cp -rf drupal-11.3.9/* /var/www/drupal
sudo chown -R www-data:www-data /var/www/drupal/
sudo chmod -R 755 /var/www/drupal/

sudo cat <<EOF > /etc/nginx/sites-available/drupal.conf
server {
    listen 80;
    listen [::]:80;
    server_name _;

    root /var/www/drupal;
    index index.php index.html index.htm;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php8.4-fpm.sock;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }

    location ~ /\.ht {
        deny all;
    }
}   
EOF

ln -s /etc/nginx/sites-available/drupal.conf /etc/nginx/sites-enabled/

nginx -t

sudo systemctl restart nginx.service
sudo systemctl restart php8.4-fpm

sudo chmod 644 /var/www/drupal/sites/default/settings.php
sudo nano /var/www/drupal/sites/default/settings.php

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

echo "
#--------------------------------------------------
#  Configure UFW to allow web traffic and SSH
#--------------------------------------------------"
sudo apt install -y ufw
sudo ufw allow 22/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Enable UFW
sudo ufw --force enable
sudo ufw reload

# nano /var/www/drupal/sites/default/settings.php <<EOF
# $settings['trusted_host_patterns'] = ['192\.168\.1\.13'];

echo "Drupal setup completed successfully."

# cd /var/www/drupal/
# composer create-project drupal/cms


