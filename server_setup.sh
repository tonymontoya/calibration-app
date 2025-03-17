#!/bin/bash
set -e

# ---------------------------
# 1. Update system and install packages
# ---------------------------
echo "Updating system packages..."
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv build-essential nginx

# ---------------------------
# 2. Set up application directory and Python environment
# ---------------------------
# Change APP_DIR to your preferred location
APP_DIR="/opt/calibration_app"
echo "Setting up application directory at $APP_DIR..."
sudo mkdir -p $APP_DIR
sudo chown $USER:$USER $APP_DIR

echo "Creating Python virtual environment..."
python3 -m venv $APP_DIR/venv

echo "Activating virtual environment and installing Python dependencies..."
source $APP_DIR/venv/bin/activate
pip install --upgrade pip
pip install flask flask_sqlalchemy gunicorn pandas

# (Optional) Clone your application repository here if not already present.
# For example: git clone <your_repo_url> $APP_DIR

# ---------------------------
# 3. Create systemd service for Gunicorn
# ---------------------------
echo "Creating systemd service file for the calibration app..."
sudo tee /etc/systemd/system/calibration_app.service > /dev/null <<EOF
[Unit]
Description=Gunicorn instance to serve Calibration App using SQLite
After=network.target

[Service]
User=$USER
Group=www-data
WorkingDirectory=$APP_DIR
Environment="PATH=$APP_DIR/venv/bin"
ExecStart=$APP_DIR/venv/bin/gunicorn --workers 3 --bind 127.0.0.1:8000 app:app

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd and starting the calibration_app service..."
sudo systemctl daemon-reload
sudo systemctl start calibration_app.service
sudo systemctl enable calibration_app.service

# ---------------------------
# 4. Configure Nginx as a reverse proxy
# ---------------------------
# Replace "your_domain_or_IP" with your actual domain name or server IP
NGINX_CONFIG="/etc/nginx/sites-available/calibration_app"
echo "Creating Nginx configuration..."
sudo tee $NGINX_CONFIG > /dev/null <<EOF
server {
    listen 80;
    server_name your_domain_or_IP;

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
    }
}
EOF

echo "Enabling Nginx site and restarting Nginx..."
sudo ln -sf $NGINX_CONFIG /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

echo "Setup complete. The calibration app using SQLite is installed and configured."
