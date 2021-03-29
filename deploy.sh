#!/bin/bash -e

# DEPLOYMENT SCRIPT
# -----------------
# Note: The init is intended for CentOS/Redhat server, but with some modifications
# can be utilized on a debian/ubuntu based distribution. Simply change dnf
# commands to apt counterparts and firewall-cmd configuration to UFW

# Specify your base domain here
DOMAIN="piotr-machura.com"

_usage() {
    echo "
    Server deployment and management script.

    Use this to install, manage user accounts and email server.

    Usage:
        init - install missing software, build the images and start the containers.
        -u  <username> <password> - adds username@$DOMAIN to mailserver and carddav with given password.
        -s  - obtain SSL certificates for $DOMAIN, www.$DOMAIN, dav.$DOMAIN, and mail.$DOMAIN using Certbot.
        -m  - safely pass arguments to docker-mailserver's 'setup.sh' script located under ./data/mail.sh.
        -h  - display this message."
    exit 1
}

# Check if all the tools are avalible
[[ $EUID -ne 0 ]] && echo "This script must be run as root.\n" && _usage
[[-z "$(command -v docker &>/dev/null)" ]] && echo "No Docker runtime detected. Install it with ./deploy.sh init" && _usage
[[-z "$(command -v docker-compose &>/dev/null)" ]] && echo "No docker-compose detected. Install it with ./deploy.sh init" && _usage
[[ ! -f "./data/mail.sh" ]] && echo "No docker-mailserver setup.sh script found. Install it with ./deploy.sh init" && _usage

case $1 in
    "init")
        [[ "$#" != "1" ]] && echo "Illegal arguments for $1: ${@:2}" && _usage

        # Change all occurences of the base domain
        default_domain="piotr-machura.com"
        if [[ "$DOMAIN" != "$default_domain" ]]; then
            echo "Replacing $default_domain with $DOMAIN..."
            find ./config ./docker-compose.yml -type f -exec sed -i -e "s/$default_domain/$DOMAIN/g" {} \;
        fi

        # Enable docker repository, install engine and compose
        if [[ -z "$(command -v docker &>/dev/null)" ]]; then
            echo "Installing docker engine..."
            dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo > /dev/null
            dnf install docker-ce docker-ce-cli containerd.io > /dev/null
        fi
        if [[-z "$(command -v docker-compose &>/dev/null)" ]]; then
            echo "Installing docker compose..."
            curl -L "https://github.com/docker/compose/releases/download/1.28.4/docker-compose-$(uname -s)-$(uname -m)" -o /user/bin/docker-compose
            chmod +x /usr/bin/docker-compose
        fi

        # Configure the firewall
        echo "Configuring the firewall..."
        firewall-cmd --permanent --zone=public --add-service=http
        firewall-cmd --permanent --zone=public --add-service=https
        firewall-cmd --reload

        # Get docker-mailserver's setup tool
        if [[ ! -f "./data/mail.sh" ]]; then
            echo "Getting docker-mailserver's setup.sh..."
            curl https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/v9.0.1/setup.sh > ./data/mail.sh
            chmod +x ./data/mail.sh
        fi
        # TODO: Add mailserver DNS help here

        # Build the images and start the containers
        echo "Starting the containers..."
        docker-compose up --build --detach
        echo "
        Initial setup complete. Use
        ./deploy.sh ssl
        to obtain ssl certificates and
        ./deploy.sh user <username> <password>
        to add username@$DOMAIN to email and carddav."
        # TODO: Add general DNS help here.
        ;;

    "-u")
        [[ "$#" != "1" ]] && echo "Illegal arguments for $1: ${@:2}" && _usage
        read -p "User (will become user@$DOMAIN): " user
        read -p -s "Password: " pass
        # Add users to mailserver and radicale
        docker exec -t radicale \
            htpasswd -B -b -c /var/radicale/data/users "$user@$DOMAIN" "$pass"
        ./data/mail.sh -c mail -p ./config/mailserver email add "$user@$DOMAIN" "$pass"
        echo "Added $user@$DOMAIN to email and carddav servers."
        ;;

    "-s")
        [[ "$#" != "1" ]] && echo "Illegal arguments for $1: ${@:2}" && _usage
        # Obtain SSL certificates
        docker exec -it nginx-certbot \
            certbot --nginx --agree-tos -d "$DOMAIN" -d "www.$DOMAIN" -d "dav.$DOMAIN" -d "mail.$DOMAIN"
        ;;

    "-m")
        # Pass arguments to docker-mailserver's setup.sh
        ./data/mail.sh -c mail -p ./config/mailserver "${@:2}"
        ;;

    "-h" | *)
        [[ "$#" != "1" ]] && echo "Illegal arguments for $1: ${@:2}"
        _usage
        ;;
esac
