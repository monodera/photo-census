# PhotosCountDaily GUI アプリ実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** macOS Photos ライブラリの日別枚数・容量を表示する SwiftUI ネイティブアプリを構築し、既存 Python CLI を `legacy/` に退避、GitHub Releases への dmg 配布フローを整備する。

**Architecture:** PhotoKit 資産を純粋データ `AssetRecord` に変換し、集計 (`DailyAggregator`) とフォーマット (`Formatters`) を PhotoKit 非依存の純粋関数としてユニットテストする。UI は `@Observable` な ViewModel + SwiftUI (Table / Swift Charts / サムネイルグリッド)。

**Tech Stack:** Swift 5.9+ / SwiftUI / PhotoKit / Swift Charts / XCTest / XcodeGen / GitHub Actions

**Spec:** `docs/superpowers/specs/2026-07-12-photos-count-daily-gui-design.md`

## Global Constraints

- Deployment target: **macOS 14.0** 以上
- アプリ名 **PhotosCountDaily**、bundle ID **com.monodera.PhotosCountDaily**、バージョン **0.1.0**
- データ取得は **PhotoKit のみ**（Photos.sqlite 直接読みは禁止）
- 容量表示は **10 進単位（KB=1000B、Finder と同一）**
- 日付グループ化はローカルタイムゾーン。日付不明は `"Unknown"` としてソート時常に末尾
- `.xcodeproj` は git 管理外（XcodeGen の `project.yml` から生成）
- ロジックのユニットテストは PhotoKit に触れないこと（TCC プロンプトが出るため）
- コミットメッセージは英語・命令形。末尾に `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` を付ける
- 作業ディレクトリ: `/Users/monodera/tmp/photos_count_daily`（リポジトリルート。以下パスは全てここからの相対）

---

### Task 0: 開発環境の準備

**Files:** なし（環境セットアップのみ）

**Interfaces:**
- Produces: `xcodebuild`（Xcode 本体）と `xcodegen` が使える状態。以降の全タスクの前提。

- [ ] **Step 1: Xcode をインストール（ユーザー操作）**

App Store から Xcode をインストールする（無料、数十 GB・時間がかかる）。これは自動化できないのでユーザーに依頼すること。

- [ ] **Step 2: Xcode をアクティブな開発ツールに設定**

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
xcodebuild -runFirstLaunch
```

- [ ] **Step 3: 確認**

Run: `xcodebuild -version`
Expected: `Xcode 16.x`（またはそれ以降）が表示される

- [ ] **Step 4: XcodeGen をインストール**

```bash
brew install xcodegen
```

Run: `xcodegen --version`
Expected: `Version: 2.x.x`

---

### Task 1: Python CLI を legacy/ へ移動

**Files:**
- Move: `photos_count_daily.py` → `legacy/photos_count_daily.py`
- Move: `pyproject.toml` → `legacy/pyproject.toml`
- Move: `uv.lock` → `legacy/uv.lock`
- Move: `README.md` → `legacy/README.md`
- Move: `README_ja.md` → `legacy/README_ja.md`
- Create: `.gitignore`

**Interfaces:**
- Produces: リポジトリルートが空き、Task 2 以降がアプリ用構成を作れる。CLI は `legacy/` 内で従来どおり動く（Task 6 の突き合わせ検証で使用）。

- [ ] **Step 1: ファイルを git mv で移動**

```bash
mkdir -p legacy
git mv photos_count_daily.py pyproject.toml uv.lock README.md README_ja.md legacy/
rm -rf __pycache__ .venv
```

- [ ] **Step 2: .gitignore を作成**

`.gitignore`（リポジトリルート、新規作成）:

```gitignore
# Python (legacy CLI)
__pycache__/
.venv/

# Xcode / XcodeGen
*.xcodeproj
build/
DerivedData/

# macOS
.DS_Store

# Release artifacts
*.dmg
```

- [ ] **Step 3: CLI が legacy/ 内で動くことを確認**

Run: `cd legacy && uv sync && uv run python photos_count_daily.py --help`
Expected: usage が表示され exit 0（ライブラリ読み込みは不要、`--help` で十分）

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "Move Python CLI to legacy/

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: XcodeGen プロジェクトスケルトン

**Files:**
- Create: `PhotosCountDaily/project.yml`
- Create: `PhotosCountDaily/Sources/PhotosCountDailyApp.swift`
- Create: `PhotosCountDaily/Sources/Views/ContentView.swift`（プレースホルダ、Task 6 で置き換え）
- Create: `PhotosCountDaily/Tests/SmokeTests.swift`

**Interfaces:**
- Produces: `xcodegen generate` → `xcodebuild build` / `xcodebuild test` が通るプロジェクト。以降のタスクは `Sources/` `Tests/` にファイルを足すだけで再生成すれば取り込まれる。

- [ ] **Step 1: project.yml を作成**

`PhotosCountDaily/project.yml`:

```yaml
name: PhotosCountDaily
options:
  bundleIdPrefix: com.monodera
  deploymentTarget:
    macOS: "14.0"
  createIntermediateGroups: true
targets:
  PhotosCountDaily:
    type: application
    platform: macOS
    sources:
      - Sources
    info:
      path: Sources/Info.plist
      properties:
        CFBundleShortVersionString: "0.1.0"
        CFBundleVersion: "1"
        LSMinimumSystemVersion: "14.0"
        LSApplicationCategoryType: public.app-category.photography
        NSPhotoLibraryUsageDescription: "Reads your Photos library to count photos and total size per day."
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.monodera.PhotosCountDaily
        CODE_SIGN_IDENTITY: "-"
        CODE_SIGN_STYLE: Manual
  PhotosCountDailyTests:
    type: bundle.unit-test
    platform: macOS
    sources:
      - Tests
      - path: Sources/Models.swift
        optional: true
      - path: Sources/Formatters.swift
        optional: true
      - path: Sources/DailyAggregator.swift
        optional: true
    settings:
      base:
        GENERATE_INFOPLIST_FILE: YES
schemes:
  PhotosCountDaily:
    build:
      targets:
        PhotosCountDaily: all
        PhotosCountDailyTests: [test]
    run:
      config: Debug
    test:
      config: Debug
      targets:
        - PhotosCountDailyTests
```

**設計メモ:** テストターゲットはアプリターゲットに依存させず（TEST_HOST なし）、ロジックファイル（Models / Formatters / DailyAggregator）を直接コンパイルに含める。アプリをホストにするとテスト実行時にアプリが起動し、`ContentView` の `.task` が Photos 権限ダイアログ（TCC）を出して CI やテストが止まるため。`optional: true` は該当ファイルが Task 3–4 で追加されるまでビルドを通すための指定。

- [ ] **Step 2: アプリエントリポイントを作成**

`PhotosCountDaily/Sources/PhotosCountDailyApp.swift`:

```swift
import SwiftUI

