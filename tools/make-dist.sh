#!/usr/bin/env bash
# 配布用の tar.gz を作る（ビルド済みの画面・プロキシの依存込み）。使い方:
#   tools/make-dist.sh <バージョン 例:0.1.0> <イメージの置き場 例:ghcr.io/ユーザー名> <出力先ディレクトリ>
# 中身は make-release-tree.sh の出力（公開側のリポジトリでは、そのままのツリー。内部情報なし）に、画面のビルド結果とプロキシの node_modules を足したもの。
# tools/release.env に置き場とバージョンを書く。install.sh はこれがあると、イメージをビルドせず pull する。
set -euo pipefail
ver="${1:?バージョンを指定してください（例: 0.1.0）}"
registry="${2:?イメージの置き場を指定してください（例: ghcr.io/ユーザー名）}"
outdir="${3:?出力先のディレクトリを指定してください}"
cd "$(git rev-parse --show-toplevel)"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
name="fnl-$ver"

if [ -f tools/make-release-tree.sh ]; then
  bash tools/make-release-tree.sh "$work/$name"   # 非公開側のリポジトリ：内部情報を除いたツリーを作る
else
  mkdir -p "$work/$name" && git archive HEAD | tar -x -C "$work/$name"   # 公開側のリポジトリ：すでに除いてある
fi
(cd "$work/$name/frontend" && npm ci --no-audit --no-fund && npm run build && rm -rf node_modules)
for p in console-proxy ovs-helper capture-proxy collab-proxy; do
  d="$work/$name/backend/$p"
  [ -f "$d/package.json" ] || continue
  if [ -f "$d/package-lock.json" ]; then (cd "$d" && npm ci --omit=dev --no-audit --no-fund)
  else (cd "$d" && npm install --omit=dev --no-audit --no-fund); fi   # lock が無いものは、あるだけ入れる
done
printf 'FNL_VERSION=%s\nFNL_REGISTRY=%s\n' "$ver" "$registry" > "$work/$name/tools/release.env"

mkdir -p "$outdir"
tar -C "$work" -czf "$outdir/$name.tar.gz" "$name"
(cd "$outdir" && sha256sum "$name.tar.gz" > "$name.tar.gz.sha256")
echo "OK: $outdir/$name.tar.gz"
