#!/bin/bash

# DEPLOYMENT SCRIPT
# -----------------
# Note: This is intended for CentOS/Redhat server, but with some modifications
# can be utilized on a debian/ubuntu based distribution. Simply change dnf
# commands to apt counterparts and firewall-cmd configuration to UFW (although
# Docker is known to disregard firewall wrappers and talk directly to iptables)

read -p "Specify your domain name (empty for default): "
domain="$REPLY"
[[ ! -z "$domain" ]] && echo "Replacing piotr-machura.com with $domain..." && \
    find ./config ./docker-compose.yml -type f -exec sed -i -e "s/piotr-machura.com/$domain/g" {} \;

# Enable docker repository, install engine and compose
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf install docker-ce docker-ce-cli containerd.io
curl -L "https://github.com/docker/compose/releases/download/1.28.4/docker-compose-$(uname -s)-$(uname -m)" -o /user/bin/docker-compose
chmod +x /usr/bin/docker-compose

# Configure the firewall
firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --permanent --zone=public --add-service=https
firewall-cmd --reload

# Create directories for docker volumes
mkdir --parents ./data/html ./data/letsencrypt ./data/log/letsencrypt
mkdir --parents ./data/mail/maildata ./data/mail/state ./data/log/mail
mkdir --parents ./data/roundcube/html ./data/roundcube/db
mkdir --parents ./data/openldap/ldap ./data/openldap/ldap-conf

# Build the nginx-certbot image and start the containers
docker-compose up --build --detach

# Obtain SSL certificates
docker exec -it nginx-certbot certbot --nginx --agree-tos
