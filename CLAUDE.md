# photos_count_daily

macOS の Photos ライブラリを読み込み、日付ごとに写真枚数をカウントして表示するスクリプト。

## 実行方法

Python の実行には `uv` を使う。

```bash
# 依存関係のインストール
uv sync

# スクリプトの実行
uv run python photos_count_daily.py [オプション]
```

## コマンドラインオプション

| オプション | 説明 |
| --------- | ---- |
| `-s {count\|date\|size}` | カウント順（デフォルト）、日付順、または合計容量順でソート |
| `-r` | ソート順を逆にする |
| `-n N` | 上位 N 件のみ表示 |
| `--library PATH` | カスタム Photos ライブラリのパスを指定（省略時はシステムデフォルト） |
| `--raw-only` | RAW 画像のみをカウント（RAW 単体および RAW+JPEG ペア） |
| `--photos-only` | 動画を除外して写真のみをカウント |
| `--debug` | 最初の5枚の写真のデバッグ情報を表示 |
| `--debug-date YYYY-MM-DD` | 指定日付の全写真を表示（デバッグ用） |
| `--diagnose-tz` | タイムゾーン情報のない写真（日付ズレの可能性あり）を報告（診断用） |
| `--date-field {date\|date_original\|date_added}` | グループ化に使う日付フィールド（デフォルト: `date`） |

`--date-field` の各値：

- `date` — Photos.app が表示する撮影日（ユーザーによる日付編集が反映される）
- `date_original` — インポート時の EXIF 撮影日（ユーザー編集前の元の日付）
- `date_added` — Photos ライブラリへの追加日（インポート日）

### 実行例

```bash
# 枚数の多い日付順にトップ10を表示
uv run python photos_count_daily.py -n 10

# 日付の新しい順に表示
uv run python photos_count_daily.py -s date -r

# RAW 画像のみを集計してカスタムライブラリから読み込む
uv run python photos_count_daily.py --raw-only --library /path/to/Photos.photoslibrary

# EXIF 元日付でグループ化（Photos.app で撮影日を編集した写真がある場合）
uv run python photos_count_daily.py --date-field date_original
```

## 出力形式

```text
Date          Count       Size
------------------------------
2024-12-15       45     2.1 GB
2024-12-14       32   980.5 MB
...
------------------------------
Total: XXXX photos, ZZZ GB across YYY days
```

- 結果（テーブル）は **stdout** に出力（パイプ処理に対応）
- ステータス・デバッグメッセージは **stderr** に出力

## 実装上のポイント

- **バースト写真**: `photos()` は BURST_KEY（キー写真）、BURST_SELECTED（ユーザー選択）、および burstPickType が BURST_PICK_TYPE_NONE の写真を返す。未レビューバーストの自動選択写真（BURST_DEFAULT_PICK）は osxphotos の公開 API では取得できないため既知の制限として残る
- **ライブラリビュー非表示の写真の除外**: Photos の DB にはライブラリビューに表示されない写真も含まれるため、以下を除外する
  - hidden 写真
  - 共有アルバム（iCloud shared album）の写真（`shared`）
  - 「あなたと共有」でライブラリ未保存の写真（`syndicated` かつ `saved_to_library` でない）
- **RAW 判定**: `--raw-only` は `israw`（RAW 単体）または `has_raw`（RAW+JPEG ペア）で判定する。`has_raw` だけでは RAW 単体ファイルが漏れるので注意
- **日付フィールド**: `--date-field` オプションで `date`（デフォルト）/ `date_original` / `date_added` を選択可能
- **日付不明**: `None` の場合は `"Unknown"` として集計し、ソート時は末尾に表示
- **容量**: `original_filesize`（オリジナルファイルのサイズ）を日付ごとに合計。DB のメタデータ由来なので iCloud 未ダウンロードでも取得できる。RAW+JPEG ペアの RAW 分は DB に記録がないため `path_raw` のファイル実体から加算する（未ダウンロードの場合は加算できず、件数を stderr に警告）。編集後の派生ファイルは含まない。表示は 10進単位（KB=1000B、Finder と同じ）

## 開発環境

- Python 3.12+
- パッケージマネージャー: `uv`
- 主要依存ライブラリ: `osxphotos>=0.75.5`
