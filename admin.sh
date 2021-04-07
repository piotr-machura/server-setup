#!/bin/bash -e

# DEPLOYMENT SCRIPT
# -----------------
# Note: The init is intended for CentOS/Redhat server, but with some modifications
# can be utilized on a debian/ubuntu based distribution. Simply change dnf
# commands to apt counterparts and firewall-cmd configuration to UFW

# Specify your base domain here
DOMAIN="piotr-machura.com"

# Message formatting function
function msg() {
    echo -e "\e[1;37m[$2 $1 \e[1;37m]\e[m"
}
green="\e[1;32m"
yellow="\e[1;33m"
red="\e[1;31m"
bold="\e[1;37m"
normal="\e[m"

_usage() {
    echo -en "$bold"
    echo -e "Server management script.$normal
Use this to manage user accounts, SSL certificates and email server.

$bold Usage:$normal
    -ca -$green add$normal username to CardDAV server.
    -cd -$red delete$normal username from CardDAV server.
    -s  - obtain SSL certificates for $DOMAIN, www.$DOMAIN, dav.$DOMAIN, and mail.$DOMAIN using Certbot.
    -m  - pass arguments to docker-mailserver's$yellow setup.sh$normal. Add --help for more information.
    -h  - display this message."
}
case $1 in
    "-u")
        [[ "$#" != "1" ]] && msg "Illegal arguments for $1: ${@:2}" $red && _usage && exit 1
        read -p "User (will become user@$DOMAIN): " user
        read -p -s "Password: " pass
        # Add users to mailserver and radicale
        docker exec -t radicale \
            htpasswd -B -b -c /var/radicale/data/users "$user@$DOMAIN" "$pass"
        ./data/mail/mail.sh -c mail -p ./data/mailserver/config email add "$user@$DOMAIN" "$pass"
        echo "Added $user@$DOMAIN to email and carddav servers."
        ;;

    "-s")
        [[ "$#" != "1" ]] && msg "Illegal arguments for $1: ${@:2}" $red && _usage && exit 1
        # Obtain SSL certificates
        docker exec -it nginx-certbot \
            certbot --nginx --agree-tos -d "$DOMAIN" -d "www.$DOMAIN" -d "dav.$DOMAIN" -d "mail.$DOMAIN"
        ;;

    "-m")
        # Pass arguments to docker-mailserver's setup.sh
        ./data/mail/mail.sh -c mail -p ./data/mailserver/config "${@:2}"
        ;;

    "-h" )
        [[ "$#" != "1" ]] && msg "Illegal arguments for $1: ${@:2}" $red && _usage && exit 1
        _usage
        ;;
    * )
        msg "Unknown argument: $1" $red && _usage && exit 1
        ;;
esac
