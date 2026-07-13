# photos-count-daily

> **注:** これはレガシーの Python CLI 版です。現在このリポジトリはネイティブ macOS アプリ **PhotoCensus** を提供しています — [トップレベルの README](../README_ja.md) を参照してください。CLI は以下のとおり引き続き動作します。

macOS の Photos ライブラリを読み込み、日付ごとに写真枚数をカウントして表示するスクリプト。

## 必要環境

- macOS
- [uv](https://docs.astral.sh/uv/)

## 実行方法

`uv` がインストールされていれば、`uv sync` 不要でそのまま実行できます。

```bash
git clone https://github.com/monodera/photo-census.git
cd photo-census/legacy
uv run photos_count_daily.py
```

## オプション

| オプション | 説明 |
| --------- | ---- |
| `-s {count,date,size}` | カウント順（デフォルト）、日付順、または合計容量順でソート |
| `-r` | ソート順を逆にする |
| `-n N` | 上位 N 件のみ表示 |
| `--library PATH` | カスタム Photos ライブラリのパスを指定（省略時はシステムデフォルト） |
| `--raw-only` | RAW 画像のみをカウント（RAW 単体および RAW+JPEG ペア） |
| `--photos-only` | 動画を除外して写真のみをカウント |
| `--date-field {date,date_original,date_added}` | グループ化に使う日付フィールド（デフォルト: `date`） |

`--date-field` の各値：

- `date` — Photos.app が表示する撮影日（ユーザーによる日付編集が反映される）
- `date_original` — インポート時の EXIF 撮影日（ユーザー編集前の元の日付）
- `date_added` — Photos ライブラリへの追加日（インポート日）

## 実行例

```bash
# 枚数の多い日付順にトップ10を表示
uv run photos_count_daily.py -n 10

# 日付の新しい順に表示
uv run photos_count_daily.py -s date -r

# 容量の大きい日付順にトップ10を表示
uv run photos_count_daily.py -s size -n 10

# RAW 画像のみを集計してカスタムライブラリから読み込む
uv run photos_count_daily.py --raw-only --library /path/to/Photos.photoslibrary

# EXIF 元日付でグループ化（Photos.app で撮影日を編集した写真がある場合）
uv run photos_count_daily.py --date-field date_original
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
- ステータスメッセージは **stderr** に出力

## カウント対象

Photos.app のライブラリビューに表示される写真を数えることを目標にしており、以下はカウントから除外されます。

- 非表示（hidden）にした写真
- 共有アルバム（iCloud 共有アルバム）の写真
- 「あなたと共有」に届いたままライブラリに保存していない写真

## 既知の制限

- **バースト写真**: Photos.app でレビュー済みのキー写真とユーザー選択写真のみカウント。未レビューバーストの自動選択写真は含まれない
- **容量**: オリジナルファイル（RAW+JPEG ペアの場合は RAW 分も）のサイズの合計。RAW 分は iCloud から未ダウンロードの場合は含められない（stderr に警告を表示）。編集後の派生ファイルは含まれない
- **iCloud 同期中**: Photos ライブラリの同期中は実行タイミングによりカウントが一時的にずれる場合がある
