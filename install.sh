#!/usr/bin/env bash

curl -fsSL https://get.docker.com | sh
curl -fsSL https://sing-box.app/install.sh | sh -s -- --beta
snap install core
snap refresh core
snap install --classic certbot
ln -s /snap/bin/certbot /usr/bin/certbot
