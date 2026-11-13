# 利用している外部ソフトのライセンス

このリポジトリ自体は MIT License（`LICENSE`）です。次のソフトは**リポジトリに含めず**、導入やビルドのときに
各自の環境へ取得します（例外は、mstpd へのパッチ `backend/l2switch/mstpd/fnl.patch`）。

確認日：2026-11-02（各プロジェクトの LICENSE ファイル、Alpine 3.22 のパッケージ情報による）。

## 実行時に使うもの

| ソフト | 用途 | ライセンス | 備考 |
|---|---|---|---|
| containerlab | ラボの作成・破棄 | BSD-3-Clause | |
| clab-api-server | 認証付きの API | Apache-2.0 | 管理者編マニュアル 3 章・手順 3 で導入 |
| FRRouting | ルーター、L3 スイッチの経路制御 | GPL-2.0-or-later | `fnl/frr` は公式イメージ（`quay.io/frrouting/frr`）、`fnl/l3switch` は Alpine のパッケージ |
| mstpd | スイッチの STP／RSTP／MSTP | GPL-2.0 | LICENSE は GPL v2 の全文。ソースを取得してビルドする。コンテナ向けの改修パッチ `backend/l2switch/mstpd/fnl.patch` をこのリポジトリに置く（同じ GPL-2.0 で扱う） |
| lldpd | LLDP／CDP | ISC | Alpine のパッケージ |
| nftables | L3 スイッチの ACL | GPL-2.0-or-later | Alpine のパッケージ |
| dhcp-helper | L3 スイッチの DHCP リレー | GPL-2.0-only OR GPL-3.0-only | Alpine のパッケージ |
| Alpine Linux | イメージの土台 | 各パッケージのライセンスによる | |
| EdgeShark | キャプチャの裏方 | MIT | `backend/edgeshark/` |
| Wireshark | パケットの解析 | GPL-2.0-or-later | ブラウザの中で動かす |
| noVNC | Wireshark の画面 | MPL-2.0（コア） | |
| nginx | 入口 | BSD-2-Clause | |
| Open vSwitch | 初期の構成で使用（現在のスイッチは Linux ブリッジ） | Apache-2.0 | |

## プロキシ（`backend/`）の依存

| ソフト | ライセンス |
|---|---|
| ws（WebSocket） | MIT |

## 画面（`frontend/`）の依存

`frontend/package-lock.json` の本番用の依存（開発用を除く）を数えると、次のとおりです。

| ライセンス | 個数 | 主なもの |
|---|---|---|
| MIT | 21 | React、@xyflow/react（React Flow）、@xterm/xterm、Zustand |
| ISC | 8 | |
| BSD-3-Clause | 1 | d3-ease |
| Python-2.0 | 1 | argparse（ビルド時の依存） |

## GPL のソフトを含むイメージについて

`fnl/frr`・`fnl/l2switch`・`fnl/l3switch` のイメージは GPL のソフト（FRR、mstpd など）を含みます。
**このイメージは、GitHub Container Registry（`ghcr.io/freenetworklab/fnl-frr`・`fnl-l2switch`・`fnl-l3switch`）で配布しています。**
ソースからビルドすることもできます（`tools/install.sh --build-images`）。Dockerfile とパッチはこのリポジトリにあるので、再現できます。

イメージに含まれる GPL のソフトと、そのソースの場所は次のとおりです（バージョンは、イメージの Dockerfile で固定したもの）。

| ソフト | バージョン | ライセンス | ソース |
|---|---|---|---|
| FRRouting | 10.2.1（公式イメージ `quay.io/frrouting/frr:10.2.1`、改変なし） | GPL-2.0-or-later | https://github.com/FRRouting/frr （タグ `frr-10.2.1`） |
| mstpd | コミット `2e747d80ad48ffd32ec2f918b48a7c7a3916253b` ＋ このリポジトリの `backend/l2switch/mstpd/fnl.patch` | GPL-2.0 | https://github.com/mstpd/mstpd と、改修パッチ（このリポジトリ） |
| nftables・dhcp-helper・FRR（L3 スイッチ用）ほか Alpine のパッケージ | Alpine Linux 3.22 のもの | 各パッケージのライセンス | https://gitlab.alpinelinux.org/alpine/aports 、https://dl-cdn.alpinelinux.org/alpine/v3.22/ （各パッケージのソース） |

- GPL-2.0 の全文は、各ソフトのソース（上の表）にあります。イメージにはラベル（`org.opencontainers.image.source`・`licenses`）でこのリポジトリと
  ライセンスを示しています。ライセンス全文をイメージの中に入れることは、次のイメージの更新で行います。
- このリポジトリの Dockerfile・スクリプト（`fnl-subif-agent`、`swcli` など）は MIT です。これらは FRR や mstpd と別のプロセスとして動かしており、
  GPL のソフトを改変して組み込んだものではありません（mstpd だけは、上のパッチで改変しており、パッチは GPL-2.0 です）。
- **ソースの提供について**：上のソフトの対応するソース（改変があればその差分を含む）は、上の場所から入手できます。
  入手できない場合は、このリポジトリの Issue で請求してください。イメージを配布してから 3 年間、実費でソースを提供します。
