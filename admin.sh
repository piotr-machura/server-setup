#!/bin/bash -e

# DEPLOYMENT SCRIPT
# -----------------
# Note: The init is intended for CentOS/Redhat server, but with some modifications
# can be utilized on a debian/ubuntu based distribution. Simply change dnf
# commands to apt counterparts and firewall-cmd configuration to UFW

# Specify your base domain here
DOMAIN="piotr-machura.com"

# Message formatting functions
green="\e[1;32m"
yellow="\e[1;33m"
red="\e[1;31m"
bold="\e[1;37m"
normal="\e[m"
function msg() {
    echo -e "$bold=>$2 $1 \e[m"
}
_usage() {
    echo -en "$bold"
    echo -e "Server management script.$normal
Use this to manage user accounts, SSL certificates and email server.
$bold
Usage:$normal
    -ca -$green add$normal username to CardDAV server. Prompts for input.
    -cd -$red delete$normal username from CardDAV server. Prompts for input.
    -cl - list CardDAV users.
    -s  - obtain SSL certificates for $DOMAIN, www.$DOMAIN, dav.$DOMAIN, and mail.$DOMAIN using Certbot.
    -m  - pass arguments to docker-mailserver's$yellow setup.sh$normal. Add$green help$normal for more information.
    -h  - display this message."
}
case $1 in
    "-ca")
        [[ "$#" != "1" ]] && msg "Illegal arguments for $1: ${@:2}" $red && _usage && exit 1
        echo -ne "$bold=>$green Username:$normal "
        read user
        echo -ne "$bold=>$green Password:$normal "
        read -s pass
        # Add users to mailserver and radicale
        docker exec -t radicale \
            htpasswd -B -b /var/radicale/data/users "$user" "$pass"
        msg "Added $user to CardDAV server" $green
        ;;

    "-cd")
        [[ "$#" != "1" ]] && msg "Illegal arguments for $1: ${@:2}" $red && _usage && exit 1
        echo -ne "$bold=>$yellow Username:$normal "
        read user
        docker exec -t radicale \
            htpasswd -D /var/radicale/data/users "$user"
        msg "Removed $user from CardDAV server" $green
        ;;

    "-cl")
        [[ "$#" != "1" ]] && msg "Illegal arguments for $1: ${@:2}" $red && _usage && exit 1
        while read line; do echo ${line%%:*}; done < ./data/radicale/users
        ;;

    "-s")
        [[ "$#" != "1" ]] && msg "Illegal arguments for $1: ${@:2}" $red && _usage && exit 1
        # Obtain SSL certificates
        docker exec -it nginx-certbot \
            certbot --nginx --agree-tos -d "$DOMAIN" -d "www.$DOMAIN" -d "dav.$DOMAIN" -d "mail.$DOMAIN"
        ;;

    "-m")
        # Pass arguments to docker-mailserver's setup.sh
        ./data/mailserver/setup.sh -c mailserver -p $(pwd)/data/mailserver/config "${@:2}"
        ;;

    "-h" )
        [[ "$#" != "1" ]] && msg "Illegal arguments for $1: ${@:2}" $red && _usage && exit 1
        _usage
        ;;
    * )
        msg "Unknown argument: $1" $red && _usage && exit 1
        ;;
esac
