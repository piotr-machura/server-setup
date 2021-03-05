FROM nginx:alpine
RUN apk add certbot certbot-nginx
RUN mkdir /etc/letsencrypt
RUN mkdir /var/log/letsencrypt
COPY ./renew /etc/periodic/daily/renew
RUN chmod +x /etc/periodic/daily/renew
CMD sh -c "crond; nginx -g 'daemon off;'"
