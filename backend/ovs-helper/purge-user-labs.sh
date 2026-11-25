#!/bin/sh
# ユーザーのラボのフォルダ（$ROOT/<ユーザー名>/）を、まるごと消す。管理画面の「ユーザーを削除（ラボも消す）」用。
# コンテナ版（OVS_HELPER_NO_SUDO=1）の ovs-helper だけが、server.js から直接実行する（sudoでは使わない。従来の方式は非対応）。
#
# なぜ要るか（2026-11-18、WSLの実測）：ユーザーを消しても、labs/<ユーザー名>/ は、持ち主のいない uid のまま残る。
#   あとで新しいユーザーに同じ uid が割り当てられると、その人が、消えた人のラボを読めてしまう。
#   止まっているラボは、APIでは消せない（404）。そこで、権限を絞ったこのコンテナで、フォルダごと消す。
#
# 呼び出し：purge-user-labs.sh <ユーザー名>     ※ユーザーを消す「前」に呼ぶ（持ち主の確認に、アカウントが要るため）
# 守り：ユーザー名の形式／アカウントの実在／$ROOT/<名前> が通常のディレクトリ（シンボリックリンクでない）／
#       持ち主がそのアカウントか root／（busybox の rm は --one-file-system を持たない。ユーザーのフォルダの中にマウントは無い前提）
set -eu

ROOT="${FNL_LABS_ROOT:-/var/lib/containerlab/labs}"
user="${1:-}"
fail() { echo "refused: $1" >&2; exit 1; }

printf '%s' "$user" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9_.-]*$' || fail "invalid user"
[ -n "${FNL_PASSWD_FILE:-}" ] || fail "FNL_PASSWD_FILE is required"
entry="$(awk -F: -v u="$user" '$1 == u { print; exit }' "$FNL_PASSWD_FILE")"
[ -n "$entry" ] || fail "unknown user"
uid="$(printf '%s' "$entry" | cut -d: -f3)"
[ "$uid" != 0 ] || fail "refusing root"

udir="$ROOT/$user"
[ ! -L "$udir" ] || fail "symlink"
[ -e "$udir" ] || { echo "nothing to remove"; exit 0; }
[ -d "$udir" ] || fail "not a plain directory"
owner="$(stat -c %u "$udir")"
[ "$owner" = "$uid" ] || [ "$owner" = 0 ] || fail "owner mismatch"

rm -rf -- "$udir"
echo "removed $udir"
