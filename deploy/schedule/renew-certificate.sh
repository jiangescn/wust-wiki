#!/bin/sh
set -eu
site=/opt/1panel/www/sites/schedule.wiki.jianges.com
cert=/opt/wust-schedule/letsencrypt/live/schedule.wiki.jianges.com
docker run --rm \
  -v /opt/wust-schedule/letsencrypt:/etc/letsencrypt \
  -v "$site/acme:/var/www/acme" \
  certbot/certbot:latest renew --quiet
if ! cmp -s "$cert/fullchain.pem" "$site/ssl/fullchain.pem"; then
  install -m 644 "$cert/fullchain.pem" "$site/ssl/fullchain.pem"
  install -m 600 "$cert/privkey.pem" "$site/ssl/privkey.pem"
  docker exec 1Panel-openresty-hRNC /usr/local/openresty/nginx/sbin/nginx -t
  docker exec 1Panel-openresty-hRNC /usr/local/openresty/nginx/sbin/nginx -s reload
fi
