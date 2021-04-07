#!/bin/bash -e

# INITIAL DEPLOYMENT SCRIPT
# -------------------------
# This is intended for a CentOS/Redhat based Linux distribution. For
# Ubuntu/Debian change firewall commands to ufw counterparts and follow
# Docker/docker-compose installation instructions from official sources.

[[ "$#" != "0" ]] && echo "Ignored arguments: $@"

# Specify your base domain here
DOMAIN="piotr-machura.com"

# Message formatting function
# Message formatting functions
green="\e[1;32m"
yellow="\e[1;33m"
red="\e[1;31m"
bold="\e[1;37m"
teal="\e[1;36m"
normal="\e[m"
function msg() {
    echo -e "$bold=>$2 $1 \e[m"
}

DEFAULT_DOMAIN="piotr-machura.com"
if [[ "$DOMAIN" != "$DEFAULT_DOMAIN" ]]; then
    msg "Replacing $DEFAULT_DOMAIN with $DOMAIN" $yellow
    # find ./config ./docker-compose.yml -type f -exec sed -i -e "s/$DEFAULT_DOMAIN/$DOMAIN/g" {} \;
    msg "Done" $green
fi
msg "Initializing with domain $DOMAIN" $teal

if [[ -z "$(command -v docker 2>/dev/null)" ]]; then
    msg "No Docker engine in PATH, installing" $yellow
    dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo > /dev/null
    dnf install docker-ce docker-ce-cli containerd.io > /dev/null
    msg "Done" $green
else
    msg "Found Docker engine" $green
fi
if [[ -z "$(command -v docker-compose 2>/dev/null)" ]]; then
    msg "No docker-compose in PATH, installing" $yellow
    curl -L "https://github.com/docker/compose/releases/download/1.28.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/bin/docker-compose
    chmod +x /usr/bin/docker-compose
    msg "Done" $green
else
    msg "Found docker-compose" $green
fi

msg "Configuring the firewall" $teal
firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --permanent --zone=public --add-service=https
firewall-cmd --permanent --zone=public --add-service=imap
firewall-cmd --permanent --zone=public --add-service=smtp
firewall-cmd --reload
msg "Done" $green

if [[ ! -f "./data/mailserver/setup.sh" ]]; then
    msg "Mailserver admin script not found, downloading" $yellow
    curl https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/v9.0.1/setup.sh > ./data/mailserver/setup.sh
    chmod +x ./data/mailserver/setup.sh
    msg "Done" $green
fi

msg "Starting the containers" $teal
docker-compose up --detach
msg "Initial setup complete" $green

if [[ -z $(ls ./data/letsencrypt/live 2>/dev/null) ]]; then
    msg "No certificates found, launching Certbot" $yellow
    docker exec -it nginx-certbot \
        certbot --nginx --agree-tos -d "$DOMAIN" -d "www.$DOMAIN" -d "dav.$DOMAIN" -d "mail.$DOMAIN"
    msg "Restarting services" $yellow
    docker-compose restart
    msg "Done" $green
fi

msg "Further steps" $teal
echo -e "Create an email user with
$bold  ./admin.sh -m email add myuser@$DOMAIN$normal
and configure the email-related DNS records with
$bold  ./admin.sh -mk$normal"

msg "Deployment succesfull" $green
