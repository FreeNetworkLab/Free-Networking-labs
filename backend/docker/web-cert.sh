#!/bin/sh
# nginx の起動前に、HTTPS の自己署名証明書が無ければ作る（/etc/nginx/ssl/fnl は名前付きボリューム）。
# 名前は FNL_HOSTNAME（既定 fnl）、IP はこのサーバーのもの。ブラウザには「安全でない」と出る（自己署名のため）。
set -eu
D=/etc/nginx/ssl/fnl
[ -f "$D/cert.pem" ] && [ -f "$D/key.pem" ] && exit 0
H="${FNL_HOSTNAME:-fnl}"
SAN="DNS:$H,DNS:localhost,IP:127.0.0.1"
for ip in $(ip -4 -o addr show 2>/dev/null | awk '{print $4}' | cut -d/ -f1 | grep -v '^127\.' | head -8); do SAN="$SAN,IP:$ip"; done
openssl req -x509 -newkey rsa:2048 -keyout "$D/key.pem" -out "$D/cert.pem" -days 825 -nodes \
  -subj "/CN=$H" -addext "subjectAltName=$SAN" 2>/dev/null
echo "HTTPS の証明書を作りました（$SAN）"
