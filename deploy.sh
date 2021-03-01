#!/bin/bash
homedir=$(pwd)
# Enable docker repository, install engine and compose
dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
dnf install docker-ce docker-ce-cli containerd.io
curl -L "https://github.com/docker/compose/releases/download/1.28.4/docker-compose-$(uname -s)-$(uname -m)" -o /user/bin/docker-compose
chmod +x /usr/bin/docker-compose

# Create directories for docker volumes
mkdir --parents $homedir/data/html $homedir/data/letsencrypt
# Build the nginx-certbot image
cd $homedir/build
docker build -t nginx-certbot .
# Run the containers
cd $homedir
docker-compose up --daemonize
# Obtain letsencrypt certificates
docker exec -it webserver certbot --nginx
