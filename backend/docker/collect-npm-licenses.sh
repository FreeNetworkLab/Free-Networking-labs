#!/bin/sh
# 本番用の npm の依存（開発用を除く）の LICENSE / COPYING ファイルを、出力先に集める（MIT などは、配る時に表示を残す必要がある）。
# 使い方: （package.json のあるフォルダで）collect-npm-licenses.sh <出力先のディレクトリ>
set -eu
out="${1:?出力先}"
root="$(pwd)/node_modules/"
mkdir -p "$out"
npm ls --omit=dev --all --parseable 2>/dev/null | tail -n +2 | sort -u | while read -r d; do
  name="${d#"$root"}"
  [ "$name" = "$d" ] && continue
  dest="$out/$(printf '%s' "$name" | tr '/' '_')"
  for f in "$d"/LICEN[SC]E* "$d"/COPYING* "$d"/NOTICE*; do
    [ -f "$f" ] || continue
    mkdir -p "$dest"; cp "$f" "$dest/"
  done
done
