#!/bin/bash

# DEPLOYMENT SCRIPT
# -----------------
# Note: This is intended for CentOS/Redhat server, but with some modifications
# can be utilized on a debian/ubuntu based distribution. Simply change dnf
# commands to apt counterparts and firewall-cmd configuration to UFW (although
# Docker is known to disregard firewall wrappers and talk directly to iptables)

domain="piotr-machura.com"

[[ $EUID -ne 0 ]] && echo "This script must be run as root." && exit 1
[[-z "$(command -v docker &>/dev/null)" ]] && echo "No Docker runtime detected. Install it with ./deploy.sh init" && exit 1
[[-z "$(command -v docker-compose &>/dev/null)" ]] && echo "No docker-compose detected. Install it with ./deploy.sh init" && exit 1

case $1 in
    "init")
        default_domain="piotr-machura.com"
        [[ -z "$2" ]] && echo "Please specify your domain." && exit 1
        domain="$2"
        [[ "$domain" != "$default_domain" ]] && echo "Replacing $default_domain with $domain..." && \
            find ./deploy.sh ./config ./docker-compose.yml -type f -exec sed -i -e "s/$default_domain/$domain/g" {} \;

        # Enable docker repository, install engine and compose
        [[-z "$(command -v docker &>/dev/null)" ]] && \
            dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo && \
            dnf install docker-ce docker-ce-cli containerd.io || exit 1
        [[-z "$(command -v docker-compose &>/dev/null)" ]] && \
            curl -L "https://github.com/docker/compose/releases/download/1.28.4/docker-compose-$(uname -s)-$(uname -m)" -o /user/bin/docker-compose && \
            chmod +x /usr/bin/docker-compose || exit 1

        # Configure the firewall
        firewall-cmd --permanent --zone=public --add-service=http && \
            firewall-cmd --permanent --zone=public --add-service=https && \
            firewall-cmd --reload || exit 1

        # Get docker-mailserver's setup tool
        [[ ! -f "./config/setup.sh" ]] && \
            curl https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/v9.0.1/setup.sh > ./config/setup.sh && \
            chmod +x ./config/setup.sh || exit 1

        # Build the images and start the containers
        docker-compose up --build --detach || exit 1
        echo "
        Initial setup complete. Use
        ./deploy.sh ssl
        to obtain ssl certificates and
        ./deploy.sh user <username> <password>
        to add username@$domain to mailserver and carddav server."
        ;;

    "user"| "-u")
        # Add users to mailserver and radicale
        [[ [[ -z "$2" ]] || [[ -z "$3" ]] ]] && echo "Please provide arguments: <username> <password>" && exit 1
        docker exec -t radicale htpasswd -b -c /var/radicale/users "$2@$domain" "$3" && \
            ./config/setup.sh -c mail -p ./config/mailserver email add "$2@$domain" "$3" || exit 1
        echo "Added $2@$domain to email and carddav servers."
        ;;

    "ssl" | "-s")
        # Obtain SSL certificates
        docker exec -it nginx-certbot certbot --nginx --agree-tos -d "$domain" -d "www.$domain" -d "dav.$domain"
        ;;

    "mail" | "-m")
        # Pass arguments to docker-mailserver's setup.sh
        shift ; ./config/setup.sh -c mail -p ./config/mailserver "$@" || exit 1
        ;;

    "help" | "-h" | *)
        echo "
        Usage:
            init <domain> - install missing software, build the images and start the containers.
            -u | user <username> <password> - adds user@$domain to mailserver and carddav with given password.
            -s | ssl - obtainSSL certificates for $domain and www.$domain using Certbot.
            -m | mail - pass arguments to docker-mailserver's 'setup.sh' script.
            -h | help - dipslay this message."
        ;;
esac
