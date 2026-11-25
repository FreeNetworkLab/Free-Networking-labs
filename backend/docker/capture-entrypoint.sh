#!/bin/sh
# capture-proxy の起動前に、自己署名証明書が無ければ作る（/tls は名前付きボリューム）。
set -eu
if [ ! -f /tls/cert.pem ] || [ ! -f /tls/key.pem ]; then
  openssl req -x509 -newkey rsa:2048 -keyout /tls/key.pem -out /tls/cert.pem -days 825 -nodes \
    -subj "/CN=capture-proxy" -addext "subjectAltName=DNS:localhost,IP:127.0.0.1" 2>/dev/null
  echo "capture-proxy の証明書を作りました"
fi
cd /app/capture-proxy
exec node server.js
