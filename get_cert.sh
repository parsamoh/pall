#!/usr/bin/env bash

read -rp "Enter DOMAIN: " DOMAIN_NAME
certbot certonly --standalone --register-unsafely-without-email --non-interactive --agree-tos -d $DOMAIN_NAME
