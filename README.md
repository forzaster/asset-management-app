# 資産管理アプリ

株式・投資信託・NISA・外国株ETFの売買・配当履歴を管理し、損益を可視化するローカル動作のWebアプリ。

## 機能

| 画面 | 内容 |
|------|------|
| **ホーム** | 累積損益KPI・投資分類別/利益種別別の内訳グラフ・保有銘柄一覧（yfinance株価Fetch） |
| **利益推移** | 年次損益推移グラフ（投資分類別積み上げ）・累積損益折れ線・年次/カテゴリ別集計テーブル |
| **取引履歴** | 全取引の一覧・フィルター（年/口座/分類/種別/銘柄名）・CSVダウンロード |
| **設定** | CSVインポート（取引履歴/保有銘柄）・保有銘柄の手動編集（数量・取得単価・ティッカー）・CSV出力 |

## 対応する投資分類

- 日本株
- 投資信託
- 外国株ETF
- REIT（J-REIT含む）
- 外国投信（MMFなど）

## セットアップ

### 必要環境

- Python 3.11+
- [uv](https://docs.astral.sh/uv/)

### インストール

```bash
cd python && uv sync
```

### データインポート

データ管理画面からCSVファイルをアップロードしてインポートします。

- `python/exports/transactions.csv` — 取引履歴
- `python/exports/holdings.csv` — 保有銘柄

CSVエクスポート（現在のDBからバックアップ）:

```bash
cd python && uv run python src/scripts/export_csv.py
```

### アプリ起動

```bash
cd python && uv run streamlit run src/app.py
```

ブラウザで http://localhost:8501 を開く。

## Apple版（SwiftUI / iOS / iPadOS / macOS）

Mac/iPad/iPhoneネイティブアプリ。最小OS: iOS 17 / iPadOS 17 / macOS 14。

```bash
open apple/AssetManagement.xcodeproj
# → Xcode UI で ⌘+R
```

詳細は `apple/CLAUDE.md` および `docs/superpowers/specs/2026-05-24-apple-app-design.md` 参照。

## ファイル構成

```
.
├── python/                       # Streamlit版
│   ├── pyproject.toml
│   ├── assets.db                 # SQLiteデータベース（自動生成）
│   ├── exports/                  # CSVエクスポート出力先
│   └── src/
│       ├── app.py                # Streamlitエントリーポイント
│       ├── core/db.py            # DB接続・スキーマ・クエリ・インポート関数
│       ├── pages/                # 4画面（home, profit_trend, transactions, settings）
│       └── scripts/export_csv.py # DB → CSVエクスポート
├── apple/                        # Apple SwiftUI版（実装予定）
└── docs/
    ├── plans/                    # 実装計画（個人作業向け）
    └── superpowers/
        ├── specs/                # 設計仕様
        └── plans/                # 詳細実装プラン
```

## データベース

SQLite（`assets.db`）に以下のテーブルを保持します。

| テーブル | 内容 |
|----------|------|
| `transactions` | 全取引履歴（売買・配当・税金） |
| `holdings` | 現保有銘柄（数量・取得単価・yfinanceティッカー） |
| `portfolio_snapshots` | 年次ポートフォリオ推移スナップショット |

## 株価の自動取得

ホーム画面の **🔄 Fetch** ボタンで [yfinance](https://github.com/ranaroussi/yfinance) を使い現在値を取得します。

- 日本株・J-REIT: `{証券コード}.T` 形式（例: `1234.T`）
- 米国ETF: そのままティッカー（例: `AAA`）
- 投資信託: yfinance非対応のため手動管理

設定画面の保有銘柄テーブルで `YFティッカー` 列を編集することで任意の銘柄を追加できます。
