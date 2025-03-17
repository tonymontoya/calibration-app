#!/bin/bash
set -e

# ---------------------------
# 1. Update system and install packages
# ---------------------------
echo "Updating system packages..."
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv build-essential libpq-dev nginx postgresql postgresql-contrib

# ---------------------------
# 2. Configure PostgreSQL database and user
# ---------------------------
# Set these variables as needed
DB_USER="calibration_user"
DB_PASSWORD="yourpassword"
DB_NAME="calibration_db"

echo "Configuring PostgreSQL..."
sudo -u postgres psql <<EOF
DO
\$do\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DB_USER') THEN
      CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASSWORD';
   END IF;
END
\$do\$;
DROP DATABASE IF EXISTS $DB_NAME;
CREATE DATABASE $DB_NAME OWNER $DB_USER;
EOF

# ---------------------------
# 3. Set up application directory and Python environment
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
pip install flask flask_sqlalchemy gunicorn psycopg2-binary pandas

# (Optional) Clone your application repository here if not already present.
# For example: git clone <your_repo_url> $APP_DIR

# ---------------------------
# 4. Create systemd service for Gunicorn
# ---------------------------
echo "Creating systemd service file for Gunicorn..."
sudo tee /etc/systemd/system/calibration_app.service > /dev/null <<EOF
[Unit]
Description=Gunicorn instance to serve Calibration App
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
# 5. Configure Nginx as reverse proxy
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

echo "Setup complete. The calibration app and PostgreSQL database are installed and configured."
