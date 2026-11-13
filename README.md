# Free-Networking-labs

> **ドラフト**：試験版公開に向けて整備中です。内容は変わることがあります。

ブラウザだけで使える、ネットワーク演習用のシミュレータです。Cisco Modeling Labs（CML）のような操作感
（ドラッグ＆ドロップでのトポロジ編集、ブラウザ内コンソール、ノードごとの起動・停止）を、
[containerlab](https://containerlab.dev/) の上に OSS で作っています。

CML Free にある次の制約を持たないことを目指しています。

- 1 人でしか使えない → **複数人が同じサーバーを同時に使える**（Linux アカウントでログイン、ラボは利用者ごとに分離）
- 同時に動かせるノードが 5 台まで → **台数の上限なし**（サーバーのメモリ次第）

ノードはすべて軽量なコンテナなので、仮想マシン型のシミュレータより少ないメモリで動きます。

## できること

| 分類 | 内容 |
|---|---|
| ノード | ルーター（FRR）、L2 スイッチ、L3 スイッチ、PC（Linux） |
| 編集 | ドラッグ＆ドロップ、自動保存、起動中の変更だけを反映、元に戻す／やり直す、YAML のエクスポート／インポート |
| コンソール | ブラウザ内のターミナル（複数タブ） |
| ルーター | OSPF・BGP・RIP・IS-IS・静的経路など。`vtysh` で設定 |
| L2 スイッチ | VLAN、STP／RSTP／MSTP、EtherChannel（LACP）、ポートセキュリティ、LLDP／CDP。**Cisco 風の CLI** |
| L3 スイッチ | L2 の機能＋ SVI 間ルーティング、OSPF・BGP・RIP、route-map、VRRP、DHCP リレー、ACL |
| 回線 | 帯域・遅延・ゆらぎ・ロスの設定、ケーブルの抜き差し |
| キャプチャ | 画面から Wireshark（ブラウザの中）を開く |
| 共有 | スナップショット、共有リンク（閲覧／編集）、複数画面での同時編集 |

未実装のものは、PVST、EIGRP、HSRP、VRF などです。使い方は[利用者編マニュアル](docs/manual/操作マニュアル_利用者編.pdf)にあります。

## 構成

```
ブラウザ ── HTTPS ──> nginx (443)
                        ├─ /            画面（React + React Flow + xterm.js）
                        ├─ /api         clab-api-server（Linux アカウントで認証。既存の OSS）
                        ├─ /console     console-proxy（ターミナルの WebSocket 中継）
                        ├─ /ovs         ovs-helper（設定の保存先の用意）
                        └─ /capture     capture-proxy（Wireshark の中継）
                                          │
                              containerlab ── Docker ── FRR / L2・L3 スイッチ / PC
```

- 認証は Linux のアカウント（PAM）をそのまま使います。独自のユーザー DB はありません。
- `backend/` に、プロキシ 4 つとノードのイメージ（`frr-router/`・`l2switch/`）、nginx の設定があります。
- `frontend/` に画面があります。

サーバーの構成と運用は[管理者編マニュアル](docs/manual/操作マニュアル_管理者編.pdf)を見てください。

## 動作環境

- Ubuntu Server 24.04 LTS（カーネル 6.7 以上。STP が MST のブリッジ機能を使うため）
- Docker 29.x、containerlab、clab-api-server
- Node.js 24（画面のビルドとプロキシの実行）
- 目安：4 コア・メモリ 12 GB ほどで、40 人規模の授業を想定（実測は管理者編の 2 章）

## セットアップ（共有サーバー）

Ubuntu 24.04 のサーバーで、管理者のアカウント（`sudo` が使える人）が実行します。

**配布版（おすすめ）**：[Releases](https://github.com/FreeNetworkLab/Free-Networking-labs/releases) の `fnl-<バージョン>.tar.gz` を使います。画面はビルド済みで、ノードのイメージは
ダウンロードするだけなので、数分で終わります。

```sh
tar xzf fnl-<バージョン>.tar.gz && cd fnl-<バージョン>
sha256sum -c ../fnl-<バージョン>.tar.gz.sha256   # 任意：壊れていないかの確認（.sha256 を同じ場所に置く）
bash tools/install.sh --mode server --dry-run    # やることを表示だけして確認
bash tools/install.sh --mode server              # 入れる
sudo bash tools/add-user.sh <ユーザー名>          # 利用者のアカウントを作る
```

**ソースから入れる場合**（開発者向け。ノードのイメージのビルドを含むため 1〜2 時間かかります）：

```sh
git clone https://github.com/FreeNetworkLab/Free-Networking-labs.git && cd Free-Networking-labs
bash tools/check-env.sh                          # 環境の確認（何も変更しない）。カーネルの機能も確かめる
bash tools/install.sh --mode server --dry-run    # やることを表示だけして確認
bash tools/install.sh --mode server              # 入れる（1〜2時間。イメージのビルドを含む）
sudo bash tools/add-user.sh <ユーザー名>          # 利用者のアカウントを作る（ログインはFNLの画面だけ）
```

- 手順の中身と、手動で行う場合は、[管理者編マニュアル](docs/manual/操作マニュアル_管理者編.pdf)の 3 章にあります。
- ファイアウォール（ufw）やSSHの設定は、インストールでは変更しません。
- 利用者のアカウントは、`clab_api` グループだけに入れ、`docker`・`sudo`・`clab_admins` には入れません。
  `docker` グループはサーバーの root と同じ権限になります。`add-user.sh` は、この形で作ります。
- 個人の PC の WSL 上で動かすことは、今後対応する予定です。先に `tools/check-env.sh` で、WSL のカーネルが必要な機能
  （STP の MST、netem、bonding、nftables、macvlan など）を満たすか確かめられます。

## 使い方

[利用者編マニュアル](docs/manual/操作マニュアル_利用者編.pdf)に、ログインから、ラボの作り方、
機器の設定、演習の例、Wireshark の使い方まであります。

## 開発

```sh
cd frontend
npm install
npm run dev      # 開発サーバー（API は別途サーバーが要ります）
npm test         # vitest
npm run build
```

- スイッチの CLI のテスト：`cd backend/l2switch && python3 -m unittest test_swcli test_l3 test_acl`
- CI（GitHub Actions）：backend（構文確認とテスト）、frontend（型検査・lint・テスト・ビルド）、swcli（pyflakes とテスト）

## 制約と注意

- 外部ネットワークへの接続（CML の External Connector 相当）と、商用ベンダーのイメージは対象外です。
- HTTPS の証明書は自己署名の想定です（初回にブラウザの警告が出ます）。学内などの閉じたネットワークで使う前提です。
- ルーターの設定は、実機と同じく `write memory` で保存します。

## ライセンス

[MIT License](LICENSE)。同梱・利用している外部ソフトのライセンスは
[THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md) にまとめています。
