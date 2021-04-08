#!/bin/bash -e

# DEPLOYMENT SCRIPT
# -----------------
# Note: The "-i" flag is intended for CentOS/Redhat server, but with some
# modifications can be utilized on a debian/ubuntu based distribution. Simply
# change dnf commands to apt counterparts and firewall-cmd configuration to UFW

# Specify your base domain here
DOMAIN="piotr-machura.com"
# This domain will be replaced if it differs from DOMAIN
DEFAULT_DOMAIN="piotr-machura.com"

# Message formatting
green="\e[1;32m"
yellow="\e[1;33m"
blue="\e[1;34m"
red="\e[1;31m"
bold="\e[1;37m"
teal="\e[1;36m"
normal="\e[m"

msg() {
    echo -e "$2=>$bold $1 \e[m"
}

_usage() {
    echo -en "$blue"
    echo -e "USAGE:$bold
    Server deployment and management script.$normal
    Use this to install all of the required tools, manage user accounts, SSL certificates and email server.
$teal
    Flags:$normal
    $bold-i$normal  -$yellow initialize$normal the server, downloading the necessary tools.
    $bold-da$normal -$green add$normal username to CardDAV server. Prompts for input.
    $bold-dd$normal -$red delete$normal username from CardDAV server. Prompts for input.
    $bold-dl$normal - list CardDAV users.
    $bold-s$normal  - obtain SSL certificates for $DOMAIN, www.$DOMAIN, dav.$DOMAIN, and mail.$DOMAIN using Certbot.
    $bold-m$normal  - pass arguments to docker-mailserver's$yellow setup.sh$normal. Add$green help$normal for more information.
    $bold-mk$normal - generate/print a DKIM key for your mailserver.$yellow Warning:$bold at least one email account must exist before generation.$normal
    $bold-h$normal  - display this message."
}

case $1 in
    "-i")
        [[ "$#" != "1" ]] && msg "Illegal arguments for $1: ${@:2}" $red && _usage && exit 1
        if [[ "$DOMAIN" != "$DEFAULT_DOMAIN" ]]; then
            msg "Replacing $DEFAULT_DOMAIN with $DOMAIN" $yellow
            find ./config ./docker-compose.yml -type f -exec sed -i -e "s/$DEFAULT_DOMAIN/$DOMAIN/g" {} \;
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
        serv=$(firewall-cmd --list-services --zone=public)
        [[ ! "$serv" == *"http"* ]] && firewall-cmd --permanent --zone=public --add-service=http
        [[ ! "$serv" == *"https"* ]] && firewall-cmd --permanent --zone=public --add-service=https
        [[ ! "$serv" == *"imap"* ]] && firewall-cmd --permanent --zone=public --add-service=imap
        [[ ! "$serv" == *"smtp"* ]] && firewall-cmd --permanent --zone=public --add-service=smtp
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
        ;;

    "-da")
        [[ "$#" != "1" ]] && msg "Illegal arguments for $1: ${@:2}" $red && _usage && exit 1
        echo -ne "$bold=>$teal Username:$normal "
        read -r user
        echo -ne "$bold=>$teal Password:$normal "
        read -rs pass
        # Add users to mailserver and radicale
        docker exec -t radicale \
            htpasswd -B -b /var/radicale/data/users "$user" "$pass"
        msg "Added $user to CardDAV server" $green
        ;;

    "-dd")
        [[ "$#" != "1" ]] && msg "Illegal arguments for $1: ${@:2}" $red && _usage && exit 1
        echo -ne "$bold=>$yellow Username:$normal "
        read -r user
        docker exec -t radicale \
            htpasswd -D /var/radicale/data/users "$user"
        msg "Removed $user from CardDAV server" $green
        ;;

    "-dl")
        [[ "$#" != "1" ]] && msg "Illegal arguments for $1: ${@:2}" $red && _usage && exit 1
        while read -r line; do echo ${line%%:*}; done < ./data/radicale/users
        ;;

    "-s")
        [[ "$#" != "1" ]] && msg "Illegal arguments for $1: ${@:2}" $red && _usage && exit 1
        docker exec -it nginx-certbot \
            certbot --nginx --agree-tos -d "$DOMAIN" -d "www.$DOMAIN" -d "dav.$DOMAIN" -d "mail.$DOMAIN"
        ;;

    "-m")
        ./data/mailserver/setup.sh -c mailserver -p $(pwd)/data/mailserver/config "${@:2}"
        ;;

    "-mk")
        [[ "$#" != "1" ]] && msg "Illegal arguments for $1: ${@:2}" $red && _usage && exit 1
        if [[ -z $(ls ./data/mailserver/config/opendkim/keys) ]]; then
            msg "Generating DKIM keys for $DOMAIN" $teal
            ./admin.sh -m config dkim
        fi
        msg "DKIM TXT record:" $teal
        # The public key is VERY ugly, unix magic fixes it
        cat data/mailserver/config/opendkim/keys/$DOMAIN/mail.txt | tr -d '\n()' | sed 's/"[\t| ]*"//g' | sed "s/[\t| ];.*//"
        echo ''
        msg "SPF TXT record:" $teal
        echo -e "\t\tIN\tTXT\t\"v=spf1 mx a:mail.$DOMAIN -all\""
        msg "DMARC TXT record:" $teal
        echo -e "_dmarc\t\tIN\tTXT\t\"v=DMARC1; p=none; rua=mailto:dmarc.report@$DOMAIN; ruf=mailto:dmarc.report@$DOMAIN; sp=none; ri=86400\""
        ;;

    "-h")
        [[ "$#" != "1" ]] && msg "Illegal arguments for $1: ${@:2}" $red && _usage && exit 1
        _usage
        ;;
    * )
        msg "Unknown argument: $1" $red && _usage && exit 1
        ;;
esac
