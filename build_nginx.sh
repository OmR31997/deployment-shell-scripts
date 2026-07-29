#!/bin/bash

# Prompt user for inputs
read -p "Enter domain name (leave blank for none): " DOMAIN_NAME
read -p "Enter app name: " APP_NAME
read -p "Enter app port (default 4000): " APP_PORT
APP_PORT=${APP_PORT:-4000}

if [[ -n "$DOMAIN_NAME" ]]; then
    read -p "Enter SSL certificate path: " SSL_CERT
    read -p "Enter SSL certificate key path: " SSL_CERT_KEY
fi

config_nginx() {

    if [[ -L /etc/nginx/sites-enabled/default ]]; then
        sudo unlink /etc/nginx/sites-enabled/default
    fi

    if [[ -f /etc/nginx/sites-available/default ]]; then
        sudo rm -rf /etc/nginx/sites-available/default
    fi

    FILE="/etc/nginx/sites-available/$APP_NAME.conf"

    # Base HTTP block
    sudo tee "$FILE" > /dev/null <<EOF
server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN_NAME:-_};

    location / {
        proxy_pass http://localhost:$APP_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
EOF

    # If domain + certs are provided, add HTTPS block
    if [[ -n "$DOMAIN_NAME" && -n "$SSL_CERT" && -n "$SSL_CERT_KEY" ]]; then
        sudo tee -a "$FILE" > /dev/null <<EOF

    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name $DOMAIN_NAME;

    ssl_certificate $SSL_CERT;
    ssl_certificate_key $SSL_CERT_KEY;

    location / {
        proxy_pass http://localhost:$APP_PORT;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
EOF
    else
        echo "}" | sudo tee -a "$FILE" > /dev/null
    fi

    # Enable site
    sudo ln -sf "$FILE" "/etc/nginx/sites-enabled/$APP_NAME.conf"
}

reload_nginx(){
        if sytemctl is-active --quiet nginx; then
                echo "Reloading Nginx..."
                sudo systemctl reload nginx
        else
                echo "Starting Nginx..."
                sudo systemctl start nginx
                sudo systemctl enable nginx
        fi

        echo "NGINX CONFIGURATION RELOADED SUCCESSFULLY"
}

config_nginx
reload_nginx