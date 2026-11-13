# frontend

Containerlabベースのオープンソース版CML（ラボ管理GUI）のフロントエンド。React + React Flow（トポロジエディタ）+ xterm.js（統合コンソール）。詳しい構成はリポジトリルートの `README.md` と、`docs/manual/` のマニュアル（PDF）を参照。

## セットアップ

```sh
npm install
npm run dev
```

デフォルトでは `http://localhost:5173` で起動する（Vite標準ポート）。

## 現状

- 開発・確認は、clab-api-serverの動くサーバー（`backend/nginx/deploy-frontend.sh`で反映）に対して行う
- API は clab-api-server のもの（Swagger UI／GitHub Pages の API 仕様書）を使う

## dev-tools について

`../dev-tools/` に、統合コンソール（xterm.js）疎通確認用の簡易WebSocketエコーサーバーがある。バックエンド（clab-api-server）未接続でもコンソール表示だけ先行確認できる。

```sh
cd ../dev-tools
npm install
npm start
```

## Lint

```sh
npm run lint
```

## テスト

```sh
npm test
```

vitest（2026-10-15〜）。トポロジ⇔containerlab YAMLの変換・保存と読み込みの往復・ノードごとの設定コマンド
（`src/utils/labTopology.test.ts`）と、リンクの品質の値の変換（`src/utils/linkCondition.test.ts`）。
イメージのタグを上げた時に古いルーターがPCと判定された不具合（2026-10-15）のような退行を防ぐためのもの。
