#!/usr/bin/env bash
# コンテナ版 Free-Networking-labs の初期化と起動（設計：設計メモ（非公開））。何度実行しても安全。
#   1. .env を作る（JWT の鍵、実行ユーザーのuid/gid、ラボのルート）
#   2. clab-api-server を起動し、初回だけ、グループと最初の管理者を作る（公式イメージ既定の admin は消す）
#   3. 全サービスを起動する
# 前提：Docker（compose プラグイン）、画面のビルド（frontend/dist）、証明書（backend/nginx/certs）、
#       capture-proxy の証明書（backend/capture-proxy/certs）。ホストの nginx など 80/443 の使用者は止めておく。
# 使い方：backend/compose/init.sh [管理者名（既定: fnladmin）]
#         backend/compose/init.sh --reset-password [管理者名]   管理者のパスワードを作り直して表示する（控え忘れ・紛失用）
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE"
RESET=0
if [ "${1:-}" = "--reset-password" ]; then RESET=1; shift; fi
ADMIN="${1:-fnladmin}"

command -v docker >/dev/null || { echo "docker が見つかりません" >&2; exit 1; }
D=(docker); docker info >/dev/null 2>&1 || D=(sudo docker)
[ -f ../../frontend/dist/index.html ] || { echo "frontend/dist がありません（配布版に含まれます。gitなら npm run build）" >&2; exit 1; }
for f in ../nginx/certs/cert.pem ../nginx/certs/key.pem ../capture-proxy/certs/cert.pem ../capture-proxy/certs/key.pem; do
  [ -f "$f" ] || { echo "$f がありません（tools/install.sh が作る証明書です）" >&2; exit 1; }
done

if [ ! -f .env ]; then
  ( umask 077
    {
      echo "FNL_UID=$(id -u)"
      echo "FNL_GID=$(id -g)"
      echo "FNL_LABS_ROOT=/var/lib/containerlab/labs"
      echo "JWT_SECRET=$(openssl rand -hex 32)"
    } > .env )
  echo ".env を作りました（JWT の鍵を含むので、他人に見せないでください）"
fi
# shellcheck disable=SC1091
. ./.env
[ -d "$FNL_LABS_ROOT" ] || sudo mkdir -p "$FNL_LABS_ROOT"

"${D[@]}" compose up -d clab-api-server
for _ in $(seq 1 30); do
  "${D[@]}" compose exec -T clab-api-server true 2>/dev/null && break; sleep 1
done

if [ "$RESET" = 1 ]; then
  "${D[@]}" compose exec -T clab-api-server getent passwd "$ADMIN" >/dev/null || { echo "$ADMIN というアカウントがありません" >&2; exit 1; }
  PW="$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-16)"
  echo "$ADMIN:$PW" | "${D[@]}" compose exec -T clab-api-server chpasswd
  echo "パスワードを作り直しました。  ユーザー名: $ADMIN   パスワード: $PW"
  exit 0
fi

# 初回だけ：グループと最初の管理者を作り、公式イメージ既定の admin を消す
if ! "${D[@]}" compose exec -T clab-api-server getent passwd "$ADMIN" >/dev/null; then
  PW="$(openssl rand -base64 18 | tr -d '/+=' | cut -c1-16)"
  "${D[@]}" compose exec -T clab-api-server sh -c "
    groupadd -f clab_api; groupadd -f clab_admins
    useradd -m -s /usr/sbin/nologin -G clab_api,clab_admins '$ADMIN'
    echo '$ADMIN:$PW' | chpasswd
    getent passwd admin >/dev/null && userdel -r admin 2>/dev/null || true"
  echo "最初の管理者を作りました。パスワードは今だけ表示します（控えてください）。"
  echo "  ユーザー名: $ADMIN"
  echo "  パスワード: $PW"
  echo "  （控え忘れたら: bash backend/compose/init.sh --reset-password）"
fi

"${D[@]}" compose up -d
echo "起動しました。ブラウザで https://<このサーバー>/ を開いてください。"
