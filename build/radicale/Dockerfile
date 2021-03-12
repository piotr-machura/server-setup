FROM alpine:3.13.2

RUN set -xe && \
    apk add --no-cache apache2-utils python3 py3-bcrypt py3-cffi py3-pip; \
    pip3 install bcrypt passlib pytz radicale; \
    mkdir -p /var/radicale/data/collections /var/radicale/config; \
    touch /var/radicale/data/users

COPY ./config.ini /var/radicale/config/config.ini

VOLUME ["/var/radicale/data"]
VOLUME ["/var/radicale/config"]

EXPOSE 8000

CMD sh -c "python3 -m radicale --config /var/radicale/config/config.ini"