@main
struct PhotosCountDailyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

- [ ] **Step 3: プレースホルダの ContentView を作成**

`PhotosCountDaily/Sources/Views/ContentView.swift`:

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("PhotosCountDaily")
            .frame(minWidth: 640, minHeight: 480)
    }
}
```

- [ ] **Step 4: スモークテストを作成**

`PhotosCountDaily/Tests/SmokeTests.swift`:

```swift
import XCTest

final class SmokeTests: XCTestCase {
    func testTestTargetRuns() {
        XCTAssertTrue(true)
    }
}
```

- [ ] **Step 5: 生成してビルド・テスト**

```bash
cd PhotosCountDaily && xcodegen generate && cd ..
xcodebuild -project PhotosCountDaily/PhotosCountDaily.xcodeproj \
  -scheme PhotosCountDaily -destination 'platform=macOS' build
xcodebuild -project PhotosCountDaily/PhotosCountDaily.xcodeproj \
  -scheme PhotosCountDaily -destination 'platform=macOS' test
```

Expected: `BUILD SUCCEEDED` と `TEST SUCCEEDED`（SmokeTests 1 件パス）

- [ ] **Step 6: Commit**

```bash
git add PhotosCountDaily
git commit -m "Add XcodeGen skeleton for SwiftUI app

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: Models + Formatters（TDD）

**Files:**
- Create: `PhotosCountDaily/Sources/Models.swift`
- Create: `PhotosCountDaily/Sources/Formatters.swift`
- Test: `PhotosCountDaily/Tests/FormattersTests.swift`

**Interfaces:**
- Produces:
  - `struct AssetRecord { var creationDate: Date?; var isVideo: Bool; var isRAW: Bool; var fileSize: Int64? }`
  - `struct DailyStat: Identifiable, Equatable { var day: String; var date: Date?; var count: Int; var totalBytes: Int64; var id: String { day } }`
  - `struct AggregationResult: Equatable { var stats: [DailyStat]; var totalCount: Int; var totalBytes: Int64; var unknownSizeCount: Int; static let empty: AggregationResult }`
  - `Formatters.dayString(from: Date?, calendar: Calendar) -> String`
  - `Formatters.sizeString(fromBytes: Int64) -> String`

- [ ] **Step 1: 失敗するテストを書く**

`PhotosCountDaily/Tests/FormattersTests.swift`:

```swift
import XCTest

final class FormattersTests: XCTestCase {
    private var tokyo: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    private func date(_ string: String, timeZone: String = "Asia/Tokyo") -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: timeZone)!
        return formatter.date(from: string)!
    }

    func testDayStringFormatsLocalDay() {
        XCTAssertEqual(Formatters.dayString(from: date("2024-12-15 09:30:00"), calendar: tokyo), "2024-12-15")
    }

    func testDayStringUsesCalendarTimeZone() {
        // UTC 2024-12-15 23:30 = 東京では 2024-12-16 08:30 → calendar のタイムゾーンで日付が決まる
        XCTAssertEqual(
            Formatters.dayString(from: date("2024-12-15 23:30:00", timeZone: "UTC"), calendar: tokyo),
            "2024-12-16"
        )
    }

    func testDayStringNilIsUnknown() {
        XCTAssertEqual(Formatters.dayString(from: nil, calendar: tokyo), "Unknown")
    }

    func testSizeStringBytes() {
        XCTAssertEqual(Formatters.sizeString(fromBytes: 999), "999 B")
    }

    func testSizeStringKB() {
        XCTAssertEqual(Formatters.sizeString(fromBytes: 1000), "1.0 KB")
    }

    func testSizeStringMB() {
        XCTAssertEqual(Formatters.sizeString(fromBytes: 980_500_000), "980.5 MB")
    }

    func testSizeStringGB() {
        XCTAssertEqual(Formatters.sizeString(fromBytes: 2_100_000_000), "2.1 GB")
    }

    func testSizeStringRollsOverNearUnitBoundary() {
        // 999.96 MB は "1000.0 MB" と表示されてしまうため GB に繰り上げる
        XCTAssertEqual(Formatters.sizeString(fromBytes: 999_960_000), "1.0 GB")
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

```bash
cd PhotosCountDaily && xcodegen generate && cd ..
xcodebuild -project PhotosCountDaily/PhotosCountDaily.xcodeproj \
  -scheme PhotosCountDaily -destination 'platform=macOS' test
```

Expected: ビルドエラー `cannot find 'Formatters' in scope` で FAIL

- [ ] **Step 3: Models と Formatters を実装**

`PhotosCountDaily/Sources/Models.swift`:

```swift
import Foundation

/// PhotoKit 資産の中間表現。集計ロジックを PhotoKit から切り離すための純粋データ。
struct AssetRecord: Equatable {
    var creationDate: Date?
    var isVideo: Bool
    var isRAW: Bool
    /// nil はサイズ不明（iCloud 未ダウンロード等でリソースからサイズが取れない場合）
    var fileSize: Int64?
}

struct DailyStat: Identifiable, Equatable {
    /// "YYYY-MM-DD" または "Unknown"
    var day: String
    /// その日の 00:00（ローカルタイムゾーン）。Unknown は nil。グラフの x 軸に使う
    var date: Date?
    var count: Int
    var totalBytes: Int64
    var id: String { day }
}

struct AggregationResult: Equatable {
    var stats: [DailyStat]
    var totalCount: Int
    var totalBytes: Int64
    /// fileSize が nil だった（合計に含められなかった）資産数
    var unknownSizeCount: Int

    static let empty = AggregationResult(stats: [], totalCount: 0, totalBytes: 0, unknownSizeCount: 0)
}
```

`PhotosCountDaily/Sources/Formatters.swift`:

```swift
import Foundation

