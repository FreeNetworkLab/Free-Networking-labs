#!/usr/bin/env bash
# Free-Networking-labs のインストール（共有サーバー用）。Ubuntu 24.04、管理者のアカウント（sudoが使える人）で実行する。
# 管理者編マニュアル3章の手順1〜10を自動にしたもの。何度実行しても同じ結果になるよう、入っているものはスキップする。
#
# 使い方:
#   bash tools/install.sh --mode server --dry-run     ← まず、やることを表示だけして確認する
#   bash tools/install.sh --mode server               ← 実際に入れる（配布版は数分。git から実行した場合はイメージのビルドで1〜2時間）
# オプション:
#   --dry-run        何も変更せず、実行するコマンドだけを表示する
#   --skip-images    ノードのイメージのビルド・取得を飛ばす（あとで手動で行う）
#   --build-images   配布版でも、イメージを取得せずソースからビルドする
#   --hostname NAME  HTTPS証明書に入れるホスト名（既定：このサーバーの hostname）
#
# すでに動いているサーバーに再度実行しても、入っているものはスキップし、設定が変わらない限りサービスは再起動しない。
# 個人のWSL向け（--mode personal）は、今後対応する。先に tools/check-env.sh でWSLのカーネルの機能を確かめられる。
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
ME=$(id -un)
MODE=""
DRY=0
SKIP_IMAGES=0
BUILD_IMAGES=0
HOST_NAME=$(hostname)
while [ $# -gt 0 ]; do
  case "$1" in
    --mode) MODE="${2:-}"; shift ;;
    --dry-run) DRY=1 ;;
    --skip-images) SKIP_IMAGES=1 ;;
    --build-images) BUILD_IMAGES=1 ;;
    --hostname) HOST_NAME="${2:-}"; shift ;;
    -h | --help) sed -n 2,15p "$0"; exit 0 ;;
    *) echo "不明なオプション: $1" >&2; exit 2 ;;
  esac
  shift
done
case "$MODE" in
  server) ;;
  personal) echo "--mode personal（個人のWSL）は未対応です。先に bash tools/check-env.sh で環境を確かめてください" >&2; exit 2 ;;
  *) echo "--mode server を指定してください（例: bash tools/install.sh --mode server --dry-run）" >&2; exit 2 ;;
esac
[ "$(id -u)" != 0 ] || { echo "rootではなく、管理者の一般アカウントで実行してください（中でsudoを使います）" >&2; exit 1; }

# 配布版（tar.gz）には release.env がある。あればイメージは取得し、無ければ（gitから実行）ビルドする
FNL_VERSION=""; FNL_REGISTRY=""
[ -f "$REPO/tools/release.env" ] && . "$REPO/tools/release.env"

step() { printf '\n==== %s ====\n' "$*"; }
run() { if [ "$DRY" = 1 ]; then printf '  $ %s\n' "$*"; else printf '  $ %s\n' "$*"; "$@"; fi; }
sh_run() { if [ "$DRY" = 1 ]; then printf '  $ %s\n' "$1"; else printf '  $ %s\n' "$1"; bash -c "$1"; fi; }

step "0. 事前の確認"
. /etc/os-release
echo "  OS: ${PRETTY_NAME}   カーネル: $(uname -r)   管理者: $ME   リポジトリ: $REPO"
[ "${ID}" = ubuntu ] || { echo "Ubuntu 以外は未確認です（apt を使うため Debian 系のみ想定）" >&2; [ "$DRY" = 1 ] || exit 1; }
[ "$(ps -p 1 -o comm=)" = systemd ] || { echo "systemd が動いていません" >&2; [ "$DRY" = 1 ] || exit 1; }
sudo -n true 2>/dev/null || echo "  （sudo のパスワードを聞かれることがあります）"

step "1. 基本のパッケージ"
run sudo apt-get update
run sudo apt-get install -y git openssl rsync curl ca-certificates gnupg

step "2. Docker"
if command -v docker >/dev/null 2>&1; then
  echo "  入っています（$(docker --version)）"
else
  run sudo install -m 0755 -d /etc/apt/keyrings
  run sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
  run sudo chmod a+r /etc/apt/keyrings/docker.asc
  sh_run "echo \"deb [arch=\$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable\" | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null"
  run sudo apt-get update
  run sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi
run sudo systemctl enable --now docker
id -nG "$ME" | tr ' ' '\n' | grep -qx docker || {
  run sudo usermod -aG docker "$ME"
  echo "  ※ docker グループに入れました。入れ直し（ログインし直し）が必要です。このスクリプトは sudo docker で続けます"
}
if docker info >/dev/null 2>&1; then DOCKER=(docker); else DOCKER=(sudo docker); fi

