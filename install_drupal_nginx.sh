#!/bin/bash

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo "============= Update Server ================"
sudo apt update && sudo apt upgrade -y
sudo apt autoremove -y

sudo apt install nginx -y
sudo systemctl enable nginx.service
sudo systemctl start nginx.service

sudo apt install -y php8.3 php8.3-common php8.3-cli php8.3-intl php8.3-xmlrpc php8.3-mysql php8.3-zip php8.3-gd php8.3-tidy php8.3-mbstring php8.3-curl php8.3-xml php-pear \
php8.3-bcmath php8.3-pspell php8.3-curl php8.3-ldap php8.3-soap unzip git curl php8.3-gmp php8.3-imagick php8.3-fpm php8.3-redis php8.3-apcu postfix php8.3-mysql \
 bzip2 imagemagick ffmpeg libsodium23 fail2ban libpng-dev libjpeg-dev libtiff-dev 

sed -i "s/\;date\.timezone\ =/date\.timezone\ =\ Africa\/Kigali/g" /etc/php/8.3/fpm/php.ini
sed -i "s/max_execution_time = 30/max_execution_time = 600/" /etc/php/8.3/fpm/php.ini
sed -i "s/max_input_time = 60/max_input_time = 1000/" /etc/php/8.3/fpm/php.ini
sed -i "s/;max_input_vars = 1000/max_input_vars = 7000/" /etc/php/8.3/fpm/php.ini
sed -i "s/error_reporting = E_ALL \& \~E_DEPRECATED/error_reporting = E_ALL \& \~E_NOTICE \& \~E_DEPRECATED/" /etc/php/8.3/fpm/php.ini
sed -i "s/short_open_tag = Off/short_open_tag = On/" /etc/php/8.3/fpm/php.ini
sed -i "s/upload_max_filesize = 2M/upload_max_filesize = 500M/" /etc/php/8.3/fpm/php.ini
sed -i "s/post_max_size = 8M/post_max_size = 500M/" /etc/php/8.3/fpm/php.ini
sed -i "s/memory_limit = 128M/memory_limit = 512M/" /etc/php/8.3/fpm/php.ini

tee -a /etc/php/8.3/fpm/php.ini <<EOF

   file_uploads = On
   allow_url_fopen = On
   extension=pdo_pgsql
   extension=pgsql
   
EOF

systemctl restart nginx
systemctl restart php8.3-fpm

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

sudo mariadb -uroot --password="" -e "CREATE DATABASE drupaldb DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mariadb -uroot --password="" -e "CREATE USER 'drupaluser'@'localhost' IDENTIFIED BY 'abc1234@';"
sudo mariadb -uroot --password="" -e "GRANT ALL PRIVILEGES ON drupaldb.* TO 'drupaluser'@'localhost';"
sudo mariadb -uroot --password="" -e "FLUSH PRIVILEGES;"

sudo systemctl restart mariadb.service

cd /usr/src && wget https://ftp.drupal.org/files/projects/drupal-11.1.2.tar.gz 
tar -zxvf drupal-11.1.2.tar.gz
sudo mv drupal-11.1.2 /var/www/html/drupal
sudo chown -R www-data:www-data /var/www/html/drupal/
sudo chmod -R 755 /var/www/html/drupal/

sudo cat << EOF > /etc/apache2/sites-available/drupal.conf <<NGINX

server {
    listen 80;
    listen [::]:80;
    root /var/www/html/drupal;
    index  index.php;
    server_name  $WEBSITE_NAME;

    # Log files
    access_log /var/log/nginx/drupal.access.log;
    error_log /var/log/nginx/drupal.error.log;
    
    client_max_body_size 100M;
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

ln -s /etc/nginx/sites-available/drupal.conf /etc/nginx/sites-enabled/

nginx -t

sudo systemctl restart nginx.service
sudo systemctl restart php8.3-fpm

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


