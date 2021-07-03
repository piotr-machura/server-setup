FROM nginx:alpine

RUN set -xe; \
    apk add --no-cache certbot certbot-nginx; \
    mkdir /etc/letsencrypt /var/log/letsencrypt

COPY ./renew /etc/periodic/daily/renew
RUN chmod +x /etc/periodic/daily/renew

CMD sh -c "crond; nginx -g 'daemon off;'"
