#!/usr/bin/env bash
# 環境チェック（読み取りだけ。何も変更しない）。共有サーバーでも、個人のWSLでも使える。
# 使い方: bash tools/check-env.sh
#
# 見ること：OS・systemd・Docker・資源・待ち受けポート・カーネルの機能
# カーネルの機能は、使い捨てのコンテナ（Dockerがあれば）か空のネットワーク名前空間の中で、実際に作ってみて確かめる（ホストには何も残らない）。
#   [OK]   問題なし
#   [WARN] 動くが、一部の機能が使えない／余裕が少ない
#   [NG]   このままでは動かない
# 終了コード：[NG]が1つでもあれば1、なければ0
set -u

NG=0
WARN=0
ok() { printf '  [OK]   %s\n' "$1"; }
warn() { printf '  [WARN] %s\n         → %s\n' "$1" "$2"; WARN=$((WARN + 1)); }
ng() { printf '  [NG]   %s\n         → %s\n' "$1" "$2"; NG=$((NG + 1)); }
section() { printf '\n== %s ==\n' "$1"; }

# バージョンの比較（$1 >= $2 なら真）
ver_ge() { [ "$(printf '%s\n%s\n' "$2" "$1" | sort -V | head -n1)" = "$2" ]; }

WSL=0
grep -qi microsoft /proc/version 2>/dev/null && WSL=1

section "環境"
. /etc/os-release 2>/dev/null || true
echo "  OS: ${PRETTY_NAME:-不明}   カーネル: $(uname -r)   $([ "$WSL" = 1 ] && echo 'WSL上で実行中' || echo '通常のLinux')"
case "${ID:-}-${VERSION_ID:-}" in
  ubuntu-24.04) ok "動作確認済みのOS（Ubuntu 24.04）" ;;
  ubuntu-*) warn "Ubuntu ${VERSION_ID:-?} は、動作確認が 24.04 のみ" "apt を使う導入は同じ手順で動く見込みですが、未確認です（Ubuntu 26.04 のWSLで試験中）" ;;
  *) warn "動作確認はUbuntu 24.04のみ（${PRETTY_NAME:-不明}）" "手順の一部（apt・ufw）が使えない可能性があります" ;;
esac

if [ "$(ps -p 1 -o comm= 2>/dev/null)" = systemd ]; then
  ok "systemd が動いている"
else
  if [ "$WSL" = 1 ]; then
    ng "systemd が動いていない" "/etc/wsl.conf に次を書き、PowerShellで wsl --shutdown して入れ直す：[boot] の下に systemd=true"
  else
    ng "systemd が動いていない" "サービスの常駐に systemd が要ります"
  fi
fi

if [ "$(stat -fc %T /sys/fs/cgroup 2>/dev/null)" = cgroup2fs ]; then
  ok "cgroup v2"
else
  warn "cgroup v2 ではない" "containerlab・Docker が古い方式で動きます。新しいOSなら通常はv2です"
fi

section "カーネル"
KVER=$(uname -r | sed -E 's/^([0-9]+\.[0-9]+).*/\1/')
if ver_ge "$KVER" 6.7; then
  ok "カーネル $KVER（STPのMST機能に必要な 6.7 以上）"
else
  warn "カーネル $KVER は 6.7 未満" "L2/L3スイッチのSTP（RSTP/MSTP）が動きません。他の機能は動きます。$([ "$WSL" = 1 ] && echo 'WSLは wsl --update で新しいカーネルになります')"
fi

section "Docker"
if command -v docker >/dev/null 2>&1; then
  if docker info >/dev/null 2>&1; then
    ok "docker が使える（$(docker --version | sed 's/,.*//')）"
    DOCKER_OK=1
  else
    ng "docker を実行できない" "サービスが止まっているか、ユーザーが docker グループに入っていません（入れ直しにログインし直しが必要）"
    DOCKER_OK=0
  fi
else
  ng "docker が入っていない" "https://docs.docker.com/engine/install/ubuntu/ の手順で入れてください（WSLではDocker Desktopではなく、WSLの中に入れる）"
  DOCKER_OK=0
fi
command -v containerlab >/dev/null 2>&1 && ok "containerlab が入っている（$(containerlab version 2>/dev/null | awk '/version/{print $2; exit}')）" || warn "containerlab が入っていない" "tools/install.sh が入れます（または clab-api-server のインストーラーが内蔵版を使います）"

section "資源"
MEM_GB=$(awk '/MemTotal/{printf "%d", $2/1024/1024}' /proc/meminfo)
if [ "$MEM_GB" -ge 8 ]; then ok "メモリ ${MEM_GB} GB"; else warn "メモリ ${MEM_GB} GB" "少人数・少ノードなら動きます。8 GB 以上を推奨（ルーター1台が約40 MB、L2スイッチ約20 MB）"; fi
DISK_GB=$(df -BG --output=avail "$([ -d /var/lib/docker ] && echo /var/lib/docker || echo /)" 2>/dev/null | tail -n1 | tr -dc 0-9)
if [ "${DISK_GB:-0}" -ge 20 ]; then ok "空きディスク ${DISK_GB} GB"; else warn "空きディスク ${DISK_GB:-?} GB" "イメージのビルドに十数GBが要ります。20 GB 以上を推奨"; fi
if [ "$WSL" = 1 ]; then
  echo "  （WSLは、メモリの既定がWindowsの半分です。足りなければ %UserProfile%\\.wslconfig の [wsl2] の memory= で増やします）"
