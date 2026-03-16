# photos-count-daily

A script that reads a macOS Photos library and counts the number of photos per day.

[日本語版 README はこちら](README_ja.md)

## Requirements

- macOS
- [uv](https://docs.astral.sh/uv/)

## Usage

If `uv` is installed, you can run the script directly without `uv sync`:

```bash
git clone https://github.com/monodera/photos-by-date.git
cd photos-by-date
uv run photos_count_daily.py
```

## Options

| Option | Description |
| ------ | ----------- |
| `-s {count,date}` | Sort by count (default) or by date |
| `-r` | Reverse the sort order |
| `-n N` | Show only the top N results |
| `--library PATH` | Path to a custom Photos library (default: system default) |
| `--raw-only` | Count only RAW images |
| `--photos-only` | Exclude videos and count photos only |
| `--date-field {date,date_original,date_added}` | Date field to use for grouping (default: `date`) |

Values for `--date-field`:

- `date` — The date as displayed in Photos.app (reflects any user edits to the date)
- `date_original` — The original EXIF date at import time (before any user edits)
- `date_added` — The date the photo was added to the Photos library (import date)

## Examples

```bash
# Show the top 10 dates with the most photos
uv run photos_count_daily.py -n 10

# Show results sorted by date, newest first
uv run photos_count_daily.py -s date -r

# Count only RAW images from a custom library
uv run photos_count_daily.py --raw-only --library /path/to/Photos.photoslibrary

# Group by the original EXIF date (useful if you have edited dates in Photos.app)
uv run photos_count_daily.py --date-field date_original
```

## Output Format

```text
Date           Count
--------------------
2024-12-15        45
2024-12-14        32
...
--------------------
Total: XXXX photos across YYY days
```

- Results (table) are printed to **stdout** (pipe-friendly)
- Status messages are printed to **stderr**

## Known Limitations

- **Burst photos**: Only key photos and user-selected photos from reviewed bursts are counted. Auto-selected photos from unreviewed bursts are not included.
- **iCloud sync in progress**: Photo counts may be temporarily inaccurate depending on the timing of script execution while the library is syncing.
