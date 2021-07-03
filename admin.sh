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
if [ -x "$(command -v tput)" ]; then
    bold="$(tput bold)"
    black="$(tput setaf 0)"
    red="$(tput setaf 1)"
    green="$(tput setaf 2)"
    yellow="$(tput setaf 3)"
    blue="$(tput setaf 4)"
    magenta="$(tput setaf 5)"
    cyan="$(tput setaf 6)"
    white="$(tput setaf 7)"
    normal="$(tput sgr0)"
fi

msg() {
    echo -e "${2}::${normal}${bold} ${1}${normal}"
}

_usage() {
cat <<EOF
${blue}${bold}USAGE:
${normal}Server deployment and management script.
Use this to install all of the required tools, manage user accounts, SSL certificates and email server.

${cyan}${bold}Flags:${normal}
${bold}-i${normal} - ${yellow}initialize${normal} the server, downloading the necessary tools.
${bold}-da${normal} - ${green}add${normal} username to CardDAV server. Prompts for input.
${bold}-dd${normal} - ${red}delete${normal} username from CardDAV server. Prompts for input.
${bold}-dl${normal} - list CardDAV users.
${bold}-s${normal}  - obtain SSL certificates for ${DOMAIN}, www.${DOMAIN}, dav.${DOMAIN}, and mail.${DOMAIN} using Certbot.
${bold}-m${normal}  - pass arguments to docker-mailserver's ${yellow}setup.sh${normal}. Add ${green}help${normal} for more information.
${bold}-mk${normal} - generate/print a DKIM key for your mailserver. ${yellow}${bold}Warning:${normal} at least one email account must exist before generation.
${bold}-h${normal}  - display this message.
EOF
}

_unknown_arg() {
    if [[ "$#" != "1" ]]; then
        msg "Illegal arguments for $1: ${@:2}" "$red"
        echo ''
        _usage
        exit 1
    fi
}