fi

section "ポート"
for p in 80 443 8090; do
  if ss -ltn 2>/dev/null | awk '{print $4}' | grep -qE "[:.]${p}\$"; then
    warn "ポート $p は使用中" "既存のサービスと重なります（このシステムを入れ済みなら問題ありません）"
  else
    ok "ポート $p は空いている"
  fi
done

section "カーネルの機能（使い捨ての空の環境で、実際に作って確認）"
# テスト本体。空のネットワーク名前空間の中で実行するので、ホストには何も残らない
PROBE='
t() { n=$1; shift; if "$@" >/dev/null 2>&1; then echo "OK $n"; else echo "NG $n"; fi; }
t veth ip link add v0 type veth peer name v1
t vlan-bridge ip link add br0 type bridge vlan_filtering 1
t stp-mst sh -c "ip link add br1 type bridge vlan_filtering 1 && ip link set br1 type bridge mst_enabled 1"
t bond ip link add bond0 type bond mode 802.3ad
t netem tc qdisc add dev lo root netem delay 1ms
t vlan-sub sh -c "ip link add d0 type dummy && ip link add link d0 name d0.10 type vlan id 10"
t macvlan sh -c "ip link add d1 type dummy && ip link add link d1 name mv0 type macvlan mode bridge"
t nftables sh -c "nft add table inet t && nft add chain inet t c \"{ type filter hook forward priority 0; }\""
'
RESULT=""
if [ "${DOCKER_OK:-0}" = 1 ]; then
  # Docker があれば、使い捨てのコンテナで行う
  RESULT=$(docker run --rm --cap-add NET_ADMIN --cap-add NET_RAW alpine:3.22 sh -c "apk add -q --no-cache iproute2 iproute2-tc nftables >/dev/null 2>&1 || { echo SKIP; exit 0; }; $PROBE" 2>&1)
elif command -v unshare >/dev/null 2>&1 && command -v ip >/dev/null 2>&1 && command -v tc >/dev/null 2>&1 && command -v nft >/dev/null 2>&1; then
  # Docker が無くても、ip・tc・nft があれば、空のネットワーク名前空間で行う（rootが要る）
  echo "  （Docker が無いので、空のネットワーク名前空間で確認します。sudo のパスワードを聞かれることがあります）"
  RESULT=$(sudo unshare -n sh -c "$PROBE" 2>&1)
else
  warn "カーネルの機能を確認できなかった" "Docker を入れるか、次を実行してから、もう一度試してください：sudo apt-get install -y iproute2 nftables"
fi
if [ -n "$RESULT" ]; then
  if ! echo "$RESULT" | grep -qE '^(OK|NG) '; then
    # テストが動かなかった（sudoのパスワード、パッケージ不足など）。機能が無いとは判定しない
    warn "カーネルの機能を確認できなかった（テストが動きませんでした）" "$(echo "$RESULT" | head -n1)"
  elif echo "$RESULT" | grep -q '^SKIP'; then
    warn "カーネルの機能を確認できなかった" "テスト用のパッケージ（iproute2・nftables）を取得できません。インターネットに接続してやり直してください"
  else
    feat() { # 名前 | 必須か(req/opt) | 説明 | 対処
      if echo "$RESULT" | grep -q "^OK $1\$"; then ok "$3"; else
        if [ "$2" = req ]; then ng "$3 が使えない" "$4"; else warn "$3 が使えない" "$4"; fi
      fi
    }
    feat veth req "veth（ノード間の線）" "カーネルが対応していません。containerlab が動きません"
    feat vlan-bridge req "VLAN対応ブリッジ（L2スイッチのVLAN）" "ブリッジの VLAN フィルタリングが使えません"
    feat vlan-sub req "VLANサブインターフェース（ルーターのrouter on a stick）" "8021q が使えません"
    feat nftables req "nftables（L3スイッチのACL・転送の制御）" "nf_tables が使えません"
    feat stp-mst opt "STPのMST機能（L2/L3スイッチのSTP）" "カーネル6.7以上が必要です。STP以外は動きます"
    feat bond opt "bonding（EtherChannel/LACP）" "bonding が使えません。EtherChannel以外は動きます"
    feat netem opt "netem（線の品質：遅延・ロス・帯域）" "sch_netem が使えません。線の品質の設定以外は動きます"
    feat macvlan opt "macvlan（L3スイッチのVRRP）" "macvlan が使えません。VRRP以外は動きます"
  fi
fi

printf '\n== 結果 ==\n  NG %d 件 / WARN %d 件\n' "$NG" "$WARN"
if [ "$NG" -gt 0 ]; then
  echo "  [NG] を直してから進めてください。"
  exit 1
fi
echo "  このまま進められます$([ "$WARN" -gt 0 ] && echo '（WARNの機能は使えない可能性があります）')。"
exit 0