step "3. clab-api-server（Linux アカウントでの認証、ラボの分離）"
if [ -x /usr/local/bin/clab-api-server ]; then
  echo "  入っています"
else
  sh_run "curl -fsSL https://raw.githubusercontent.com/srl-labs/clab-api-server/main/install.sh | sudo bash -s -- install"
fi
ENVF=/etc/clab-api-server/clab-api-server.env
ENV_CHANGED=0
set_env() { # KEY VALUE（値が違う時だけ書き換える）
  if [ "$DRY" = 1 ]; then printf '  （設定）%s=%s\n' "$1" "$2"; return; fi
  if sudo grep -qxF "$1=$2" "$ENVF" 2>/dev/null; then return; fi
  ENV_CHANGED=1
  if sudo grep -qE "^$1=" "$ENVF" 2>/dev/null; then sudo sed -i -E "s|^$1=.*|$1=$2|" "$ENVF"; else echo "$1=$2" | sudo tee -a "$ENVF" >/dev/null; fi
}
set_env API_PORT 8090
set_env API_USER_GROUP clab_api
set_env SUPERUSER_GROUP clab_admins
set_env TLS_ENABLE true
set_env TLS_AUTO_CERT true
set_env CLAB_LABS_ROOT /var/lib/containerlab/labs
run sudo install -d -m 0755 /var/lib/containerlab/labs
run sudo systemctl enable clab-api-server
# 設定を変えた時、または止まっている時だけ再起動する（動いているサーバーで、起動中の処理を途切れさせないため）
if [ "$DRY" = 1 ] || [ "$ENV_CHANGED" = 1 ] || ! systemctl is-active --quiet clab-api-server; then
  run sudo systemctl restart clab-api-server
else
  echo "  設定に変更なし。再起動しません"
fi
echo "  管理者を clab_admins に入れる（ovs-helper のラッパーは、このグループだけが実行できる）"
run sudo usermod -aG clab_admins "$ME"

step "4. Node.js 24（nvm）"
if [ -s "$HOME/.nvm/nvm.sh" ]; then echo "  nvm あり"; else
  sh_run "curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash"
fi
if [ -s "$HOME/.nvm/nvm.sh" ]; then
  set +u
  . "$HOME/.nvm/nvm.sh"
  nvm ls 24 >/dev/null 2>&1 || run nvm install 24
  nvm use 24 >/dev/null
  set -u
fi
NODE=$(command -v node || echo "$HOME/.nvm/versions/node/<node 24>/bin/node")
echo "  node: $NODE"

step "5. ノードのイメージ"
if [ "$SKIP_IMAGES" = 1 ]; then echo "  --skip-images のため飛ばします（あとで手動で。管理者編マニュアル3章の手順5）"; else
  # タグは frontend/src/types/lab.ts の PALETTE_NODE_CONFIGS と合わせる
  FRR=$(grep -oE "fnl/frr:[0-9]+" "$REPO/frontend/src/types/lab.ts" | head -1)
  L2=$(grep -oE "fnl/l2switch:[0-9]+" "$REPO/frontend/src/types/lab.ts" | head -1)
  L3=$(grep -oE "fnl/l3switch:[0-9]+" "$REPO/frontend/src/types/lab.ts" | head -1)
  echo "  画面が使うタグ: $FRR / $L2 / $L3"
  if [ -n "$FNL_REGISTRY" ] && [ "$BUILD_IMAGES" = 0 ]; then
    echo "  配布版 $FNL_VERSION：$FNL_REGISTRY からイメージを取得します（ビルドしません）"
    for t in "$FRR" "$L2" "$L3"; do
      remote="$FNL_REGISTRY/fnl-${t#fnl/}"   # fnl/frr:3 → <置き場>/fnl-frr:3
      run "${DOCKER[@]}" pull "$remote"
      run "${DOCKER[@]}" tag "$remote" "$t"
    done
  else
    run "${DOCKER[@]}" build -t "$FRR" "$REPO/backend/frr-router"
    run "${DOCKER[@]}" build -t "$L2" "$REPO/backend/l2switch"
    run "${DOCKER[@]}" build -t "$L3" -f "$REPO/backend/l2switch/Dockerfile.l3" "$REPO/backend/l2switch"
  fi
  run "${DOCKER[@]}" pull alpine:3.20
  echo "  Wireshark のイメージは、先に取得しておく（無いと最初のキャプチャが45秒の制限で失敗する）"
  run "${DOCKER[@]}" pull ghcr.io/srl-labs/wireshark-vnc-docker:latest
fi

step "6. EdgeShark（キャプチャの裏方）"
sh_run "cd '$REPO/backend/edgeshark' && ${DOCKER[*]} compose up -d"

