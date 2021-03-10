FROM alpine:3.13.2

RUN apk add --no-cache --virtual=run-deps \
    apache2-utils python3 py3-bcrypt py3-cffi py3-pip

RUN set -xe && \
    pip3 install bcrypt passlib pytz radicale

# Add user radicale
RUN mkdir -p /var/radicale/data/collections /var/radicale/config
RUN touch /var/radicale/data/users

VOLUME ["/var/radicale"]

COPY ./config.ini /var/radicale/config/config.ini

# expose radicale port
EXPOSE 8000

VOLUME ["/var/radicale/data"]
VOLUME ["/var/radicale/config"]

CMD sh -c "python3 -m radicale --config /var/radicale/config/config.ini"