enum Formatters {
    /// "YYYY-MM-DD"（calendar のタイムゾーン基準）。nil は "Unknown"
    static func dayString(from date: Date?, calendar: Calendar = .current) -> String {
        guard let date else { return "Unknown" }
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year!, components.month!, components.day!)
    }

    /// 10 進単位（KB=1000B、Finder と同一）の人間可読サイズ表記
    static func sizeString(fromBytes bytes: Int64) -> String {
        if bytes < 1000 { return "\(bytes) B" }
        var size = Double(bytes)
        for unit in ["KB", "MB", "GB"] {
            size /= 1000
            // 999.95 以上は "1000.0" と表示されるため次の単位に繰り上げる
            if (size * 10).rounded() / 10 < 1000 {
                return String(format: "%.1f %@", size, unit)
            }
        }
        return String(format: "%.1f TB", size / 1000)
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

```bash
cd PhotosCountDaily && xcodegen generate && cd ..
xcodebuild -project PhotosCountDaily/PhotosCountDaily.xcodeproj \
  -scheme PhotosCountDaily -destination 'platform=macOS' test
```

Expected: `TEST SUCCEEDED`（FormattersTests 8 件 + SmokeTests 1 件パス）

- [ ] **Step 5: Commit**

```bash
git add PhotosCountDaily
git commit -m "Add asset models and day/size formatters with tests

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: DailyAggregator（TDD）

**Files:**
- Create: `PhotosCountDaily/Sources/DailyAggregator.swift`
- Test: `PhotosCountDaily/Tests/DailyAggregatorTests.swift`

**Interfaces:**
- Consumes: `AssetRecord`, `DailyStat`, `AggregationResult`, `Formatters.dayString`（Task 3）
- Produces:
  - `enum StatSortField: String, CaseIterable { case date, count, size }`
  - `DailyAggregator.aggregate(_ records: [AssetRecord], photosOnly: Bool, rawOnly: Bool, calendar: Calendar) -> AggregationResult`
  - `DailyAggregator.sorted(_ stats: [DailyStat], by field: StatSortField, ascending: Bool) -> [DailyStat]`（Unknown 常に末尾）

- [ ] **Step 1: 失敗するテストを書く**

`PhotosCountDaily/Tests/DailyAggregatorTests.swift`:

```swift
import XCTest

final class DailyAggregatorTests: XCTestCase {
    private var tokyo: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return calendar
    }

    private func date(_ string: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return formatter.date(from: string)!
    }

    private func record(
        _ day: String?,
        isVideo: Bool = false,
        isRAW: Bool = false,
        size: Int64? = 1_000
    ) -> AssetRecord {
        AssetRecord(
            creationDate: day.map { date("\($0) 12:00:00") },
            isVideo: isVideo,
            isRAW: isRAW,
            fileSize: size
        )
    }

    private func stat(for day: String, in result: AggregationResult) -> DailyStat? {
        result.stats.first { $0.day == day }
    }

    func testGroupsByLocalDay() {
        let result = DailyAggregator.aggregate(
            [record("2024-12-15"), record("2024-12-15"), record("2024-12-14")],
            photosOnly: false, rawOnly: false, calendar: tokyo
        )
        XCTAssertEqual(result.stats.count, 2)
        XCTAssertEqual(stat(for: "2024-12-15", in: result)?.count, 2)
        XCTAssertEqual(stat(for: "2024-12-14", in: result)?.count, 1)
    }

    func testDailyStatHasStartOfDayDate() {
        let result = DailyAggregator.aggregate(
            [record("2024-12-15")], photosOnly: false, rawOnly: false, calendar: tokyo
        )
        XCTAssertEqual(stat(for: "2024-12-15", in: result)?.date, date("2024-12-15 00:00:00"))
    }

    func testPhotosOnlyExcludesVideos() {
        let result = DailyAggregator.aggregate(
            [record("2024-12-15"), record("2024-12-15", isVideo: true)],
            photosOnly: true, rawOnly: false, calendar: tokyo
        )
        XCTAssertEqual(result.totalCount, 1)
    }

    func testRawOnlyKeepsOnlyRaw() {
        let result = DailyAggregator.aggregate(
            [record("2024-12-15", isRAW: true), record("2024-12-15"), record("2024-12-14")],
            photosOnly: false, rawOnly: true, calendar: tokyo
        )
        XCTAssertEqual(result.totalCount, 1)
        XCTAssertEqual(stat(for: "2024-12-15", in: result)?.count, 1)
        XCTAssertNil(stat(for: "2024-12-14", in: result))
    }

    func testNilDateGroupsAsUnknownWithNilDate() {
        let result = DailyAggregator.aggregate(
            [record(nil)], photosOnly: false, rawOnly: false, calendar: tokyo
        )
        XCTAssertEqual(stat(for: "Unknown", in: result)?.count, 1)
        XCTAssertNil(stat(for: "Unknown", in: result)?.date)
    }

    func testNilSizeCountsAsUnknownAndIsExcludedFromTotals() {
        let result = DailyAggregator.aggregate(
            [record("2024-12-15", size: nil), record("2024-12-15", size: 500)],
            photosOnly: false, rawOnly: false, calendar: tokyo
        )
        XCTAssertEqual(result.unknownSizeCount, 1)
        XCTAssertEqual(result.totalBytes, 500)
        XCTAssertEqual(stat(for: "2024-12-15", in: result)?.totalBytes, 500)
    }

    func testTotals() {
        let result = DailyAggregator.aggregate(
            [record("2024-12-15", size: 100), record("2024-12-14", size: 200)],
            photosOnly: false, rawOnly: false, calendar: tokyo
        )
        XCTAssertEqual(result.totalCount, 2)
        XCTAssertEqual(result.totalBytes, 300)
    }

    private let unsorted = [
        DailyStat(day: "Unknown", date: nil, count: 99, totalBytes: 9_999),
        DailyStat(day: "2024-12-14", date: Date(timeIntervalSince1970: 0), count: 3, totalBytes: 300),
        DailyStat(day: "2024-12-15", date: Date(timeIntervalSince1970: 86_400), count: 1, totalBytes: 500),
    ]

    func testSortByDateDescendingUnknownLast() {
        let sorted = DailyAggregator.sorted(unsorted, by: .date, ascending: false)
        XCTAssertEqual(sorted.map(\.day), ["2024-12-15", "2024-12-14", "Unknown"])
    }

    func testSortByDateAscendingUnknownStillLast() {
        let sorted = DailyAggregator.sorted(unsorted, by: .date, ascending: true)
        XCTAssertEqual(sorted.map(\.day), ["2024-12-14", "2024-12-15", "Unknown"])
    }

    func testSortByCountDescending() {
        let sorted = DailyAggregator.sorted(unsorted, by: .count, ascending: false)
        XCTAssertEqual(sorted.map(\.day), ["2024-12-14", "2024-12-15", "Unknown"])
    }

    func testSortBySizeAscending() {
        let sorted = DailyAggregator.sorted(unsorted, by: .size, ascending: true)
        XCTAssertEqual(sorted.map(\.day), ["2024-12-14", "2024-12-15", "Unknown"])
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

```bash
cd PhotosCountDaily && xcodegen generate && cd ..
xcodebuild -project PhotosCountDaily/PhotosCountDaily.xcodeproj \
  -scheme PhotosCountDaily -destination 'platform=macOS' test
```

Expected: ビルドエラー `cannot find 'DailyAggregator' in scope` で FAIL

- [ ] **Step 3: DailyAggregator を実装**

`PhotosCountDaily/Sources/DailyAggregator.swift`:

```swift
import Foundation

enum StatSortField: String, CaseIterable {
    case date
    case count
    case size
}

enum DailyAggregator {
    static func aggregate(
        _ records: [AssetRecord],
        photosOnly: Bool,
        rawOnly: Bool,
        calendar: Calendar = .current
    ) -> AggregationResult {
        var counts: [String: Int] = [:]
        var bytes: [String: Int64] = [:]
        var dayDates: [String: Date] = [:]
        var unknownSizeCount = 0

        for record in records {
            if photosOnly && record.isVideo { continue }
            if rawOnly && !record.isRAW { continue }

            let day = Formatters.dayString(from: record.creationDate, calendar: calendar)
            counts[day, default: 0] += 1
            if let size = record.fileSize {
                bytes[day, default: 0] += size
            } else {
                unknownSizeCount += 1
            }
            if dayDates[day] == nil, let creationDate = record.creationDate {
                dayDates[day] = calendar.startOfDay(for: creationDate)
            }
        }

        let stats = counts.map { day, count in
            DailyStat(day: day, date: dayDates[day], count: count, totalBytes: bytes[day] ?? 0)
        }
        return AggregationResult(
            stats: stats,
            totalCount: stats.reduce(0) { $0 + $1.count },
            totalBytes: stats.reduce(0) { $0 + $1.totalBytes },
            unknownSizeCount: unknownSizeCount
        )
    }

    /// "Unknown" は昇順・降順にかかわらず常に末尾
    static func sorted(
        _ stats: [DailyStat],
        by field: StatSortField,
        ascending: Bool
    ) -> [DailyStat] {
        let known = stats.filter { $0.day != "Unknown" }
        let unknown = stats.filter { $0.day == "Unknown" }
        let sortedKnown: [DailyStat]
        switch field {
        case .date:
            sortedKnown = known.sorted { ascending ? $0.day < $1.day : $0.day > $1.day }
        case .count:
            sortedKnown = known.sorted { ascending ? $0.count < $1.count : $0.count > $1.count }
        case .size:
            sortedKnown = known.sorted { ascending ? $0.totalBytes < $1.totalBytes : $0.totalBytes > $1.totalBytes }
        }
        return sortedKnown + unknown
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

```bash
cd PhotosCountDaily && xcodegen generate && cd ..
xcodebuild -project PhotosCountDaily/PhotosCountDaily.xcodeproj \
  -scheme PhotosCountDaily -destination 'platform=macOS' test
```

Expected: `TEST SUCCEEDED`（DailyAggregatorTests 11 件を含む全件パス）

- [ ] **Step 5: Commit**

```bash
git add PhotosCountDaily
git commit -m "Add daily aggregation and sorting with tests

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 5: PhotoLibraryService（PhotoKit アクセス層）

**Files:**
- Create: `PhotosCountDaily/Sources/PhotoLibraryService.swift`

**Interfaces:**
- Consumes: `AssetRecord`（Task 3）
- Produces:
  - `PhotoLibraryService.requestAccess() async -> PHAuthorizationStatus`
  - `PhotoLibraryService.loadRecords(progress: @escaping @Sendable (Int, Int) -> Void) async -> [AssetRecord]`（progress は (処理済み件数, 総数)）
  - `PhotoLibraryService.record(from asset: PHAsset) -> AssetRecord`（Task 8 の RAW フィルタでも使用）

**注意:** このタスクはユニットテスト対象外（PhotoKit 依存のため）。ビルドが通ることのみ確認し、動作は Task 6 でエンドツーエンド検証する。

- [ ] **Step 1: PhotoLibraryService を実装**

`PhotosCountDaily/Sources/PhotoLibraryService.swift`:

```swift
import Foundation
import Photos
import UniformTypeIdentifiers

enum PhotoLibraryService {
    static func requestAccess() async -> PHAuthorizationStatus {
        await PHPhotoLibrary.requestAuthorization(for: .readWrite)
    }

    /// ユーザーライブラリの全資産を AssetRecord に変換する。
    /// リソース列挙が資産ごとに DB を叩くため大規模ライブラリでは時間がかかる。
    /// progress は 500 件ごとと最終件で呼ばれる。
    static func loadRecords(
        progress: @escaping @Sendable (Int, Int) -> Void
    ) async -> [AssetRecord] {
        await Task.detached(priority: .userInitiated) {
            let options = PHFetchOptions()
            // 共有アルバム等を除外し、ライブラリビュー相当の資産のみ対象にする
            options.includeAssetSourceTypes = [.typeUserLibrary]
            let fetchResult = PHAsset.fetchAssets(with: options)
            let total = fetchResult.count
            var records: [AssetRecord] = []
            records.reserveCapacity(total)

            fetchResult.enumerateObjects { asset, index, _ in
                records.append(record(from: asset))
                if (index + 1) % 500 == 0 || index == total - 1 {
                    progress(index + 1, total)
                }
            }
            return records
        }.value
    }

    static func record(from asset: PHAsset) -> AssetRecord {
        var isRAW = false
        var totalSize: Int64 = 0
        var sizeKnown = false

        for resource in PHAssetResource.assetResources(for: asset) {
            switch resource.type {
            case .photo, .video, .alternatePhoto:
                if let type = UTType(resource.uniformTypeIdentifier),
                   type.conforms(to: .rawImage) {
                    isRAW = true
                }
                // fileSize は公開 API にないため KVC で取得する（App Store 配布はしない前提）
                if let size = (resource.value(forKey: "fileSize") as? NSNumber)?.int64Value {
                    totalSize += size
                    sizeKnown = true
                }
            default:
                break
            }
        }

        return AssetRecord(
            creationDate: asset.creationDate,
            isVideo: asset.mediaType == .video,
            isRAW: isRAW,
            fileSize: sizeKnown ? totalSize : nil
        )
    }
}
```

**実装メモ:**
- `.photo` / `.video` / `.alternatePhoto`（RAW+JPEG の RAW 側）のみ加算し、編集派生（`.fullSizePhoto` 等）は除外 — CLI 版の「オリジナル + RAW」集計と整合
- RAW 判定は UTI が `public.camera-raw-image`（`UTType.rawImage`）に適合するリソースの有無 — CLI 版の `israw or has_raw` と整合
- hidden 資産は `PHFetchOptions` デフォルト（`includeHiddenAssets = false`）で除外、バーストは代表写真のみ返る

- [ ] **Step 2: ビルドが通ることを確認**

```bash
cd PhotosCountDaily && xcodegen generate && cd ..
xcodebuild -project PhotosCountDaily/PhotosCountDaily.xcodeproj \
  -scheme PhotosCountDaily -destination 'platform=macOS' build
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add PhotosCountDaily
git commit -m "Add PhotoKit access layer converting assets to records

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 6: ViewModel + メイン UI（テーブル・フィルタ・進捗・権限拒否）

**Files:**
- Create: `PhotosCountDaily/Sources/LibraryStatsViewModel.swift`
- Create: `PhotosCountDaily/Sources/Views/StatsTableView.swift`
- Create: `PhotosCountDaily/Sources/Views/AccessDeniedView.swift`
- Modify: `PhotosCountDaily/Sources/Views/ContentView.swift`（プレースホルダを全置換）

**Interfaces:**
- Consumes: `DailyAggregator`, `StatSortField`（Task 4）、`PhotoLibraryService`（Task 5）、`Formatters`, `DailyStat`, `AggregationResult`（Task 3）
- Produces:
  - `@MainActor @Observable final class LibraryStatsViewModel` — プロパティ: `state: LoadState`（`.idle / .denied / .loading(done: Int, total: Int) / .loaded`）、`photosOnly: Bool`、`rawOnly: Bool`、`sortField: StatSortField`、`sortAscending: Bool`、`result: AggregationResult`、`sortedStats: [DailyStat]`、メソッド: `load() async`
  - `ContentView` — `DisplayMode`（`.table / .chart`）切り替え、`selectedDay: DailyStat?` を sheet で `DayDetailView` に渡す（Task 7 の `ChartView`、Task 8 の `DayDetailView` はプレースホルダで先行定義）

- [ ] **Step 1: ViewModel を実装**

`PhotosCountDaily/Sources/LibraryStatsViewModel.swift`:

```swift
import Foundation
import Observation
import Photos

@MainActor
@Observable
final class LibraryStatsViewModel {
    enum LoadState: Equatable {
        case idle
        case denied
        case loading(done: Int, total: Int)
        case loaded
    }

    var state: LoadState = .idle
    var photosOnly = false { didSet { recompute() } }
    var rawOnly = false { didSet { recompute() } }
    var sortField: StatSortField = .count { didSet { resort() } }
    var sortAscending = false { didSet { resort() } }
    private(set) var result: AggregationResult = .empty
    private(set) var sortedStats: [DailyStat] = []

    private var records: [AssetRecord] = []

    func load() async {
        guard state == .idle else { return }
        let status = await PhotoLibraryService.requestAccess()
        guard status == .authorized || status == .limited else {
            state = .denied
            return
        }
        state = .loading(done: 0, total: 0)
        records = await PhotoLibraryService.loadRecords { done, total in
            Task { @MainActor [weak self] in
                self?.state = .loading(done: done, total: total)
            }
        }
        recompute()
        state = .loaded
    }

    private func recompute() {
        result = DailyAggregator.aggregate(records, photosOnly: photosOnly, rawOnly: rawOnly)
        resort()
    }

    private func resort() {
        sortedStats = DailyAggregator.sorted(result.stats, by: sortField, ascending: sortAscending)
    }
}
```

- [ ] **Step 2: AccessDeniedView を実装**

`PhotosCountDaily/Sources/Views/AccessDeniedView.swift`:

```swift
import AppKit
import SwiftUI

struct AccessDeniedView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Photos access is required")
                .font(.headline)
            Text("Grant access in System Settings > Privacy & Security > Photos, then relaunch the app.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Open System Settings") {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos")!
                NSWorkspace.shared.open(url)
            }
        }
        .padding(40)
    }
}
```

- [ ] **Step 3: StatsTableView を実装**

`PhotosCountDaily/Sources/Views/StatsTableView.swift`:

```swift
import SwiftUI

