#!/bin/bash

required_packages(){
        sudo apt update

        if ! command -v node &>/dev/null; then
                sudo apt install -y nodejs
        fi

        if ! command -v npm &>/dev/null; then
                sudo apt install -y npm && sudo npm install -g pm2
        fi

        if ! command -v nginx &>/dev/null; then
                sudo apt install -y nginx
        fi

        if ! command -v certbot &>/dev/null;then
                sudo apt install certbot python3-certbot-nginx
        fi

        if command -v certbot && command -v nginx && command -v npm && command -v node &>/dev/null; then
                sudo echo "**REQUIRED PACKAGES ALREADY EXISTED"
        fi
}

required_packages