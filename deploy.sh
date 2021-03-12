#!/bin/bash -e

# DEPLOYMENT SCRIPT
# -----------------
# Note: This is intended for CentOS/Redhat server, but with some modifications
# can be utilized on a debian/ubuntu based distribution. Simply change dnf
# commands to apt counterparts and firewall-cmd configuration to UFW (although
# Docker is known to disregard firewall wrappers and talk directly to iptables)

# Specify your base domain here
DOMAIN="piotr-machura.com"

_usage() {
    echo "
    Server deployment and management script.

    Use this to install, manage user accounts and email server. 

    Usage:
        init - install missing software, build the images and start the containers.
        -u  | user <username> <password> - adds username@$DOMAIN to mailserver and carddav with given password.
        -s  | ssl - obtain SSL certificates for $DOMAIN, www.$DOMAIN, dav.$DOMAIN, and mail.$DOMAIN using Certbot.
        -m  | mail - safely pass arguments to docker-mailserver's 'setup.sh' script located under ./data/mail.sh.
        -h  | help - display this message."
    exit 1
}

[[ $EUID -ne 0 ]] && echo "This script must be run as root.\n" && _usage
[[-z "$(command -v docker &>/dev/null)" ]] && echo "No Docker runtime detected. Install it with ./deploy.sh init\n" && _usage
[[-z "$(command -v docker-compose &>/dev/null)" ]] && echo "No docker-compose detected. Install it with ./deploy.sh init\n" && _usage
[[ ! -f "./data/mail.sh" ]] && echo "No docker-mailserver setup.sh script found. Install it with ./deploy.sh init" && _usage



case $1 in
    "init")
        [[ "$#" != "1" ]] && echo "Illegal arguments for $1: ${@:2}" && _usage
        # Change all occurences of the base domain
        default_domain="piotr-machura.com"
        [[ "$DOMAIN" != "$default_domain" ]] && echo "Replacing $default_domain with $DOMAIN..." && \
            find ./config ./docker-compose.yml -type f -exec sed -i -e "s/$default_domain/$DOMAIN/g" {} \;

        # Enable docker repository, install engine and compose
        if [[ -z "$(command -v docker &>/dev/null)" ]]; then
            dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
            dnf install docker-ce docker-ce-cli containerd.io
        fi
        if [[-z "$(command -v docker-compose &>/dev/null)" ]]; then
            curl -L "https://github.com/docker/compose/releases/download/1.28.4/docker-compose-$(uname -s)-$(uname -m)" -o /user/bin/docker-compose
            chmod +x /usr/bin/docker-compose
        fi

        # Configure the firewall
        firewall-cmd --permanent --zone=public --add-service=http
        firewall-cmd --permanent --zone=public --add-service=https
        firewall-cmd --reload

        # Get docker-mailserver's setup tool
        if [[ ! -f "./data/mail.sh" ]]; then
            curl https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/v9.0.1/setup.sh > ./data/mail.sh
            chmod +x ./data/mail.sh
        fi
        # TODO: Add mailserver DNS help here

        # Build the images and start the containers
        docker-compose up --build --detach
        echo "
        Initial setup complete. Use
        ./deploy.sh ssl
        to obtain ssl certificates and
        ./deploy.sh user <username> <password>
        to add username@$DOMAIN to email and carddav."
        ;;

    "user"| "-u")
        [[ "$#" != "3" ]] && echo "Please provide arguments: <username> <password>" && _usage
        # Add users to mailserver and radicale
        docker exec -t radicale htpasswd -b -c /var/radicale/data/users "$2@$DOMAIN" "$3" && \
            ./data/mail.sh -c mail -p ./config/mailserver email add "$2@$DOMAIN" "$3"
        echo "Added $2@$DOMAIN to email and carddav servers."
        ;;

    "ssl" | "-s")
        [[ "$#" != "1" ]] && echo "Illegal arguments for $1: ${@:2}" && _usage
        # Obtain SSL certificates
        docker exec -it nginx-certbot \
            certbot --nginx --agree-tos -d "$DOMAIN" -d "www.$DOMAIN" -d "dav.$DOMAIN" -d "mail.$DOMAIN"
        ;;

    "mail" | "-m")
        # Pass arguments to docker-mailserver's setup.sh
        ./data/mail.sh -c mail -p ./config/mailserver "${@:2}"
        ;;

    "help" | "-h" | *)
        [[ "$#" != "1" ]] && echo "Illegal arguments for $1: ${@:2}"
        _usage
        ;;
esac
