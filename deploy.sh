#!/bin/bash

# DEPLOYMENT SCRIPT
# -----------------
# Note: This is intended for CentOS/Redhat server, but with some modifications
# can be utilized on a debian/ubuntu based distribution. Simply change dnf
# commands to apt counterparts and firewall-cmd configuration to UFW (although
# Docker is known to disregard firewall wrappers and talk directly to iptables)

read -p "Specify your domain name: "
domain="$REPLY"
[[ ! -z "$domain" ]] && [[ "$domain" != "piotr-machura.com" ]] && \
    find . -exec sed -e -i.bak "s/piotr-machura.com/$domain/g" {} \;

# Enable docker repository, install engine and compose
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf install docker-ce docker-ce-cli containerd.io
curl -L "https://github.com/docker/compose/releases/download/1.28.4/docker-compose-$(uname -s)-$(uname -m)" -o /user/bin/docker-compose
chmod +x /usr/bin/docker-compose

# Configure the firewall
firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --permanent --zone=public --add-service=https
firewall-cmd --reload

# Create directories for docker volumes and logs
mkdir --parents ./data/html ./data/letsencrypt
mkdir --parents ./data/log/letsencrypt

# Build the nginx-certbot image and start the containers
docker-compose up --build --detach

# Obtain SSL certificates
docker exec -it webserver certbot --nginx --agree-tos
