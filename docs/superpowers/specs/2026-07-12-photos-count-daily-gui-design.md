# PhotosCountDaily GUI アプリ設計

日付: 2026-07-12
ステータス: 承認済み

## 目的

macOS Photos ライブラリの日別写真枚数・容量を集計する既存 Python CLI
(`photos_count_daily.py`) を、SwiftUI 製のネイティブ macOS アプリとして作り直す。
既存 CLI はレガシー資産として `legacy/` に残す。

## 決定事項

| 項目 | 決定 |
| --- | --- |
| アプリ形態 | ネイティブ macOS アプリ（SwiftUI で完全書き直し） |
| データ取得 | PhotoKit（公式 API）。Photos.sqlite 直接読みは行わない |
| 対象 OS | macOS 14 以降 |
| 機能 | 日別テーブル表示・棒グラフ・日付選択で写真サムネイル一覧・フィルタ（写真のみ / RAW のみ） |
| 配布 | GitHub Releases に dmg。当面は ad-hoc 署名（無署名相当）。後日 Developer ID 署名 + notarization に差し替え可能な構成 |
| プロジェクト管理 | XcodeGen（`project.yml` を git 管理、`.xcodeproj` は生成物として git 管理外） |
| リポジトリ | 本リポジトリ内。既存 Python コードは `legacy/` へ移動 |
| アプリ名 | PhotosCountDaily（bundle ID: `com.monodera.PhotosCountDaily`） |

## リポジトリ構成（再編後）

```
photos_count_daily/
├── legacy/                # 既存 Python CLI 一式（photos_count_daily.py,
│                          #   pyproject.toml, uv.lock, 旧 README）
├── PhotosCountDaily/      # SwiftUI アプリ本体
│   ├── project.yml        # XcodeGen 設定
│   ├── Sources/           # Swift ソース
│   └── Tests/             # ユニットテスト
├── .github/workflows/release.yml   # タグ push で dmg をビルドし Releases へ
├── README.md / README_ja.md        # アプリ中心に書き直し
└── CLAUDE.md                       # 新構成に合わせて更新
```

## アーキテクチャ

集計ロジックを PhotoKit から分離し、純粋関数としてテスト可能にする。

- **AssetRecord**（struct）— PhotoKit 資産の中間表現。
  `creationDate: Date?` / `isVideo: Bool` / `isRAW: Bool` / `fileSize: Int64?`
  のみを持つ。
- **PhotoLibraryService** — PhotoKit アクセス層。
  - 読み取り専用の権限リクエスト（`NSPhotoLibraryUsageDescription` を Info.plist に設定）
  - `PHAsset.fetchAssets` で全資産を取得
  - `PHAssetResource.assetResources(for:)` からファイルサイズ（decimal 単位で
    Finder と一致させる）と RAW 判定（UTI が `public.camera-raw-image` に適合、
    RAW+JPEG ペアの alternatePhoto リソースも含む）を取得
  - 大規模ライブラリでは resource 取得に時間がかかるため、進捗をコールバックで
    通知し UI に進捗バーを表示する
- **DailyAggregator**（純関数）— `[AssetRecord]` + フィルタ設定 →
  `[DailyStat(day: String, count: Int, totalBytes: Int64)]`。
  日付グループ化は `Calendar.current`（ローカルタイムゾーン）で行う。
  `creationDate == nil` は `"Unknown"` に集計しソート時は常に末尾。
- **LibraryStatsViewModel**（`@Observable`）— 読み込み状態・進捗・フィルタ・
  ソート状態を保持。
- **View 構成**
  - `ContentView` — ツールバーにフィルタトグル、Table / Chart の表示切り替え
  - `StatsTableView` — SwiftUI `Table`。列（日付・枚数・容量）クリックでソート
  - `ChartView` — Swift Charts の棒グラフ。枚数 / 容量のメトリクス切り替え
  - `DayDetailView` — 選択した日の写真サムネイルを `PHCachingImageManager` で
    グリッド表示
- **容量表示** — `ByteCountFormatter`（decimal、KB=1000B、Finder と同一）
- **エラー処理**
  - 権限拒否時: 説明ビュー + 「システム設定を開く」ボタン
  - iCloud 未ダウンロード等でサイズ不明の資産: 件数をカウントし UI に注記表示

## CLI 版との仕様差（README に既知の制限として明記）

- `--library`（カスタムライブラリ指定）は非対応。PhotoKit はシステム
  フォトライブラリのみ扱える。
- `--date-field` 相当は `creationDate`（撮影日）固定。`date_original` /
  `date_added` は PhotoKit の公開 API では取得できない。
- 日付グループ化は Mac のローカルタイムゾーン基準。写真ごとの撮影タイム
  ゾーンは取得できないため、海外撮影分は CLI 版と日付が 1 日ずれる場合がある。
- デバッグ系オプション（`--debug` / `--debug-date` / `--diagnose-tz`）は非対応。

hidden 写真・共有アルバム・ライブラリ未保存の「あなたと共有」写真は PhotoKit の
デフォルト取得で除外されるため、CLI 版と同じ集計対象になる。バースト写真も
代表写真のみが返るため CLI 版の挙動と整合する。

## 配布フロー

1. タグ push をトリガーに GitHub Actions（macOS ランナー）が起動
2. `xcodegen` → `xcodebuild archive` → `.app` を取り出し ad-hoc 署名
3. `hdiutil` で dmg 作成、GitHub Releases にアップロード
4. README に Gatekeeper 回避手順（右クリック→開く、または
   `xattr -dr com.apple.quarantine`）を記載
5. 将来 Apple Developer Program 加入時は署名・notarization ステップを
   workflow に追加するだけで移行できるようにする

## テスト

- `DailyAggregator` のユニットテスト（XCTest）: フィルタ（写真のみ / RAW のみ）、
  日付グループ化、Unknown 扱い、容量合計
- 書式化（日付・サイズ表示）のユニットテスト
- 手動検証: 実ライブラリでアプリの合計値と `legacy/` の CLI 出力を突き合わせ、
  差異が既知の制限（タイムゾーン・date-field）で説明できることを確認

## 実装時に検証が必要な事項

- `PHAssetResource` の `fileSize`（KVC 経由の値）が iCloud 未ダウンロードの
  資産でも取得できるか。取得できない場合は「サイズ不明 N 件」として注記する
  設計で吸収する。
- RAW 判定・サイズ取得のための全資産 resource 列挙のパフォーマンス。
  遅い場合は結果をキャッシュする（初回のみフルスキャン）。