struct StatsTableView: View {
    @Bindable var viewModel: LibraryStatsViewModel
    @Binding var selection: DailyStat.ID?
    @Binding var selectedDay: DailyStat?

    @State private var sortOrder = [KeyPathComparator(\DailyStat.count, order: .reverse)]

    var body: some View {
        Table(viewModel.sortedStats, selection: $selection, sortOrder: $sortOrder) {
            TableColumn("Date", value: \.day)
            TableColumn("Count", value: \.count) { stat in
                Text("\(stat.count)")
            }
            .width(min: 60, ideal: 80)
            TableColumn("Size", value: \.totalBytes) { stat in
                Text(Formatters.sizeString(fromBytes: stat.totalBytes))
            }
            .width(min: 80, ideal: 110)
        }
        .onChange(of: sortOrder) { _, newOrder in
            guard let first = newOrder.first else { return }
            viewModel.sortAscending = first.order == .forward
            switch first.keyPath {
            case \DailyStat.day:
                viewModel.sortField = .date
            case \DailyStat.count:
                viewModel.sortField = .count
            case \DailyStat.totalBytes:
                viewModel.sortField = .size
            default:
                break
            }
        }
        .onChange(of: selection) { _, id in
            // Unknown 行（date == nil）は詳細表示できないので開かない
            selectedDay = viewModel.sortedStats.first { $0.id == id && $0.date != nil }
        }
    }
}
```

**実装メモ:** `Table` の `sortOrder` はソート UI（列ヘッダクリック）のためだけに使い、実際の並び替えは `viewModel.sortedStats`（Unknown 末尾保証つき）に委譲する。

- [ ] **Step 4: ContentView を全置換**

`PhotosCountDaily/Sources/Views/ContentView.swift`（全置換）:

```swift
import SwiftUI

