# 利用している外部ソフトのライセンス

このリポジトリ自体は MIT License（`LICENSE`）です。次のソフトは**リポジトリに含めず**、導入やビルドのときに
各自の環境へ取得します（例外は、mstpd へのパッチ `backend/l2switch/mstpd/fnl.patch`）。

確認日：2026-11-18（各プロジェクトの LICENSE ファイル、Alpine のパッケージ情報、イメージの中身の実測による）。

## 実行時に使うもの

| ソフト | 用途 | ライセンス | 備考 |
|---|---|---|---|
| containerlab | ラボの作成・破棄 | BSD-3-Clause | |
| clab-api-server | 認証付きの API | Apache-2.0 | 公式のイメージ（`ghcr.io/srl-labs/clab-api-server/clab-api-server`）を、compose が取得して使う。このリポジトリは配らない |
| FRRouting | ルーター、L3 スイッチの経路制御 | GPL-2.0-or-later | `fnl/frr` は公式イメージ（`quay.io/frrouting/frr`）、`fnl/l3switch` は Alpine のパッケージ |
| mstpd | スイッチの STP／RSTP／MSTP | GPL-2.0 | LICENSE は GPL v2 の全文。ソースを取得してビルドする。コンテナ向けの改修パッチ `backend/l2switch/mstpd/fnl.patch` をこのリポジトリに置く（同じ GPL-2.0 で扱う） |
| lldpd | LLDP／CDP | ISC | Alpine のパッケージ |
| nftables | L3 スイッチの ACL | GPL-2.0-or-later | Alpine のパッケージ |
| dhcp-helper | L3 スイッチの DHCP リレー | GPL-2.0-only OR GPL-3.0-only | Alpine のパッケージ |
| Alpine Linux | イメージの土台 | 各パッケージのライセンスによる | |
| EdgeShark | キャプチャの裏方 | MIT | `backend/edgeshark/` |
| Wireshark | パケットの解析 | GPL-2.0-or-later | ブラウザの中で動かす |
| noVNC | Wireshark の画面 | MPL-2.0（コア） | |
| nginx | 入口 | BSD-2-Clause | 公式のイメージ（`nginx:1.27-alpine`）が土台。画面と設定を焼いて `fnl-web` にしている |
| Node.js | プロキシ（`fnl-proxy`） | MIT | 公式のイメージ（`node:22-alpine`）が土台。同梱の npm は Artistic-2.0 |
| Docker CLI | ノードのイメージの取得（`init-images`） | Apache-2.0 | 公式のイメージ（`docker:27-cli`）を取得して使う。このリポジトリは配らない |
| OpenSSL | 自己署名証明書の作成（`fnl-web`・`fnl-proxy`） | Apache-2.0 | Alpine のパッケージ |
| BusyBox ほか Alpine のパッケージ | 各イメージの土台 | GPL-2.0-only など | 下の「このリポジトリが配るイメージ」を参照 |
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

## このリポジトリが配るイメージ（`fnl-web`・`fnl-proxy`）

GitHub Container Registry（`ghcr.io/freenetworklab/fnl-web`・`fnl-proxy`）で配布します。ソースからも作れます（`backend/nginx/Dockerfile`、`backend/Dockerfile.proxy`）。
どちらも、イメージの **`/licenses`** に、含まれるソフトのライセンスの情報を入れています。

| ファイル | 内容 |
|---|---|
| `LICENSE` | このリポジトリのライセンス（MIT） |
| `THIRD-PARTY-LICENSES.md` | このファイル |
| `GPL-2.0.txt` | GPL-2.0 の全文（BusyBox など、Alpine の GPL-2.0 のソフト用） |
| `alpine-packages.txt` | イメージに入っている Alpine のパッケージ全部の、名前・バージョン・ライセンス |
| `frontend/`（`fnl-web`）、`npm-*/`（`fnl-proxy`） | 本番用の npm の依存の LICENSE ファイル |

- 中身：`fnl-web` は nginx（BSD-2-Clause）、画面のビルド結果（MIT などの依存。上の「画面の依存」）、Alpine のパッケージ。
  `fnl-proxy` は Node.js（MIT）、`ws`（MIT）、Alpine のパッケージ。このリポジトリのコード（`server.js` など）は MIT です。
- Alpine のパッケージは、各自のライセンスのまま（BusyBox は GPL-2.0-only、OpenSSL は Apache-2.0 など）。改変せずに、そのまま入れています。
- **ソースの提供について**：Alpine のパッケージのソースは https://gitlab.alpinelinux.org/alpine/aports と https://dl-cdn.alpinelinux.org/alpine/ から入手できます
  （バージョンは `alpine-packages.txt`）。入手できない場合は、このリポジトリの Issue で請求してください。イメージを配布してから 3 年間、実費でソースを提供します。

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
  ライセンスを示しています。ライセンスの情報は、イメージの中の `/licenses`（`LICENSE`、このファイル、GPL-2.0 の全文、入っている Alpine のパッケージの
  名前・バージョン・ライセンスの一覧。スイッチのイメージは mstpd の LICENSE も）に入っています（2026-11-18 の `fnl/frr:4`・`fnl/l2switch:13`・`fnl/l3switch:10` から。
  `fnl-web`・`fnl-proxy` も同じ）。`dhcp-helper`（GPL-2.0-only OR GPL-3.0-only）は、GPL-2.0-only を選んで配布しています。
- このリポジトリの Dockerfile・スクリプト（`fnl-subif-agent`、`swcli` など）は MIT です。これらは FRR や mstpd と別のプロセスとして動かしており、
  GPL のソフトを改変して組み込んだものではありません（mstpd だけは、上のパッチで改変しており、パッチは GPL-2.0 です）。
- **ソースの提供について**：上のソフトの対応するソース（改変があればその差分を含む）は、上の場所から入手できます。
  入手できない場合は、このリポジトリの Issue で請求してください。イメージを配布してから 3 年間、実費でソースを提供します。
