#!/usr/bin/env bash
# 利用者（学生・先生など）のアカウントを作る。
# 使い方:
#   コンテナ方式（既定の導入）: bash tools/add-user.sh [--dry-run] [--prompt] <ユーザー名>...     （Docker が使える人）
#   従来の方式（--legacy）    : sudo bash tools/add-user.sh [--dry-run] [--prompt] <ユーザー名>...  （要root）
#   --dry-run  何も作らず、やることだけを表示する
#   --prompt   パスワードを自分で入力する（既定は、ランダムなパスワードを作って1回だけ表示する）
#
# 作るアカウント：グループは clab_api だけ。シェルは nologin（SSHで入れない。ログインはFNLの画面だけ）。
# docker・sudo・clab_admins には入れない。
# コンテナ方式では、アカウントは clab-api-server のコンテナの中にだけ作る（ホストには作らない）。どちらの方式かは自動で判定する。
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
DRY=0
PROMPT=0
USERS=()
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --prompt) PROMPT=1 ;;
    -h | --help) sed -n 2,11p "$0"; exit 0 ;;
    -*) echo "不明なオプション: $a" >&2; exit 2 ;;
    *) USERS+=("$a") ;;
  esac
done
[ "${#USERS[@]}" -gt 0 ] || { echo "ユーザー名を指定してください（例: bash tools/add-user.sh teacher1）" >&2; exit 2; }

# 方式の判定：コンテナ版の clab-api-server が動いていればコンテナ方式
CONTAINER=0
CF="$REPO/backend/compose"   # compose.yaml の場所（.env の COMPOSE_FILE に従う）
if command -v docker >/dev/null 2>&1 && [ -f "$CF/compose.yaml" ]; then
  D=(docker); docker info >/dev/null 2>&1 || D=(sudo docker)
  [ -n "$("${D[@]}" compose --project-directory "$CF" ps -q clab-api-server 2>/dev/null || true)" ] && CONTAINER=1
fi

# ex: アカウントの操作を、コンテナの中またはホストで実行する（標準入力はそのまま渡す）
if [ "$CONTAINER" = 1 ]; then
  ex() { "${D[@]}" compose --project-directory "$CF" exec -T clab-api-server "$@"; }
  echo "（コンテナ方式：アカウントは clab-api-server のコンテナの中に作ります）"
else
  if [ "$DRY" = 0 ] && [ "$(id -u)" != 0 ]; then echo "rootで実行してください（sudo bash $0 ...）" >&2; exit 1; fi
  ex() { "$@"; }
fi
ex getent group clab_api >/dev/null || { echo "グループ clab_api がありません。先に導入してください（tools/install.sh）" >&2; exit 1; }

run() { if [ "$DRY" = 1 ]; then printf '  $ %s\n' "$*"; else ex "$@"; fi; }

for u in "${USERS[@]}"; do
  echo "== $u =="
  if ! [[ "$u" =~ ^[a-z][a-z0-9_-]{1,31}$ ]]; then
    echo "  ユーザー名は、英小文字で始まり、英小文字・数字・_・- の2〜32文字にしてください。スキップします" >&2
    continue
  fi
  if ex id "$u" >/dev/null 2>&1; then
    echo "  すでにあります。作成はスキップします（所属：$(ex id -nG "$u")）"
    for g in docker sudo clab_admins; do
      ex id -nG "$u" | tr ' ' '\n' | grep -qx "$g" && echo "  ！ $g に入っています。利用者は入れないでください（gpasswd -d $u $g）"
    done
    continue
  fi
  run useradd -m -G clab_api -s /usr/sbin/nologin "$u"
  if [ "$PROMPT" = 1 ]; then
    if [ "$DRY" = 1 ]; then echo "  \$ passwd $u"; elif [ "$CONTAINER" = 1 ]; then "${D[@]}" compose --project-directory "$CF" exec clab-api-server passwd "$u"; else passwd "$u"; fi
  else
    pw=$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9' | head -c 14)
    if [ "$DRY" = 1 ]; then
      echo "  （ランダムなパスワードを設定して表示します）"
    else
      echo "$u:$pw" | ex chpasswd
      echo "  パスワード: $pw   ← 今だけ表示。本人に渡し、渡したら忘れてください"
    fi
  fi
  echo "  作成しました。画面（https://<サーバー>/）からログインできることを、一度確かめてください"
done
