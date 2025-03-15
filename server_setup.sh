#!/bin/bash
set -e

# ---------------------------
# 1. Update system and install packages
# ---------------------------
sudo apt-get update
sudo apt-get install -y python3 python3-pip python3-venv build-essential libpq-dev nginx postgresql postgresql-contrib

# ---------------------------
# 2. Setup PostgreSQL database and user
# ---------------------------
# Change these variables as needed
DB_USER="calibration_user"
DB_PASSWORD="yourpassword"
DB_NAME="calibration_db"

# Create PostgreSQL role and database
sudo -u postgres psql <<EOF
DO
\$do\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '$DB_USER') THEN
      CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASSWORD';
   END IF;
END
\$do\$;
CREATE DATABASE $DB_NAME OWNER $DB_USER;
EOF

# ---------------------------
# 3. Create application directory and Python virtual environment
# ---------------------------
APP_DIR="/opt/calibration_app"
sudo mkdir -p $APP_DIR
sudo chown $USER:$USER $APP_DIR

# Create a virtual environment and install Python dependencies
python3 -m venv $APP_DIR/venv
source $APP_DIR/venv/bin/activate
pip install --upgrade pip
pip install flask flask_sqlalchemy gunicorn psycopg2-binary pandas

# (Optional) Clone your application repository into APP_DIR here
# git clone <your_repo_url> $APP_DIR

# ---------------------------
# 4. Create a systemd service file for Gunicorn
# ---------------------------
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

# Reload systemd, start and enable the Gunicorn service
sudo systemctl daemon-reload
sudo systemctl start calibration_app.service
sudo systemctl enable calibration_app.service

# ---------------------------
# 5. Configure Nginx as a reverse proxy for the Flask app
# ---------------------------
NGINX_CONFIG="/etc/nginx/sites-available/calibration_app"
sudo tee $NGINX_CONFIG > /dev/null <<'EOF'
server {
    listen 80;
    server_name your_domain_or_IP;  # Replace with your domain name or server IP

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    }
}
EOF

# Enable the new site and restart Nginx
sudo ln -sf $NGINX_CONFIG /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

echo "Setup complete. The web application and PostgreSQL database are installed and configured."
