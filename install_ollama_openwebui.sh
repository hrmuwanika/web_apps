#!/bin/bash

sudo apt update && sudo apt upgrade

# Install ollama
curl -fsSL https://ollama.com/install.sh | sudo sh
sudo systemctl enable ollama
sudo systemctl status ollama

ollama pull gemma3:4b

# Install python3
sudo apt install python3-dev python3-venv python3-pip

python3 -m venv venv
source venv/bin/activate

cd /opt
sudo mkdir open-webui
sudo python3.11 -m venv /opt/open-webui
sudo /opt/open-webui/bin/pip install --upgrade pip

# Install open web ui
cd /opt/open-webui/bin/
python3.11 -m pip install open-webui
python3.11 -m pip install ffmpeg

sudo useradd -r -s /sbin/nologin openwebui
sudo chown -R openwebui:openwebui /opt/open-webui

# open web ui startup on boot
sudo cat <<EOF > /etc/systemd/system/openwebui.service
[Unit]
Description=Open WebUI
After=network.target

[Service]
Type=simple
User=openwebui
Group=openwebui
WorkingDirectory=/opt/open-webui
ExecStart=/bin/bash -c "source /opt/open-webui/bin/activate && /opt/open-webui/bin/open-webui serve"
Restart=always
Environment=ENV_VAR_NAME=value                        # Set any environment variables needed
PrivateTmp=true
ProtectSystem=full
ProtectHome=yes
NoNewPrivileges=true
AmbientCapabilities=CAP_NET_BIND_SERVICE              # If binding to low ports
LimitNOFILE=10000                                     # Limit the number of open files

[Install]
WantedBy=multi-user.target
EOF

sudo sytemctl enable open-webui
sudo sytemctl start open-webui

sudo apt install nginx -y
sudo sytemctl enable nginx
sudo sytemctl start nginx

sudo cat <<EOF > /etc/nginx/sites-available/openwebui.conf
server {
    listen 80;
    server_name example.com;

    access_log /var/log/nginx/openwebui_access.log;
    error_log /var/log/nginx/openwebui_error.log;

    location / {
        proxy_pass http://127.0.0.1:8080;

        client_max_body_size 300M;

        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;


        proxy_read_timeout 300;
        proxy_connect_timeout 300;
        proxy_send_timeout 300;

        # (Optional) Disable proxy buffering for better streaming response from models
        proxy_buffering off;

    }
}
EOF

sudo ln -s /etc/nginx/sites-available/openwebui.conf /etc/nginx/sites-enabled/

sudo nginx -t && sudo systemctl restart nginx

echo "Navigate to http://localhost/"

