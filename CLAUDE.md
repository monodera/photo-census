# photos_count_daily

macOS Photos ライブラリの日別写真枚数・容量を表示するネイティブ macOS アプリ
PhotoCensus（SwiftUI + PhotoKit）。旧 Python CLI は `legacy/` にある。

## リポジトリ構成

- `PhotoCensus/` — SwiftUI アプリ本体（XcodeGen 管理）
  - `project.yml` — XcodeGen 設定。`.xcodeproj` は git 管理外で毎回生成する
  - `Sources/` — Swift ソース
  - `Tests/` — XCTest（ロジックのみ。PhotoKit に触れるテストは書かない）
- `legacy/` — 旧 Python CLI（osxphotos ベース、`uv` で実行）。詳細は `legacy/README.md`
- `assets/icon/` — アプリアイコンの SVG ソースと生成スクリプト（`gen_icon.py`）
- `scripts/make_dmg.sh` — Release ビルド + ad-hoc 署名 + dmg 作成
- `.github/workflows/release.yml` — タグ `v*` push で dmg を GitHub Release に添付

## ビルド・テスト

```bash
cd PhotoCensus && xcodegen generate && cd ..
xcodebuild -project PhotoCensus/PhotoCensus.xcodeproj \
  -scheme PhotoCensus -destination 'platform=macOS' build test
```

実行: `open build/Build/Products/Debug/PhotoCensus.app`
（`-derivedDataPath build` でビルドした場合）

## アーキテクチャ

- `Models.swift` — `AssetRecord`（PhotoKit 資産の純粋データ表現）、`DailyStat`、`AggregationResult`
- `PhotoLibraryService.swift` — PhotoKit アクセス層。`PHAsset` → `AssetRecord` 変換。
  ファイルサイズは `PHAssetResource` の `fileSize`（KVC、非公開キー）から取得。
  RAW 判定はリソース UTI が `public.camera-raw-image` に適合するか
- `DailyAggregator.swift` — 集計・ソートの純粋関数。ユニットテストの主対象
- `LibraryStatsViewModel.swift` — `@Observable`。読み込み状態・フィルタ（`MediaFilter`:
  all / photosOnly / rawOnly の単一ドロップダウン）・ソートを保持
- `Views/` — `ContentView`（切り替え・ツールバー）、`StatsTableView`、`ChartView`、
  `SlidingSegmentedControl`（Table/Chart・Count/Size 切替用のカスタムアニメーション
  付きスライドコントロール）、`DayDetailView`（テーブル行またはグラフの棒クリックで
  開く日別サムネイルグリッド）、`AccessDeniedView`

## 実装上のポイント

- テストターゲットは TEST_HOST なし（アプリ起動で TCC ダイアログが出るのを避ける）。
  ロジックファイルを直接テストターゲットのソースに含めている（`project.yml` 参照)
- XcodeGen の `sources` に `optional: true` を付けてもファイル参照自体は
  `.xcodeproj` に残るため、「ファイルが存在しなくてもビルドが通る」ようにはならない。
  テストターゲットのソースとして指定したファイルは実在している必要がある
- 集計対象は `includeAssetSourceTypes = [.typeUserLibrary]` でライブラリビュー相当に限定。
  hidden・共有アルバム・未保存の「あなたと共有」は PhotoKit 側で除外される
- サイズは `.photo` / `.video` / `.alternatePhoto`（RAW+JPEG の RAW 側）リソースの合計。
  編集派生ファイルは含めない。サイズ不明（iCloud 未ダウンロード等）は件数を集計して UI に注記
- 日付グループ化はローカルタイムゾーン。写真ごとの撮影タイムゾーンは PhotoKit では取得不可
  （旧 CLI との既知の差分。README の Known limitations 参照）
- 日付不明は `"Unknown"`、ソート時は常に末尾
- 容量表示は 10 進単位（KB=1000B、Finder と同じ）。`Formatters.sizeString` を使う
- 読み込みは起動時の一度きりのスナップショット。読み込み中の進捗コールバックは
  約 30Hz に間引いて UI に反映する（`PhotoLibraryService.loadRecords` 参照）。
  アプリ実行中に Photos.app で追加・削除された写真はテーブル・グラフには反映されず、
  再起動が必要（`DayDetailView` は都度ライブラリから取得するため、その場合テーブルの
  件数とサムネイル数が食い違いうる）
- チャート（`ChartView.swift`）: macOS の Swift Charts の `chartScrollableAxes` /
  `chartXVisibleDomain` はマークを描画しないバグがあるため使用禁止。代わりに
  `ScrollView` + 明示幅（1日あたり 12pt、バー幅 9pt）+ `NSScrollView` を
  `NSViewRepresentable` 経由で直接観測（デバウンス付き）してスクロール位置を取得し、
  可視範囲に応じて右端固定の y 軸を再スケール（アニメーション付き）している。
  x 軸は年月ラベル
- ホバー処理は `ChartInteractionOverlay` に隔離し、マウス移動のたびに数千本の
  `BarMark` を再評価させないようにしている。ホバーで日付・件数・サイズのツール
  チップを表示し、クリックでその日の `DayDetailView` を開く

## リリース

`git tag vX.Y.Z && git push origin vX.Y.Z` → GitHub Actions が
ad-hoc 署名の dmg（`PhotoCensus-vX.Y.Z.dmg`）を Release に添付（無署名配布。
README に Gatekeeper 回避手順あり）。
Developer ID 署名 + notarization へ移行する場合は workflow に署名ステップを追加する。
