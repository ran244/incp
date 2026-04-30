#!/bin/sh
set -eu

CERT=/etc/nginx/ssl/inception.crt
KEY=/etc/nginx/ssl/inception.key

# Generate SSL certificate if it doesn't exist yet
if [ ! -f "$CERT" ] || [ ! -f "$KEY" ]; then
  openssl req -x509 -nodes -newkey rsa:2048 -days 365 \
    -keyout "$KEY" -out "$CERT" \
    -subj "/C=JO/ST=AMMAN/L=AMMAN/O=42/OU=42/CN=${DOMAIN_NAME}"
fi

exec "$@"
