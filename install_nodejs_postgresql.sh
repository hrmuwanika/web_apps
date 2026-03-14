#!/bin/bash

# Configuration - Change these as needed
NODE_MAJOR=24                           # Latest LTS as of 2026
DB_NAME="myapp_db"
DB_USER="app_user"
DB_PASS="secure_password_123"
APP_DIR="/var/www/myapp"

#--------------------------------------------------
# Update and upgrade the system
#--------------------------------------------------
echo "=== Updating system packages ==="
sudo apt update -y
sudo apt upgrade -y
sudo apt autoremove -y

#----------------------------------------------------
# Disabing password authentication
#----------------------------------------------------
echo "=== Disabling password authentication ... ==="
sudo apt -y install openssh-server
sudo sed -i 's/#ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config 
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo systemctl restart sshd

#--------------------------------------------------
# Setting up the timezones
#--------------------------------------------------
# set the correct timezone on ubuntu
timedatectl set-timezone Africa/Kigali
timedatectl

#--------------------------------------------------
# Installing of Nodejs
#--------------------------------------------------
echo "==== Installing Node.js  ===="
sudo apt install -y curl
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.4/install.sh | bash
source ~/.profile
nvm install $NODE_MAJOR
sudo apt install -y npm

#--------------------------------------------------
# Installing PostgreSQL Server
#--------------------------------------------------
echo "==== Installing PostgreSQL ===="
sudo apt install -y postgresql-16 postgresql-contrib

echo "=== Starting PostgreSQL service ==="
sudo systemctl start postgresql 
sudo systemctl enable postgresql

echo "==== Configuring Database ===="
sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"

echo "==== Installing Global Node Packages ===="
sudo npm install -g pm2 prisma

echo "==== Setting up Application Directory ===="
sudo mkdir -p $APP_DIR
sudo chown $USER:$USER $APP_DIR
cd $APP_DIR

npx create-next-app@latest user-management
cd user-management

echo "==== Initializing Node & Prisma ===="
npm init -y
npm install @prisma/client
npx prisma init

# Create a sample .env for Prisma
cat <<EOT > .env
DATABASE_URL="postgresql://$DB_USER:$DB_PASS@localhost:5432/$DB_NAME?schema=public"
EOT

sudo cat <<EOF > /etc/systemd/system/nodeapp.service

[Unit]
Description=Node.js Application
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$APP_DIR
ExecStart=/usr/bin/node /$APP_DIR/app.js
Restart=on-failure
Environment=NODE_ENV=production PORT=3000

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable nodeapp
sudo systemctl start nodeapp

echo "==== Setup Complete! ===="