struct ContentView: View {
    @State private var viewModel = LibraryStatsViewModel()
    @State private var display: DisplayMode = .table
    @State private var tableSelection: DailyStat.ID?
    @State private var selectedDay: DailyStat?

    enum DisplayMode: String, CaseIterable {
        case table = "Table"
        case chart = "Chart"
    }

    var body: some View {
        Group {
            switch viewModel.state {
            case .idle:
                ProgressView("Requesting Photos access…")
            case .denied:
                AccessDeniedView()
            case .loading(let done, let total):
                VStack(spacing: 12) {
                    if total > 0 {
                        ProgressView(value: Double(done), total: Double(total))
                            .frame(maxWidth: 300)
                        Text("Scanning \(done) / \(total) items…")
                            .foregroundStyle(.secondary)
                    } else {
                        ProgressView("Loading Photos library…")
                    }
                }
            case .loaded:
                loadedView
            }
        }
        .frame(minWidth: 640, minHeight: 480)
        .task { await viewModel.load() }
    }

    private var loadedView: some View {
        VStack(spacing: 0) {
            switch display {
            case .table:
                StatsTableView(
                    viewModel: viewModel,
                    selection: $tableSelection,
                    selectedDay: $selectedDay
                )
            case .chart:
                ChartView(stats: viewModel.sortedStats)
            }
            Divider()
            summaryBar
        }
        .toolbar {
            ToolbarItemGroup {
                Toggle("Photos only", isOn: $viewModel.photosOnly)
                Toggle("RAW only", isOn: $viewModel.rawOnly)
                Picker("Display", selection: $display) {
                    ForEach(DisplayMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .sheet(item: $selectedDay, onDismiss: { tableSelection = nil }) { day in
            DayDetailView(
                stat: day,
                photosOnly: viewModel.photosOnly,
                rawOnly: viewModel.rawOnly
            )
        }
    }

    private var summaryBar: some View {
        HStack(spacing: 8) {
            Text("Total: \(viewModel.result.totalCount) items, \(Formatters.sizeString(fromBytes: viewModel.result.totalBytes)) across \(viewModel.result.stats.count) days")
            if viewModel.result.unknownSizeCount > 0 {
                Text("(\(viewModel.result.unknownSizeCount) items with unknown size)")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .font(.callout)
        .padding(8)
    }
}
```

- [ ] **Step 5: ChartView / DayDetailView のプレースホルダを作成（Task 7・8 で置き換え）**

`PhotosCountDaily/Sources/Views/ChartView.swift`:

```swift
import SwiftUI

struct ChartView: View {
    var stats: [DailyStat]

    var body: some View {
        Text("Chart coming soon")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

`PhotosCountDaily/Sources/Views/DayDetailView.swift`:

```swift
import SwiftUI

struct DayDetailView: View {
    let stat: DailyStat
    let photosOnly: Bool
    let rawOnly: Bool

    var body: some View {
        Text("\(stat.day) — \(stat.count) items")
            .padding(40)
    }
}
```

- [ ] **Step 6: ビルドとテスト**

```bash
cd PhotosCountDaily && xcodegen generate && cd ..
xcodebuild -project PhotosCountDaily/PhotosCountDaily.xcodeproj \
  -scheme PhotosCountDaily -destination 'platform=macOS' build test
```

Expected: `BUILD SUCCEEDED` / `TEST SUCCEEDED`

- [ ] **Step 7: エンドツーエンド手動検証（ユーザー操作を含む）**

```bash
xcodebuild -project PhotosCountDaily/PhotosCountDaily.xcodeproj \
  -scheme PhotosCountDaily -configuration Debug \
  -derivedDataPath build build
open build/Build/Products/Debug/PhotosCountDaily.app
```

確認項目（ユーザーに依頼）:
1. 初回起動時に Photos アクセス許可ダイアログが出る → 許可
2. 進捗バーが進み、テーブルに日付・枚数・容量が表示される
3. 列ヘッダクリックでソートが切り替わり、Unknown 行（あれば）は常に末尾
4. 「Photos only」「RAW only」トグルで件数が変わる

- [ ] **Step 8: CLI 版との突き合わせ検証**

```bash
cd legacy && uv run python photos_count_daily.py -s date -r -n 10
```

アプリのテーブル（日付降順ソート）の上位と比較し、枚数・容量が一致するか、差異が既知の制限（タイムゾーン・共有写真の扱い）で説明できることを確認する。説明できない大きな差異があれば superpowers:systematic-debugging スキルで原因を調査すること。

- [ ] **Step 9: Commit**

```bash
git add PhotosCountDaily
git commit -m "Add main UI with stats table, filters, and progress

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 7: ChartView（Swift Charts）

**Files:**
- Modify: `PhotosCountDaily/Sources/Views/ChartView.swift`（プレースホルダを全置換）

**Interfaces:**
- Consumes: `DailyStat`（Task 3）、`Formatters.sizeString`（Task 3）
- Produces: `ChartView(stats: [DailyStat])` — Task 6 の `ContentView` から既に呼ばれているシグネチャを維持

- [ ] **Step 1: ChartView を実装（全置換）**

`PhotosCountDaily/Sources/Views/ChartView.swift`:

```swift
import Charts
import SwiftUI

struct ChartView: View {
    var stats: [DailyStat]

    @State private var metric: Metric = .count

    enum Metric: String, CaseIterable {
        case count = "Count"
        case size = "Size"
    }

    /// Unknown（date == nil）はグラフに出せないため除外し、日付昇順で描画する
    private var chartStats: [DailyStat] {
        stats.filter { $0.date != nil }.sorted { $0.day < $1.day }
    }

    var body: some View {
        VStack(spacing: 8) {
            Picker("Metric", selection: $metric) {
                ForEach(Metric.allCases, id: \.self) { metric in
                    Text(metric.rawValue).tag(metric)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 240)
            .padding(.top, 8)

            Chart(chartStats) { stat in
                BarMark(
                    x: .value("Date", stat.date!, unit: .day),
                    y: .value(
                        metric.rawValue,
                        metric == .count ? Double(stat.count) : Double(stat.totalBytes)
                    )
                )
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine()
                    AxisValueLabel {
                        if let raw = value.as(Double.self) {
                            if metric == .size {
                                Text(Formatters.sizeString(fromBytes: Int64(raw)))
                            } else {
                                Text("\(Int(raw))")
                            }
                        }
                    }
                }
            }
            .chartScrollableAxes(.horizontal)
            .chartXVisibleDomain(length: 3600 * 24 * 120)
            .padding()
        }
    }
}
```

**実装メモ:** `chartXVisibleDomain` で約 4 ヶ月分を表示し、それより長い履歴は横スクロール。

- [ ] **Step 2: ビルド確認**

```bash
cd PhotosCountDaily && xcodegen generate && cd ..
xcodebuild -project PhotosCountDaily/PhotosCountDaily.xcodeproj \
  -scheme PhotosCountDaily -destination 'platform=macOS' build
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: 手動検証（ユーザー操作を含む）**

```bash
xcodebuild -project PhotosCountDaily/PhotosCountDaily.xcodeproj \
  -scheme PhotosCountDaily -configuration Debug \
  -derivedDataPath build build
open build/Build/Products/Debug/PhotosCountDaily.app
```

確認項目: ツールバーで Chart に切り替え → 棒グラフが表示され、Count / Size の切り替えと横スクロールが動く。

- [ ] **Step 4: Commit**

```bash
git add PhotosCountDaily
git commit -m "Add daily bar chart with count/size metric toggle

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 8: DayDetailView（日別サムネイル一覧）

**Files:**
- Modify: `PhotosCountDaily/Sources/Views/DayDetailView.swift`（プレースホルダを全置換）

**Interfaces:**
- Consumes: `DailyStat`（Task 3）、`PhotoLibraryService.record(from:)`（Task 5、RAW フィルタ用）
- Produces: `DayDetailView(stat: DailyStat, photosOnly: Bool, rawOnly: Bool)` — Task 6 の `ContentView` から既に呼ばれているシグネチャを維持

- [ ] **Step 1: DayDetailView を実装（全置換）**

`PhotosCountDaily/Sources/Views/DayDetailView.swift`:

```swift
import Photos
import SwiftUI

struct DayDetailView: View {
    let stat: DailyStat
    let photosOnly: Bool
    let rawOnly: Bool

    @Environment(\.dismiss) private var dismiss
    @State private var assets: [PHAsset] = []

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("\(stat.day) — \(stat.count) items")
                    .font(.headline)
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding()
            Divider()
            ScrollView {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 120), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(assets, id: \.localIdentifier) { asset in
                        AssetThumbnailView(asset: asset)
                    }
                }
                .padding()
            }
        }
        .frame(minWidth: 560, minHeight: 420)
        .task {
            assets = Self.fetchAssets(for: stat, photosOnly: photosOnly, rawOnly: rawOnly)
        }
    }

    /// 集計と同じローカルタイムゾーン・同じフィルタ条件でその日の資産を取得する
    static func fetchAssets(for stat: DailyStat, photosOnly: Bool, rawOnly: Bool) -> [PHAsset] {
        guard let dayStart = stat.date else { return [] }
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: dayStart)!

        var predicates = [
            NSPredicate(
                format: "creationDate >= %@ AND creationDate < %@",
                dayStart as NSDate, dayEnd as NSDate
            )
        ]
        if photosOnly {
            predicates.append(
                NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            )
        }

        let options = PHFetchOptions()
        options.includeAssetSourceTypes = [.typeUserLibrary]
        options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let fetchResult = PHAsset.fetchAssets(with: options)
        var result: [PHAsset] = []
        result.reserveCapacity(fetchResult.count)
        fetchResult.enumerateObjects { asset, _, _ in
            result.append(asset)
        }
        if rawOnly {
            result = result.filter { PhotoLibraryService.record(from: $0).isRAW }
        }
        return result
    }
}

struct AssetThumbnailView: View {
    let asset: PHAsset

    @State private var image: NSImage?

    private static let imageManager = PHCachingImageManager()

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Rectangle().fill(.quaternary)
                ProgressView().controlSize(.small)
            }
        }
        .frame(width: 120, height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .task {
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .opportunistic
            Self.imageManager.requestImage(
                for: asset,
                targetSize: CGSize(width: 240, height: 240),
                contentMode: .aspectFill,
                options: options
            ) { result, _ in
                if let result {
                    image = result
                }
            }
        }
    }
}
```

- [ ] **Step 2: ビルド確認**

```bash
cd PhotosCountDaily && xcodegen generate && cd ..
xcodebuild -project PhotosCountDaily/PhotosCountDaily.xcodeproj \
  -scheme PhotosCountDaily -destination 'platform=macOS' build
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: 手動検証（ユーザー操作を含む）**

```bash
xcodebuild -project PhotosCountDaily/PhotosCountDaily.xcodeproj \
  -scheme PhotosCountDaily -configuration Debug \
  -derivedDataPath build build
open build/Build/Products/Debug/PhotosCountDaily.app
```

確認項目:
1. テーブルの行をクリック → シートが開きサムネイルが並ぶ（枚数がテーブルの Count と一致）
2. シートを閉じて同じ行を再クリック → 再びシートが開く
3. フィルタ ON の状態で行を開くと、フィルタ適用後の枚数と一致

- [ ] **Step 4: Commit**

```bash
git add PhotosCountDaily
git commit -m "Add per-day thumbnail grid detail view

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 9: dmg ビルドスクリプト + GitHub Actions リリース

**Files:**
- Create: `scripts/make_dmg.sh`
- Create: `.github/workflows/release.yml`

**Interfaces:**
- Consumes: Task 2 のプロジェクト構成（`PhotosCountDaily/project.yml`、scheme 名 `PhotosCountDaily`）
- Produces: `./scripts/make_dmg.sh <version>` → リポジトリルートに `PhotosCountDaily-<version>.dmg`。タグ `v*` の push で GitHub Release に dmg が添付される。

- [ ] **Step 1: dmg 作成スクリプトを書く**

`scripts/make_dmg.sh`:

```bash
#!/bin/bash
# Release ビルドを ad-hoc 署名して dmg にまとめる。
# 使い方: ./scripts/make_dmg.sh [version]  (省略時 "dev")
set -euo pipefail

cd "$(dirname "$0")/.."

VERSION="${1:-dev}"
BUILD_DIR="build"
APP="$BUILD_DIR/Build/Products/Release/PhotosCountDaily.app"
DMG="PhotosCountDaily-$VERSION.dmg"

xcodegen generate --spec PhotosCountDaily/project.yml --project PhotosCountDaily

xcodebuild -project PhotosCountDaily/PhotosCountDaily.xcodeproj \
  -scheme PhotosCountDaily -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY=- build

codesign --force --deep --sign - "$APP"

STAGING="$BUILD_DIR/dmg"
rm -rf "$STAGING" "$DMG"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create -volname "PhotosCountDaily" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
echo "Created $DMG"
```

```bash
chmod +x scripts/make_dmg.sh
```

- [ ] **Step 2: スクリプトをローカルで実行して確認**

Run: `./scripts/make_dmg.sh dev`
Expected: 最後に `Created PhotosCountDaily-dev.dmg` が出力され、`hdiutil attach PhotosCountDaily-dev.dmg` でマウントすると `PhotosCountDaily.app` と `Applications` シンボリックリンクが見える（確認後 `hdiutil detach` でアンマウント、dmg は .gitignore 済み）

- [ ] **Step 3: GitHub Actions workflow を書く**

`.github/workflows/release.yml`:

```yaml
name: Release

on:
  push:
    tags: ["v*"]

permissions:
  contents: write

jobs:
  release:
    runs-on: macos-15
    steps:
      - uses: actions/checkout@v4

