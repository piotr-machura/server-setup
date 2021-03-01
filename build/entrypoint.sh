#!/bin/sh
/usr/sbin/crond -f -d 8 &
/usr/sbin/nginx -g "daemon off;"
