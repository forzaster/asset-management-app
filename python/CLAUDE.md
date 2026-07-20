# CLAUDE.md (python/ — Streamlit版)

> ⚠ このファイルは `python/` ディレクトリ配下で作業する際のルールです。Apple版は `apple/CLAUDE.md` を参照。
> ルートの `CLAUDE.md` には両プラットフォーム共通の案内のみ記載しています。

## プロジェクト概要

株式・投資信託・NISA・外国株ETFの売買・配当履歴を管理し、損益を可視化するローカル動作Webアプリ。

- フレームワーク: Streamlit（`st.navigation` マルチページ構成）
- DB: SQLite（`assets.db`）
- パッケージ管理: **uv**（`pip` は使わない）
- チャート: Plotly Express / Graph Objects
- 株価取得: yfinance

## 開発フロー

### 1. Plan を立てる

実装前に必ず計画を `docs/plans/` に Markdown ファイルとして出力し、**ユーザーの確認を得てから実装を開始する**。

```
docs/plans/
└── YYYYMMDD_<feature-name>.md
```

Plan ファイルの構成：

```markdown
# Plan: <機能名>

## 目的
何を解決するか

## 変更対象ファイル
- path/to/file.py — 変更内容の概要

## 実装手順
1. ...
2. ...

## 考慮事項 / トレードオフ
- ...
```

### 2. 実装

ユーザー確認後に実装する。

### 3. レビュー

実装後、動作確認の前に以下の観点でセルフレビューを行う。

#### 関心の分離
- [ ] UI（`pages/`）・ビジネスロジック（`core/`）・インフラ（DB・外部API）が適切に分離されているか
- [ ] ページファイルにSQL・パースロジックが直書きされていないか
- [ ] `core/db.py` を経由せずに DB へ直接接続していないか

#### 個人情報・機密情報
- [ ] 実名・口座番号・証券コードなどの個人情報がハードコードされていないか
- [ ] ログ・エラーメッセージに取引金額や保有数量が出力されていないか
- [ ] `state.xlsx/` 配下のソースデータをコードに直書きしていないか
- [ ] **ユーザーが保有・取引した銘柄名・銘柄コード・口座種別などをコード内にハードコードしていないか**（マッピングテーブル・定数・コメント等いかなる形でも禁止。汎用ロジックで対応できない場合はユーザー設定ファイルや DB で管理する）

#### データ保全
- [ ] 既存の `assets.db` データが意図せず削除・上書きされないか
- [ ] インポート処理（`import_html.py`）は冪等か（再実行しても重複しないか）
- [ ] 保有銘柄の編集（settings.py）で保存前にバリデーションしているか

#### マイグレーション
- [ ] DBスキーマを変更した場合、既存の `assets.db` を壊さないか
- [ ] カラム追加は `ALTER TABLE` または `CREATE TABLE IF NOT EXISTS` で対応できるか
- [ ] 破壊的変更（カラム削除・型変更）が必要なら、`scripts/import_html.py` の再実行で再構築できるか確認する

### 4. 動作確認

- `uv run python3 -m py_compile <file>` で構文チェック
- クエリや関数は `uv run python3 -c "..."` で単体テスト
- Streamlit アプリは `uv run streamlit run app.py` で起動確認

## コマンド

```bash
# 依存関係インストール
uv sync

# DBデータをCSVエクスポート（exports/ に出力）
uv run python src/scripts/export_csv.py

# アプリ起動
uv run streamlit run src/app.py
```

## ディレクトリ構成

```
.
├── pyproject.toml
├── assets.db                 # SQLite DB（自動生成）
├── exports/                  # CSVエクスポート出力先
├── src/
│   ├── app.py                # Streamlit エントリーポイント
│   ├── core/
│   │   └── db.py             # DB 接続・スキーマ・クエリ・インポート関数
│   ├── pages/
│   │   ├── home.py           # ホーム：KPI・保有銘柄・Fetch
│   │   ├── profit_trend.py   # 利益推移：年次グラフ
│   │   ├── transactions.py   # 取引履歴：フィルター・CSV出力
│   │   └── settings.py       # 設定：CSVインポート・保有銘柄編集
│   └── scripts/
│       └── export_csv.py     # DB → exports/ CSV出力
└── docs/
    └── plans/                # 実装計画ファイル置き場
```

## DB スキーマ概要

| テーブル | 主なカラム |
|----------|-----------|
| `transactions` | account_type, ticker_name, trade_date, profit_type, profit_loss, tax, category, year, month |
| `holdings` | ticker_name, account_type, category, quantity, avg_cost, yf_ticker, last_price |
| `portfolio_snapshots` | snapshot_date, total_assets, realized_cumulative, unrealized_gains |

## 実装上の注意

- 日本株の yfinance ティッカー: `{4桁コード}.T`
- 投資信託は yfinance 非対応 → `yf_ticker` は空のまま
- `@st.cache_data(ttl=300)` でDB読み取りをキャッシュ。DB更新後は `.clear()` を呼ぶ
- パッケージ追加は `uv add <package>`、実行は `uv run <command>`