      - name: Install XcodeGen
        run: brew install xcodegen

      - name: Build dmg
        run: ./scripts/make_dmg.sh "${GITHUB_REF_NAME}"

      - name: Create GitHub Release
        uses: softprops/action-gh-release@v2
        with:
          files: PhotosCountDaily-*.dmg
          generate_release_notes: true
```

- [ ] **Step 4: workflow の構文チェック**

Run: `actionlint .github/workflows/release.yml 2>/dev/null || echo "actionlint not installed — skipping (visual review only)"`
Expected: エラーなし（actionlint 未導入ならスキップし、YAML を目視確認）

- [ ] **Step 5: Commit**

```bash
git add scripts/make_dmg.sh .github/workflows/release.yml
git commit -m "Add dmg build script and release workflow

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

**リリース手順（実装後の運用、README にも記載）:** `git tag v0.1.0 && git push origin v0.1.0` → Actions が dmg を Release に添付。

---

### Task 10: ドキュメント更新（README / README_ja / CLAUDE.md）

**Files:**
- Create: `README.md`（アプリ中心の英語版）
- Create: `README_ja.md`（日本語版）
- Modify: `CLAUDE.md`（全置換）
- Modify: `legacy/README.md`（冒頭にレガシー注記を追加）

**Interfaces:**
- Consumes: これまでの全タスクの成果（機能・制限・ビルド手順・リリース手順）

- [ ] **Step 1: 新しい README.md を書く**

`README.md`（新規作成、内容は以下の構成で書く。**既知の制限セクションは spec の「CLI 版との仕様差」を必ず全項目含めること**）:

```markdown
# PhotosCountDaily

A native macOS app that counts photos in your Photos library per day,
showing counts and total file sizes in a sortable table, a bar chart,
and per-day thumbnail browsing.

Built with SwiftUI + PhotoKit. Requires macOS 14 or later.

## Features

- Per-day photo count and total original file size (decimal units, same as Finder)
- Sortable table (date / count / size), filters (photos only / RAW only)
- Bar chart with count/size metric toggle (Swift Charts)
- Click a day to browse its photos as thumbnails

## Installation

Download the latest dmg from [Releases](../../releases), open it, and drag
PhotosCountDaily.app to Applications.

**Note:** The app is not notarized. On first launch, right-click the app and
choose "Open", or run:

    xattr -dr com.apple.quarantine /Applications/PhotosCountDaily.app

## Building from source

    brew install xcodegen
    cd PhotosCountDaily && xcodegen generate
    xcodebuild -project PhotosCountDaily.xcodeproj -scheme PhotosCountDaily build

Or open the generated `PhotosCountDaily.xcodeproj` in Xcode.

## Known limitations

- Only the system Photos library is supported (PhotoKit restriction).
  The legacy CLI supports custom libraries via `--library`.
- Grouping uses the photo's capture date (`creationDate`) in the Mac's
  local time zone. Per-photo capture time zones are not available via
  PhotoKit, so photos taken while traveling may fall on a neighboring day
  compared to Photos.app / the legacy CLI.
- Items whose original file size is unknown (e.g. originals not yet
  downloaded from iCloud) are counted but excluded from size totals; the
  status bar shows how many.

## Legacy Python CLI

The original command-line version lives in [legacy/](legacy/) and remains
functional. See [legacy/README.md](legacy/README.md).

## Releasing

    git tag v0.1.0 && git push origin v0.1.0

GitHub Actions builds the dmg and attaches it to the release.
```

- [ ] **Step 2: README_ja.md を書く**

`README_ja.md`: Step 1 の README.md と同内容の日本語版を書く（構成・項目は完全に対応させる。翻訳のみで情報の増減をしない）。

- [ ] **Step 3: legacy/README.md に注記を追加**

`legacy/README.md` の先頭（タイトル直後）に追記:

```markdown
> **Note:** This is the legacy Python CLI. The repository now ships a native
> macOS app — see the [top-level README](../README.md). The CLI still works
> as documented below.
```

- [ ] **Step 4: CLAUDE.md を全置換**

`CLAUDE.md`（全置換）:

```markdown
# photos_count_daily

macOS Photos ライブラリの日別写真枚数・容量を表示するネイティブ macOS アプリ
(SwiftUI + PhotoKit)。旧 Python CLI は `legacy/` にある。

## リポジトリ構成

- `PhotosCountDaily/` — SwiftUI アプリ本体（XcodeGen 管理）
  - `project.yml` — XcodeGen 設定。`.xcodeproj` は git 管理外で毎回生成する
  - `Sources/` — Swift ソース
  - `Tests/` — XCTest（ロジックのみ。PhotoKit に触れるテストは書かない）
- `legacy/` — 旧 Python CLI（osxphotos ベース、`uv` で実行）。詳細は `legacy/README.md`
- `scripts/make_dmg.sh` — Release ビルド + ad-hoc 署名 + dmg 作成
- `.github/workflows/release.yml` — タグ `v*` push で dmg を GitHub Release に添付

## ビルド・テスト

```bash
cd PhotosCountDaily && xcodegen generate && cd ..
xcodebuild -project PhotosCountDaily/PhotosCountDaily.xcodeproj \
  -scheme PhotosCountDaily -destination 'platform=macOS' build test
```

実行: `open build/Build/Products/Debug/PhotosCountDaily.app`
（`-derivedDataPath build` でビルドした場合）

## アーキテクチャ

- `Models.swift` — `AssetRecord`（PhotoKit 資産の純粋データ表現）、`DailyStat`、`AggregationResult`
- `PhotoLibraryService.swift` — PhotoKit アクセス層。`PHAsset` → `AssetRecord` 変換。
  ファイルサイズは `PHAssetResource` の `fileSize`（KVC、非公開キー）から取得。
  RAW 判定はリソース UTI が `public.camera-raw-image` に適合するか
- `DailyAggregator.swift` — 集計・ソートの純粋関数。ユニットテストの主対象
- `LibraryStatsViewModel.swift` — `@Observable`。読み込み状態・フィルタ・ソート
- `Views/` — `ContentView`（切り替え・ツールバー）、`StatsTableView`、`ChartView`、
  `DayDetailView`（サムネイル）、`AccessDeniedView`

## 実装上のポイント

- テストターゲットは TEST_HOST なし（アプリ起動で TCC ダイアログが出るのを避ける）。
  ロジックファイルを直接テストターゲットのソースに含めている（`project.yml` 参照)
- 集計対象は `includeAssetSourceTypes = [.typeUserLibrary]` でライブラリビュー相当に限定。
  hidden・共有アルバム・未保存の「あなたと共有」は PhotoKit 側で除外される
- サイズは `.photo` / `.video` / `.alternatePhoto`（RAW+JPEG の RAW 側）リソースの合計。
  編集派生ファイルは含めない。サイズ不明（iCloud 未ダウンロード等）は件数を集計して UI に注記
- 日付グループ化はローカルタイムゾーン。写真ごとの撮影タイムゾーンは PhotoKit では取得不可
  （旧 CLI との既知の差分。README の Known limitations 参照）
- 日付不明は `"Unknown"`、ソート時は常に末尾
- 容量表示は 10 進単位（KB=1000B、Finder と同じ）。`Formatters.sizeString` を使う

## リリース

`git tag vX.Y.Z && git push origin vX.Y.Z` → GitHub Actions が
ad-hoc 署名の dmg を Release に添付（無署名配布。README に Gatekeeper 回避手順あり）。
Developer ID 署名 + notarization へ移行する場合は workflow に署名ステップを追加する。
```

- [ ] **Step 5: 目視確認とリンクチェック**

README.md / README_ja.md / CLAUDE.md / legacy/README.md を通読し、パス（`legacy/`、`PhotosCountDaily/`、`scripts/make_dmg.sh`）が実在することを確認:

Run: `ls legacy/README.md PhotosCountDaily/project.yml scripts/make_dmg.sh .github/workflows/release.yml`
Expected: 4 ファイルすべて表示される

- [ ] **Step 6: Commit**

```bash
git add README.md README_ja.md CLAUDE.md legacy/README.md
git commit -m "Rewrite docs for the SwiftUI app, mark CLI as legacy

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

## 完了条件

- 全タスクのテスト・ビルドが通っている（`xcodebuild test` 全件パス）
- アプリが実ライブラリで動作し、CLI 版との突き合わせで差異が既知の制限のみ（Task 6 Step 8）
- `./scripts/make_dmg.sh dev` で dmg が作れる
- ドキュメントが新構成を反映している
