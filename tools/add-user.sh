#!/usr/bin/env bash
# 利用者（学生・先生など）のアカウントを作る。要root。
# 使い方: sudo bash tools/add-user.sh [--dry-run] [--prompt] <ユーザー名>...
#   --dry-run  何も作らず、やることだけを表示する
#   --prompt   パスワードを自分で入力する（既定は、ランダムなパスワードを作って1回だけ表示する）
#
# 作るアカウント：グループは clab_api だけ。シェルは nologin（SSHで入れない。ログインはFNLの画面だけ）。
# docker・sudo・clab_admins には入れない（dockerグループはサーバーのroot相当のため）。
set -euo pipefail

DRY=0
PROMPT=0
USERS=()
for a in "$@"; do
  case "$a" in
    --dry-run) DRY=1 ;;
    --prompt) PROMPT=1 ;;
    -h | --help) sed -n 2,9p "$0"; exit 0 ;;
    -*) echo "不明なオプション: $a" >&2; exit 2 ;;
    *) USERS+=("$a") ;;
  esac
done
[ "${#USERS[@]}" -gt 0 ] || { echo "ユーザー名を指定してください（例: sudo bash tools/add-user.sh teacher1）" >&2; exit 2; }
if [ "$DRY" = 0 ] && [ "$(id -u)" != 0 ]; then echo "rootで実行してください（sudo bash $0 ...）" >&2; exit 1; fi
getent group clab_api >/dev/null || { echo "グループ clab_api がありません。先に clab-api-server を入れてください（tools/install.sh）" >&2; exit 1; }

run() { if [ "$DRY" = 1 ]; then printf '  $ %s\n' "$*"; else "$@"; fi; }

for u in "${USERS[@]}"; do
  echo "== $u =="
  if ! [[ "$u" =~ ^[a-z][a-z0-9_-]{1,31}$ ]]; then
    echo "  ユーザー名は、英小文字で始まり、英小文字・数字・_・- の2〜32文字にしてください。スキップします" >&2
    continue
  fi
  if id "$u" >/dev/null 2>&1; then
    echo "  すでにあります。作成はスキップします（所属：$(id -nG "$u")）"
    for g in docker sudo clab_admins; do
      id -nG "$u" | tr ' ' '\n' | grep -qx "$g" && echo "  ！ $g に入っています。利用者は入れないでください（gpasswd -d $u $g）"
    done
    continue
  fi
  run useradd -m -G clab_api -s /usr/sbin/nologin "$u"
  if [ "$PROMPT" = 1 ]; then
    run passwd "$u"
  else
    pw=$(openssl rand -base64 18 | tr -dc 'A-Za-z0-9' | head -c 14)
    if [ "$DRY" = 1 ]; then
      echo "  （ランダムなパスワードを設定して表示します）"
    else
      echo "$u:$pw" | chpasswd
      echo "  パスワード: $pw   ← 今だけ表示。本人に渡し、渡したら忘れてください"
    fi
  fi
  echo "  作成しました。画面（https://<サーバー>/）からログインできることを、一度確かめてください"
done