step "7. プロキシ 4 つ（console・ovs-helper・capture・collab）"
for p in console-proxy ovs-helper capture-proxy collab-proxy; do
  [ -d "$REPO/backend/$p/node_modules" ] && continue   # 配布版は依存を同梱している
  [ -f "$REPO/backend/$p/package.json" ] && sh_run "cd '$REPO/backend/$p' && npm install --no-audit --no-fund"
done
CAPCERT="$REPO/backend/capture-proxy/certs"
if [ -f "$CAPCERT/cert.pem" ]; then echo "  capture-proxy の証明書あり"; else
  run mkdir -p "$CAPCERT"
  run openssl req -x509 -newkey rsa:2048 -keyout "$CAPCERT/key.pem" -out "$CAPCERT/cert.pem" -days 825 -nodes \
    -subj "/CN=capture-proxy" -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
fi
run mkdir -p "$HOME/.config/systemd/user"
for p in console-proxy ovs-helper capture-proxy collab-proxy; do
  src="$REPO/backend/$p/$p.service.example"
  [ -f "$src" ] || continue
  sh_run "sed -e 's#/home/<your-username>/.nvm/versions/node/<version>/bin/node#$NODE#' -e 's#/home/<your-username>/Free-Networking-labs#$REPO#g' -e 's#<your-username>#$ME#g' '$src' > '$HOME/.config/systemd/user/$p.service'"
done
run systemctl --user daemon-reload
run systemctl --user enable --now console-proxy ovs-helper capture-proxy collab-proxy
echo "  ログアウトしても、サーバーの起動時から動かし続ける"
run sudo loginctl enable-linger "$ME"

step "8. ovs-helper のラッパー（sudo の限定許可）"
W=/usr/local/sbin/ovs-helper-frr-config-init
run sudo install -m 0750 -o root -g clab_admins "$REPO/backend/ovs-helper/frr-config-init.sh" "$W"
sh_run "echo '$ME ALL=(root) NOPASSWD: $W' | sudo tee /etc/sudoers.d/ovs-helper-frr-config-init >/dev/null"
run sudo chmod 440 /etc/sudoers.d/ovs-helper-frr-config-init
run sudo visudo -c

step "9. 画面のビルドと nginx"
if [ -f "$REPO/frontend/dist/index.html" ]; then echo "  ビルド済みの画面があります（配布版）"; else
  sh_run "cd '$REPO/frontend' && npm ci --no-audit --no-fund && npm run build"
fi
NGX="$REPO/backend/nginx/certs"
if [ -f "$NGX/cert.pem" ]; then echo "  HTTPS の証明書あり（作り直すなら $NGX を消す）"; else
  IP=$(hostname -I | awk '{print $1}')
  run mkdir -p "$NGX"
  run openssl req -x509 -newkey rsa:2048 -keyout "$NGX/key.pem" -out "$NGX/cert.pem" -days 825 -nodes \
    -subj "/CN=$HOST_NAME" -addext "subjectAltName=DNS:$HOST_NAME,DNS:localhost,IP:${IP:-127.0.0.1},IP:127.0.0.1"
fi
sh_run "bash '$REPO/backend/nginx/install.sh'"

step "10. ファイアウォールなど"
echo "  このスクリプトは、ファイアウォール（ufw）やSSHの設定には触りません。"
echo "  共有サーバーとして公開する場合の注意は、管理者編マニュアルの7章（セキュリティ）を見てください。"

step "11. 動作の確認"
if [ "$DRY" = 1 ]; then echo "  （--dry-run のため確認は飛ばします）"; else
  for s in docker nginx clab-api-server; do printf '  %-18s %s\n' "$s" "$(systemctl is-active $s)"; done
  for s in console-proxy ovs-helper capture-proxy collab-proxy; do printf '  %-18s %s\n' "$s" "$(systemctl --user is-active $s)"; done
  curl -sk -m 8 -o /dev/null -w '  clab-api-server /health: HTTP %{http_code}\n' https://localhost:8090/health || true
  curl -sk -m 8 -o /dev/null -w '  画面 https://localhost/: HTTP %{http_code}\n' https://localhost/ || true
  bash "$REPO/tools/check-env.sh" || true
fi

cat <<E

完了しました。次にやること:
  1. sudo bash tools/add-user.sh <ユーザー名>      （利用者のアカウントを作る）
  2. ブラウザで https://${HOST_NAME}/ を開き、ログインできることを確かめる（初回は証明書の警告）
  3. ルーター・スイッチ・PCを置いて「起動」→ コンソールで ping、線を右クリック →「パケットキャプチャ」
※ docker グループへの追加を行った場合は、いちどログインし直してください。
E
