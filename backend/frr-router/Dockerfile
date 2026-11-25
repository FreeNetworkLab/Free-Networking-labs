# ルーター用イメージ（2026-10-14）。FRR公式イメージに、VLANサブインターフェースを
# vtyshの設定から自動で作るエージェント（fnl-subif-agent）を足したもの。詳細はREADME.md
#   fnl/frr:1（2026-10-14）：サブインターフェースのエージェント
#   fnl/frr:2（2026-10-14）：lldpd（LLDP/CDPv2を送り、スイッチの show lldp/cdp neighbors に出る）
#   fnl/frr:3（2026-10-15）：lldpdが送らなくなったら起動し直す（fnl-lldpd-start）
#   fnl/frr:4（2026-11-18）：/licenses（ライセンスの明記）を追加。ビルドの文脈をリポジトリのルートに変更
#
#   docker build -f backend/frr-router/Dockerfile -t fnl/frr:4 .      ← リポジトリのルートで
FROM quay.io/frrouting/frr:10.2.1
RUN apk add --no-cache lldpd
COPY backend/frr-router/fnl-subif-agent backend/frr-router/fnl-start backend/frr-router/fnl-lldpd-start /usr/local/bin/
RUN chmod 755 /usr/local/bin/fnl-subif-agent /usr/local/bin/fnl-start /usr/local/bin/fnl-lldpd-start
# ライセンスの明記（2026-11-18〜）：このリポジトリの LICENSE、外部ソフトの一覧、GPL-2.0、入っている Alpine のパッケージの一覧
COPY LICENSE THIRD-PARTY-LICENSES.md licenses/GPL-2.0.txt /licenses/
COPY backend/docker/collect-licenses.sh /tmp/collect-licenses.sh
RUN sh /tmp/collect-licenses.sh /licenses && rm /tmp/collect-licenses.sh
CMD ["/usr/local/bin/fnl-start"]
