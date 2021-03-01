FROM nginx:alpine
RUN apk add certbot certbot-nginx
RUN mkdir /etc/letsencrypt
COPY ./renew /etc/periodic/daily/renew
RUN chmod +x /etc/periodic/daily/renew
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT [ "../entrypoint.sh" ]