case $1 in
    "-i")
        _unknown_arg "$@"
        if [[ "$DOMAIN" != "$DEFAULT_DOMAIN" ]]; then
            msg "Replacing $DEFAULT_DOMAIN with $DOMAIN" "$yellow"
            find ./config ./docker-compose.yml -type f -exec sed -i -e "s/$DEFAULT_DOMAIN/$DOMAIN/g" {} \;
            msg "Done" "$green"
        fi
        msg "Initializing with domain $DOMAIN" "$cyan"

        if [[ -z "$(command -v docker 2>/dev/null)" ]]; then
            msg "No Docker engine in PATH, installing" "$yellow"
            dnf config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo > /dev/null
            dnf install docker-ce docker-ce-cli containerd.io > /dev/null
            msg "Done" "$green"
        else
            msg "Found Docker engine" "$green"
        fi
        if [[ -z "$(command -v docker-compose 2>/dev/null)" ]]; then
            msg "No docker-compose in PATH, installing" "$yellow"
            curl -L "https://github.com/docker/compose/releases/download/1.28.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/bin/docker-compose
            chmod +x /usr/bin/docker-compose
            msg "Done" "$green"
        else
            msg "Found docker-compose" "$green"
        fi

        msg "Configuring the firewall" "$cyan"
        serv=$(firewall-cmd --list-services --zone=public)
        [[ ! "$serv" == *"http"* ]] && firewall-cmd --permanent --zone=public --add-service=http
        [[ ! "$serv" == *"https"* ]] && firewall-cmd --permanent --zone=public --add-service=https
        [[ ! "$serv" == *"imap"* ]] && firewall-cmd --permanent --zone=public --add-service=imap
        [[ ! "$serv" == *"smtp"* ]] && firewall-cmd --permanent --zone=public --add-service=smtp
        firewall-cmd --reload
        msg "Done" "$green"

        if [[ ! -f "./data/mailserver/setup.sh" ]]; then
            msg "Mailserver admin script not found, downloading" "$yellow"
            curl https://raw.githubusercontent.com/docker-mailserver/docker-mailserver/v9.0.1/setup.sh > ./data/mailserver/setup.sh
            chmod +x ./data/mailserver/setup.sh
            msg "Done" "$green"
        fi

        msg "Copying .dist nginx config" "$yellow"
        for file in ./config/nginx/*.conf.dist; do
            newname=${file/.dist/}
            if [[ ! -f "$newname" ]]; then
                cp "$file" "$newname"
            else
                msg "Found $newname." "$green"
            fi
        done
        msg "Done" "$green"

        msg "Starting the containers" "$cyan"
        docker-compose up --detach
        msg "Initial setup complete" "$green"

        if [[ -z $(ls ./data/letsencrypt/live 2>/dev/null) ]]; then
            msg "No certificates found, launching Certbot" "$yellow"
            docker exec -it nginx-certbot \
                certbot --nginx --agree-tos -d "$DOMAIN" -d "www.$DOMAIN" -d "dav.$DOMAIN" -d "mail.$DOMAIN"
            msg "Restarting services" "$yellow"
            docker-compose restart
            msg "Done" "$green"
        fi

        msg "Further steps" "$cyan"
        echo -e "Create an email user with ${bold}./admin.sh -m email add myuser@${DOMAIN}${normal} and configure the email-related DNS records with ${bold}./admin.sh -mk${normal}"
        msg "Deployment succesfull" "$green"
        ;;

    "-da")
        _unknown_arg "$@"
        echo -ne "$bold=>$cyan Username:$normal "
        read -r user
        echo -ne "$bold=>$cyan Password:$normal "
        read -rs pass
        # Add users to mailserver and radicale
        docker exec -t radicale \
            htpasswd -B -b /var/radicale/data/users "$user" "$pass"
        msg "Added $user to CardDAV server" "$green"
        ;;

    "-dd")
        _unknown_arg "$@"
        echo -ne "$bold=>$yellow Username:$normal "
        read -r user
        docker exec -t radicale \
            htpasswd -D /var/radicale/data/users "$user"
        msg "Removed $user from CardDAV server" "$green"
        ;;

    "-dl")
        _unknown_arg "$@"
        while read -r line; do echo "${line%%:*}"; done < ./data/radicale/users
        msg "Success" "$green"
        ;;

    "-s")
        _unknown_arg "$@"
        docker exec -it nginx-certbot \
            certbot --nginx --agree-tos -d "$DOMAIN" -d "www.$DOMAIN" -d "dav.$DOMAIN" -d "mail.$DOMAIN"
        docker-compose restart webserver
        msg "Success" "$green"
        ;;

    "-m")
        ./data/mailserver/setup.sh -c mailserver -p "$(pwd)/data/mailserver/config" "${@:2}"
        msg "Success" "$green"
        ;;

    "-mk")
        _unknown_arg "$@"
        if [[ -z $(ls ./data/mailserver/config/opendkim/keys) ]]; then
            msg "Generating DKIM keys for $DOMAIN" "$cyan"
            ./admin.sh -m config dkim
        else
            msg "Found DKIM keys for $DOMAIN" "$green"
        fi
        msg "DKIM TXT record:" "$cyan"
        # The public key is VERY ugly, unix magic fixes it
        cat "data/mailserver/config/opendkim/keys/$DOMAIN/mail.txt" | tr -d '\n()' | sed 's/"[\t| ]*"//g' | sed "s/[\t| ];.*//"
        echo ''
        msg "SPF TXT record:" "$cyan"
        echo -e "\t\tIN\tTXT\t\"v=spf1 mx a:mail.$DOMAIN -all\""
        msg "DMARC TXT record:" "$cyan"
        echo -e "_dmarc\t\tIN\tTXT\t\"v=DMARC1; p=none; rua=mailto:dmarc.report@$DOMAIN; ruf=mailto:dmarc.report@$DOMAIN; sp=none; ri=86400\""
        ;;

    "-h")
        _unknown_arg "$@"
        _usage
        ;;
    * )
        msg "Unknown argument: $1" "$red" && _usage && exit 1
        ;;
esac
