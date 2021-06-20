#!/bin/bash

################################################################################
# Script for installing Moodle v3.11 MariaDB, Apache2 and Php 7.3 on Ubuntu 18.04
# Authors: Henry Robert Muwanika

# Make a new file:
# sudo nano install_moodle.sh
# Place this content in it and then make the file executable:
# sudo chmod +x install_moodle.sh
# Execute the script to install Moodle:
# ./install_moodle.sh
#
################################################################################
#
#
# Set to "True" to install certbot and have ssl enabled, "False" to use http
ENABLE_SSL="True"
# Set the website name
WEBSITE_NAME="example.com"
# Provide Email to register ssl certificate
ADMIN_EMAIL="odoo@example.com"
##
#----------------------------------------------------
# Disable password authentication
#----------------------------------------------------
sudo sed -i 's/#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config 
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo service sshd restart

sudo apt install -y iptables iptables-persistent 

# firewall and iptables
ufw enable
ufw allow ssh
ufw allow http
ufw allow https

#--------------------------------------------------
# Update Server
#--------------------------------------------------
echo -e "\n============= Update Server ================"
sudo apt update
sudo apt upgrade -y
sudo apt autoremove -y

sudo apt install -y vim wget git

# Installation of MySQL database
sudo apt install -y mysql-server mysql-client

sudo systemctl enable mysql.service
sudo systemctl start mysql.service

#sudo mysql_secure_installation

cat >> /etc/mysql/mysql.conf.d/mysqld.cnf <<EOF
[mysqld]
        innodb_file_format = Barracuda 
        default_storage_engine = innodb
        innodb_file_per_table = 1
EOF

sudo systemctl restart mysql.service

mysql -u root -p<<MYSQL_SCRIPT
CREATE DATABASE moodle;
GRANT ALL PRIVILEGES ON moodle.* TO 'admin'@'localhost' IDENTIFIED WITH mysql_native_password BY 'abc1234!';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

sudo systemctl restart mysql.service

sudo apt install -y graphviz aspell ghostscript clamav 
sudo apt install -y apache2 php libapache2-mod-php php-cli php-mysql php-mbstring php-xmlrpc php-zip
sudo apt install -y php-gd php-xml php-bcmath php-ldap php-pspell php-curl php-intl php-soap php-pear 

sudo systemctl enable apache2.service
sudo systemctl start apache2.service

# Download & install Moodle
wget https://download.moodle.org/download.php/direct/stable311/moodle-latest-311.tgz
sudo tar -zxvf moodle-latest-311.tgz 
sudo mv moodle /var/www/html/

sudo chown -R www-data:www-data /var/www/html/moodle
sudo chmod -R 755 /var/www/html/moodle

sudo mkdir -p /var/moodledata
sudo chown -R www-data /var/moodledata
sudo chmod -R 777 /var/moodledata

sudo mkdir -p /var/quarantine
sudo chown -R www-data /var/quarantine

sudo rm -f /var/www/html/index.html

# Configure Apache2 HTTP Server
#------------------------------------------------------------------------------
cat >> /etc/apache2/sites-available/moodle.conf <<EOF

<VirtualHost *:80>
ServerAdmin admin@vps.rw
DocumentRoot /var/www/html/moodle/
ServerName vps.rw
ServerAlias courses.vps.rw

<Directory /var/www/html/moodle/>
Options +FollowSymlinks
AllowOverride All
Require all granted
</Directory>

ErrorLog ${APACHE_LOG_DIR}/error.log
CustomLog ${APACHE_LOG_DIR}/access.log combined

</VirtualHost>
EOF

#------------------------------------------------------------------------------

# Enable the Apache rewrite module
sudo a2enmod rewrite
sudo a2ensite moodle.conf
sudo systemctl restart apache2

#--------------------------------------------------
# Enable ssl with certbot
#--------------------------------------------------

if [ $ENABLE_SSL = "True" ] && [ $ADMIN_EMAIL != "odoo@example.com" ]  && [ $WEBSITE_NAME != "example.com" ];then
  sudo apt install snapd -y
  sudo apt-get remove certbot
  
  sudo snap install core
  sudo snap refresh core
  sudo snap install --classic certbot
  sudo ln -s /snap/bin/certbot /usr/bin/certbot
  sudo certbot --apache -d $WEBSITE_NAME --noninteractive --agree-tos --email $ADMIN_EMAIL --redirect
  sudo systemctl reload apache2
  
  echo "\n============ SSL/HTTPS is enabled! ========================"
else
  echo "\n==== SSL/HTTPS isn't enabled due to choice of the user or because of a misconfiguration! ======"
fi

echo -e "Access moodle https://courses.vps.rw/install.php"
