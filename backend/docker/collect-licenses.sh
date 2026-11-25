#!/bin/sh
# イメージの中に /licenses を用意する（ライセンスの明記）。fnl-web・fnl-proxy のビルドで使う。
#   alpine-packages.txt … このイメージに入っている Alpine のパッケージと、そのライセンス
# 使い方: collect-licenses.sh <出力先のディレクトリ>
set -eu
out="${1:?出力先}"
mkdir -p "$out"
{
  echo "# このイメージに入っている Alpine Linux のパッケージ（名前-バージョン <TAB> ライセンス）"
  echo "# 各パッケージのソースは https://gitlab.alpinelinux.org/alpine/aports と https://dl-cdn.alpinelinux.org/alpine/ にあります"
  # apk list -I の1行：「名前-バージョン アーキテクチャ {元のパッケージ} (ライセンス) [installed]」
  apk list -I 2>/dev/null | sort | while read -r nv _ _ rest; do
    lic=$(printf '%s' "$rest" | sed -n 's/^(\(.*\)) \[installed\]$/\1/p')
    printf '%s\t%s\n' "$nv" "${lic:-不明}"
  done
} > "$out/alpine-packages.txt"
