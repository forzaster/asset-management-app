# CLAUDE.md (apple/ — SwiftUI版)

> ⚠ このファイルは `apple/` ディレクトリ配下で作業する際のルールです。Streamlit版は `python/CLAUDE.md` を参照。

## プロジェクト概要

asset-management の Apple マルチプラットフォーム実装（iOS 17+ / iPadOS 17+ / macOS 14+）。

- フレームワーク: SwiftUI Multiplatform（ネイティブ、Catalystではない）
- 永続化: GRDB.swift（SQLite直接、Streamlit版と同一スキーマ互換）
- DI: 内部Swift Package "AssetCore" + Repository Protocol
- チャート: Swift Charts
- CSV: CodableCSV / ZIP: Zip
- パッケージ管理: Swift Package Manager

## ディレクトリ構成

```
apple/
├── AssetManagement/                            # Xcodeプロジェクトルート（Xcode標準レイアウト）
│   ├── AssetManagement.xcodeproj
│   ├── AssetManagement/                        # アプリ本体ソース
│   │   ├── AssetManagementApp.swift            # @main エントリ
│   │   ├── RootView.swift                      # ナビゲーション（TabView / NavigationSplitView）
│   │   ├── ContentView.swift                   # 未使用（Xcodeテンプレ残骸）
│   │   ├── Navigation/Section.swift            # 4セクション定義
│   │   ├── Support/AppEnvironment.swift        # DI Container 保持
│   │   ├── ViewModels/                         # @Observable
│   │   │   ├── HomeViewModel.swift
│   │   │   ├── ProfitTrendViewModel.swift
│   │   │   ├── TransactionsViewModel.swift
│   │   │   └── DataViewModel.swift
│   │   ├── Views/
│   │   │   ├── HomeView.swift
│   │   │   ├── ProfitTrendView.swift
│   │   │   ├── TransactionsView.swift
│   │   │   ├── DataView.swift
│   │   │   └── Components/
│   │   │       ├── KPICard.swift
│   │   │       ├── ProfitLossText.swift
│   │   │       └── EmptyStateView.swift
│   │   └── Assets.xcassets/
│   ├── AssetManagementTests/                   # ホストアプリのテスト
│   └── AssetManagementUITests/                 # UIテスト
└── Packages/AssetCore/                         # ローカルSwift Package
    ├── Package.swift
    ├── Sources/AssetCore/
    │   ├── AppContainer.swift                  # DIファクトリ
    │   ├── Models/                             # Transaction / Holding / PortfolioSnapshot / Summaries
    │   ├── Repositories/                       # Protocol定義（差し替え可能 I/F）
    │   ├── SQLite/                             # GRDB実装（Schema, 4 Repositories, GRDBRecords）
    │   └── CSV/                                # ImportService + parsers
    └── Tests/AssetCoreTests/
```

> 注意: Xcodeテンプレートは `apple/AssetManagement/` を作成してその下に `AssetManagement.xcodeproj` と `AssetManagement/` ソース、`AssetManagementTests/`, `AssetManagementUITests/` を並べる構造をとります。AppParameters Plan で記載した `apple/AssetManagement.xcodeproj` トップレベル配置とは異なるので注意。

## 開発フロー

### 計画
- 大きな変更は `docs/superpowers/plans/YYYY-MM-DD-<feature>.md` に実装プランを作成し、ユーザー確認を得てから着手

### TDD
- `AssetCore` 配下の変更は必ずテストを先に書く
- View / ViewModel は ViewModel 単体テスト + View は Preview で目視確認

### 動作確認コマンド

```bash
# AssetCore のテスト（DEVELOPER_DIR を指定して Xcode toolchain を使う）
cd apple/Packages/AssetCore && \
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test

# 特定テストのみ実行
cd apple/Packages/AssetCore && \
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer swift test --filter <TestName>

# Xcodeでアプリビルド
open apple/AssetManagement/AssetManagement.xcodeproj
# → Xcode UIで ⌘+R

# CLI で iOS Simulator ビルド（コンパイル確認のみ、署名スキップ）
cd apple/AssetManagement && \
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project AssetManagement.xcodeproj -scheme AssetManagement \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

> `swift test` を CommandLineTools 経由で実行すると `no such module 'Testing'` エラーになるため、必ず `DEVELOPER_DIR` で Xcode を指定する。

## 実装ルール

### 関心の分離
- View はレイアウト・表示のみ、状態とロジックは ViewModel に
- ViewModel は `AppContainer` のプロトコル経由でデータアクセス
- AppContainer は UI 層から切り離されており単独でテスト可能

### データアクセス
- すべて `async throws` (Swift Concurrency)
- Models / Repositories は `Sendable`
- GRDB の `DatabaseQueue` を `@unchecked Sendable` クラスに閉じ込める

### CSV / DB スキーマ互換性
- `transactions.csv` などのカラム順序・命名は `python/src/scripts/export_apple_zip.py` と一致させる
- SQLite UNIQUE INDEX も Streamlit版と完全一致させる（マルチロット対応で `acq_date` 必須）
- スキーマ変更時は `python/src/core/db.py` 側も同期して変更

### 個人情報
- 銘柄名・口座番号などをコード/コメントにハードコードしない
- テストデータは架空のもの（"AAA" "BBB" "テスト銘柄A" 等）を使う
- コミットメッセージにも実銘柄・金額・口座情報を含めない

## レビューチェックリスト

実装後、動作確認前にセルフレビュー:
- [ ] View ロジック (ViewModel) のテストが追加されているか
- [ ] Repository の新規メソッドにテストがあるか
- [ ] スキーマ変更がある場合、`python/` 側も同期されたか
- [ ] Sendable 警告がないか（Swift 6 strict）
- [ ] 個人情報がコード・テストデータ・コミットメッセージに含まれていないか
