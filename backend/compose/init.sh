#!/usr/bin/env bash
# コンテナ版 Free-Networking-labs の初期化と起動（設計：設計メモ（非公開））。何度実行しても安全。
#   1. --local のときだけ .env を作る（JWT の鍵、実行ユーザーのuid/gid、ラボのルート、COMPOSE_FILE）
#   2. 全サービスを起動する（docker compose up -d）。初回は、init-accounts が JWT の鍵と最初の管理者を作り、パスワードを表示する
#   イメージ版は、init.sh を使わず docker compose up -d だけでも同じ（パスワードは docker compose logs init-accounts）。
# 前提：Docker（compose プラグイン）。ホストの nginx など 80/443 の使用者は止めておく。
#   既定は、公開したイメージ（ghcr.io の fnl-web・fnl-proxy）を使う。画面のビルドも証明書も、イメージが用意する。
#   --local は、手元のコード（配布用tar.gz・ソース）を bind mount で使う（非推奨）。画面のビルド（frontend/dist）、
#   証明書（backend/nginx/certs、backend/capture-proxy/certs）が要る（tools/install.sh が用意する）。
# 使い方：backend/compose/init.sh [--local] [管理者名（既定: fnladmin）]
#         backend/compose/init.sh --reset-password [管理者名]   管理者のパスワードを作り直して表示する（控え忘れ・紛失用）
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
RESET=0
LOCAL=0
while [ "${1:-}" = "--reset-password" ] || [ "${1:-}" = "--local" ]; do
  case "$1" in --reset-password) RESET=1 ;; --local) LOCAL=1 ;; esac
  shift
done
ADMIN="${1:-fnladmin}"

command -v docker >/dev/null || { echo "docker が見つかりません" >&2; exit 1; }
D=(docker); docker info >/dev/null 2>&1 || D=(sudo docker)
if [ "$LOCAL" = 1 ]; then
  [ -f ../../frontend/dist/index.html ] || { echo "frontend/dist がありません（配布版に含まれます。gitなら npm run build）" >&2; exit 1; }
  for f in ../nginx/certs/cert.pem ../nginx/certs/key.pem ../capture-proxy/certs/cert.pem ../capture-proxy/certs/key.pem; do
    [ -f "$f" ] || { echo "$f がありません（tools/install.sh が作る証明書です）" >&2; exit 1; }
  done
fi

# .env は、手元のコード版（--local）のときだけ作る（イメージ版は .env なしで動く。JWT の鍵は init-accounts がボリュームに作る）。
# すでに .env があれば（以前の導入）、その値（JWT の鍵など）をそのまま使う
if [ "$LOCAL" = 1 ] && [ ! -f .env ]; then
  ( umask 077
    {
      echo "FNL_UID=$(id -u)"
      echo "FNL_GID=$(id -g)"
      echo "FNL_LABS_ROOT=/var/lib/containerlab/labs"
      echo "JWT_SECRET=$(openssl rand -hex 32)"
    } > .env )
  echo ".env を作りました（JWT の鍵を含むので、他人に見せないでください）"
fi
if [ "$LOCAL" = 1 ] && ! grep -q '^COMPOSE_FILE=' .env; then
  echo "COMPOSE_FILE=compose.yaml:compose.local.yaml" >> .env   # 手元のコードを使う（docker compose が .env を自動で読む）
fi
if [ -f .env ]; then
  # shellcheck disable=SC1091
  . ./.env
fi
FNL_LABS_ROOT="${FNL_LABS_ROOT:-/var/lib/containerlab/labs}"
[ -d "$FNL_LABS_ROOT" ] || sudo mkdir -p "$FNL_LABS_ROOT"
export FNL_ADMIN_USER="$ADMIN"   # init-accounts が、最初の管理者の名前に使う

if [ "$RESET" = 1 ]; then
  "${D[@]}" compose up -d clab-api-server
  for _ in $(seq 1 30); do
    "${D[@]}" compose exec -T clab-api-server true 2>/dev/null && break; sleep 1
  done
  "${D[@]}" compose exec -T clab-api-server getent passwd "$ADMIN" >/dev/null || { echo "$ADMIN というアカウントがありません" >&2; exit 1; }
  PW="$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-16)"
  echo "$ADMIN:$PW" | "${D[@]}" compose exec -T clab-api-server chpasswd
  echo "パスワードを作り直しました。  ユーザー名: $ADMIN   パスワード: $PW"
  exit 0
fi

# 起動する。初回は init-accounts（JWT の鍵と最初の管理者）が先に動き、clab-api-server はその後に起動する。
# 最初の管理者のパスワードは、init-accounts のログに出る。今回の起動で出た分だけを表示する
START="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
"${D[@]}" compose up -d
LOG="$("${D[@]}" compose logs --no-log-prefix --since "$START" init-accounts 2>/dev/null || true)"
if printf '%s' "$LOG" | grep -q "最初の管理者を作りました"; then
  printf '%s\n' "$LOG" | sed -n '/=====/,$p'
  echo "  （控え忘れたら: bash backend/compose/init.sh --reset-password）"
fi
echo "起動しました。ブラウザで https://<このサーバー>/ を開いてください。"
echo "ノードのイメージは、init-images が取得中かもしれません（数分）：docker compose logs -f init-images"
