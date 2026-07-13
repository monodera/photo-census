# PhotoCensus

A native macOS app that counts photos in your Photos library per day,
showing counts and total file sizes in a sortable table, a bar chart,
and per-day thumbnail browsing.

Built with SwiftUI + PhotoKit. Requires macOS 14 or later.

[日本語版 README はこちら](README_ja.md)

## Features

- Per-day photo count and total original file size (decimal units, same as Finder)
- Sortable table (date / count / size) with a filter dropdown: All / Photos only / RAW only
- Bar chart (Swift Charts) with a Count/Size metric switcher, horizontal scrolling
  over the full date range, a pinned y-axis that rescales to the visible dates,
  and a hover tooltip showing the date, count, and size
- Click a table row or a chart bar to browse that day's photos as thumbnails
- Table/Chart and Count/Size are switched with a custom animated sliding control

## Installation

Download the latest dmg from [Releases](../../releases), open it, and drag
PhotoCensus.app to Applications.

**Note:** The app is not notarized. On first launch, right-click the app and
choose "Open", or run:

    xattr -dr com.apple.quarantine /Applications/PhotoCensus.app

## Building from source

    brew install xcodegen
    cd PhotoCensus && xcodegen generate
    xcodebuild -project PhotoCensus.xcodeproj -scheme PhotoCensus build

Or open the generated `PhotoCensus.xcodeproj` in Xcode.

The app icon is generated from an SVG source via `assets/icon/gen_icon.py`
(see `assets/icon/`).

## Known limitations

- Only the system Photos library is supported (PhotoKit restriction).
  The legacy CLI supports custom libraries via `--library`.
- The date field used for grouping is fixed to the photo's capture date
  (`creationDate`). The legacy CLI's `--date-field` (choosing between
  capture date, original EXIF date, and date added) has no PhotoKit
  equivalent.
- Grouping uses the photo's capture date in the Mac's local time zone.
  Per-photo capture time zones are not available via PhotoKit, so photos
  taken while traveling may fall on a neighboring day compared to
  Photos.app / the legacy CLI.
- The legacy CLI's debugging options (`--debug`, `--debug-date`,
  `--diagnose-tz`) have no equivalent in the app.
- Items whose original file size is unknown (e.g. originals not yet
  downloaded from iCloud) are counted but excluded from size totals; the
  status bar shows how many.
- Counts are a snapshot taken at app launch. Photos added or deleted in
  Photos.app while PhotoCensus is running are not reflected until you
  relaunch the app. The day-detail thumbnail sheet fetches live from the
  library, so in that case its grid can differ from the table's count.

## Legacy Python CLI

The original command-line version lives in [legacy/](legacy/) and remains
functional. See [legacy/README.md](legacy/README.md).

## Releasing

    git tag v0.1.0 && git push origin v0.1.0

GitHub Actions builds the dmg and attaches it to the release.
