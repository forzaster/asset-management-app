# CLAUDE.md (root)

asset-management は **Streamlit版（Python）** と **Apple版（Mac/iPad/iPhone, SwiftUI）** の2つの実装を持つマルチプラットフォーム構成です。

## ディレクトリ

| パス | 内容 | 詳細ルール |
|------|------|------------|
| `python/` | 既存Streamlit版 | `python/CLAUDE.md` |
| `apple/`  | Apple SwiftUI版  | `apple/CLAUDE.md` |
| `docs/`   | 仕様・設計・実装プラン | `docs/superpowers/specs/`, `docs/superpowers/plans/`, `docs/plans/` |

## 作業時のルール

- `python/` 配下を触る場合は `python/CLAUDE.md` を必ず参照
- `apple/` 配下を触る場合は `apple/CLAUDE.md` を必ず参照
- 両方をまたぐ作業（例: データ互換性・CSV import/exportのスキーマ）の場合は両方を参照

## データの流れ

```
Streamlit版（python/）
  ├─ assets.db (SQLite)
  └─ export ZIP → Apple版（apple/）が import
```

MVPでは Streamlit → Apple の片方向同期。将来的にiCloud Drive経由の双方向化を検討。

## 起動コマンド要約

```bash
# Streamlit版
cd python && uv run streamlit run src/app.py

# Apple版（Xcodeで開く）
open apple/AssetManagement.xcodeproj
```

## 開発フロー（両プラットフォーム共通）

1. 大きな変更は `docs/superpowers/plans/YYYY-MM-DD-<feature>.md` に実装プランを作成し、ユーザー確認を得てから着手
2. 実装後、動作確認前にセルフレビュー（各 `CLAUDE.md` のチェックリスト）
3. テスト・動作確認後にコミット

## レビューガイドライン（必須チェック項目）

コード変更、コミット、PR、レビュー時には**必ず以下を確認**する。Apple/Python どちらのコードでも共通。

### 機密情報・個人情報の混入チェック

- [ ] **実在の銘柄名・銘柄コード・口座種別** がコード／テストデータ／コメント／コミットメッセージにハードコードされていないか
  - テストデータは "AAA" "BBB" "テスト銘柄A" 等の架空名・架空コードを使用すること
  - マッピングテーブル・定数・コメント等いかなる形でも禁止
- [ ] **実取引金額・保有数量・実勘定残高** がコード／ログ／コミットメッセージに含まれていないか
- [ ] **個人を特定し得る情報**（氏名、口座番号、メールアドレス、電話番号等）が含まれていないか
- [ ] `python/state.xlsx/`, `python/state_data/`, `python/exports/`, `python/scripts/` 配下のソースデータをコードに直書きしていないか
- [ ] `assets.db` 等の実DBファイルがコミット対象に含まれていないか（`.gitignore` で除外されているか確認）
- [ ] APIキー・トークン・パスワード等の認証情報が含まれていないか
- [ ] エラーメッセージ・ログ出力で取引金額・保有数量・実銘柄名が出力されていないか

汎用ロジックで対応できない場合は、ユーザー設定ファイルや DB で管理する。

### コミットメッセージ

- 機能の説明のみにとどめ、金額・銘柄名・口座情報を含めない
- 例 OK: `feat: 還付金インポート機能を追加`
- 例 NG: `feat: 還付金 123,456円を ABC証券から取り込み`
