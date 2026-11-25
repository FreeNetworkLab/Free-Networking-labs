# 画面（frontend）と nginx の設定を焼いたイメージ（fnl-web）。ビルドの文脈はリポジトリのルート：
#   docker build -f backend/nginx/Dockerfile -t fnl-web .
FROM node:22-alpine AS build
WORKDIR /w
COPY frontend/package.json frontend/package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY frontend/ ./
RUN npm run build
# 本番用の依存のライセンスファイルを集める（イメージの /licenses/frontend に入れる）
COPY backend/docker/collect-npm-licenses.sh /collect-npm-licenses.sh
RUN sh /collect-npm-licenses.sh /lic-frontend

FROM nginx:1.27-alpine
LABEL org.opencontainers.image.title="fnl-web" \
      org.opencontainers.image.description="Free-Networking-labs の画面と入口（nginx）" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/FreeNetworkLab/Free-Networking-labs" \
      org.opencontainers.image.documentation="含まれるソフトのライセンスは、イメージの /licenses を参照"
RUN apk add --no-cache openssl
COPY backend/nginx/fnl.conf /etc/nginx/conf.d/default.conf
COPY backend/nginx/admin-allow.conf /etc/nginx/fnl-admin-allow.conf
COPY --from=build /w/dist /var/www/free-networking-labs
COPY backend/docker/web-cert.sh /docker-entrypoint.d/40-fnl-cert.sh
RUN chmod +x /docker-entrypoint.d/40-fnl-cert.sh && mkdir -p /etc/nginx/ssl/fnl
# ライセンスの明記：このリポジトリの LICENSE、外部ソフトの一覧、GPL-2.0（busybox など）、画面の依存の LICENSE、Alpine のパッケージ一覧
COPY LICENSE THIRD-PARTY-LICENSES.md /licenses/
COPY licenses/GPL-2.0.txt /licenses/
COPY --from=build /lic-frontend /licenses/frontend
COPY backend/docker/collect-licenses.sh /tmp/collect-licenses.sh
RUN sh /tmp/collect-licenses.sh /licenses && rm /tmp/collect-licenses.sh
