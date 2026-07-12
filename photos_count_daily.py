#!/usr/bin/env python3
# /// script
# requires-python = ">=3.12"
# dependencies = [
#   "osxphotos>=0.75.5",
# ]
# ///
"""
macOS Photos library photo counter by date.
Count photos grouped by date and display sorted results.
"""

import argparse
from collections import Counter
import os
import sys

try:
    import osxphotos
except ImportError:
    print("Error: osxphotos is not installed.", file=sys.stderr)
    print("Install it with: uv add osxphotos", file=sys.stderr)
    sys.exit(1)


def format_date(dt):
    """Format datetime to YYYY-MM-DD string."""
    if dt is None:
        return "Unknown"
    # Use the date as-is without timezone conversion
    # This matches Photos.app behavior which uses the original timezone
    return dt.strftime("%Y-%m-%d")


def format_size(num_bytes):
    """Format bytes as human-readable string (decimal units, matching Finder)."""
    if num_bytes < 1000:
        return f"{num_bytes} B"
    size = num_bytes
    for unit in ("KB", "MB", "GB"):
        size /= 1000
        # 999.95+ would render as "1000.0", so roll over to the next unit
        if round(size, 1) < 1000:
            return f"{size:.1f} {unit}"
    return f"{size / 1000:.1f} TB"


def count_photos_by_date(library_path=None, raw_only=False, debug=False, debug_date=None, photos_only=False, date_field="date", diagnose_tz=False):
    """
    Count photos by date from macOS Photos library.

    Args:
        library_path: Path to Photos library. If None, uses system default.
        raw_only: If True, count only RAW images.
        debug: If True, print debug information for first few photos.
        debug_date: If specified, print all photos for this date (YYYY-MM-DD).
        photos_only: If True, exclude videos (movies).
        date_field: Photo property to use for date grouping ("date", "date_original", "date_added").
        diagnose_tz: If True, report photos with missing timezone data that may be on wrong date.

    Returns:
        Tuple of two Counter objects keyed by date string:
        (photo counts, total original file sizes in bytes).
    """
    print("Loading Photos library...", file=sys.stderr)

    if library_path:
        photosdb = osxphotos.PhotosDB(dbfile=library_path)
    else:
        photosdb = osxphotos.PhotosDB()

    # Get photos, optionally excluding movies
    if photos_only:
        all_photos = photosdb.photos(movies=False)
    else:
        all_photos = photosdb.photos()

    # Exclude photos not shown in Photos.app library view:
    # - hidden photos
    # - shared iCloud album photos (in DB but not in library)
    # - syndicated ("Shared with You") photos not saved to library
    all_photos = [
        p for p in all_photos
        if not p.hidden
        and not p.shared
        and not (p.syndicated and not p.saved_to_library)
    ]
    print(f"Found {len(all_photos)} photos", file=sys.stderr)

    date_counter = Counter()
    size_counter = Counter()
    filtered_count = 0
    missing_raw_count = 0

    for photo in all_photos:
        # Filter for RAW images if requested
        if raw_only and not (photo.israw or photo.has_raw):
            continue

        filtered_count += 1

        # Debug: print first 5 photos' date information
        if debug and filtered_count <= 5:
            print(f"\nDebug Photo {filtered_count}: {photo.original_filename}", file=sys.stderr)
            print(f"  date: {photo.date}", file=sys.stderr)
            print(f"  date.tzinfo: {photo.date.tzinfo if photo.date else 'N/A'}", file=sys.stderr)
            print(f"  tzoffset (sec): {photo.tzoffset}", file=sys.stderr)
            print(f"  tzname: {photo.tzname}", file=sys.stderr)
            date_orig_is_fallback = not (photo.exif_info and photo.exif_info.date)
            print(f"  date_original: {photo.date_original} {'[fallback to date]' if date_orig_is_fallback else ''}", file=sys.stderr)
            print(f"  date_modified: {photo.date_modified}", file=sys.stderr)
            print(f"  date_added: {photo.date_added}", file=sys.stderr)
            print(f"  burst: {photo.burst}, ismovie: {photo.ismovie}", file=sys.stderr)

        # Use the specified date field for grouping
        date_str = format_date(getattr(photo, date_field))

        # Debug specific date: print all photos for that date
        if debug_date and date_str == debug_date:
            print(f"\n[{date_str}] {photo.original_filename}", file=sys.stderr)
            print(f"  UUID: {photo.uuid}", file=sys.stderr)
            print(f"  date: {photo.date}", file=sys.stderr)
            print(f"  date.tzinfo: {photo.date.tzinfo if photo.date else 'N/A'}", file=sys.stderr)
            print(f"  tzoffset (sec): {photo.tzoffset}", file=sys.stderr)
            print(f"  tzname: {photo.tzname}", file=sys.stderr)
            date_orig_is_fallback = not (photo.exif_info and photo.exif_info.date)
            print(f"  date_original: {photo.date_original} {'[fallback to date]' if date_orig_is_fallback else ''}", file=sys.stderr)
            print(f"  date_modified: {photo.date_modified}", file=sys.stderr)
            print(f"  date_added: {photo.date_added}", file=sys.stderr)
            print(f"  exif date: {photo.exif_info.date if photo.exif_info else 'none'}", file=sys.stderr)
            print(f"  iscloudasset: {photo.iscloudasset}", file=sys.stderr)
            print(f"  incloud: {photo.incloud}", file=sys.stderr)
            print(f"  burst: {photo.burst}, burst_key: {photo.burst_key if photo.burst else 'N/A'}", file=sys.stderr)
            print(f"  isphoto: {photo.isphoto}, ismovie: {photo.ismovie}", file=sys.stderr)

        date_counter[date_str] += 1
        size_counter[date_str] += photo.original_filesize or 0

        # Include the RAW component of RAW+JPEG pairs; its size is not in the
        # DB metadata, so read it from the local file (unavailable if the RAW
        # is not downloaded from iCloud)
        if photo.has_raw:
            try:
                size_counter[date_str] += os.path.getsize(photo.path_raw)
            except (TypeError, OSError):
                missing_raw_count += 1

        # Timezone diagnosis
        if diagnose_tz and photo.date is not None:
            # Photos with no timezone info are treated as UTC — risk of wrong-day assignment
            if photo.tzoffset == 0 and photo.tzname is None:
                local_dt = photo.date.astimezone()
                local_date = local_dt.strftime("%Y-%m-%d")
                if local_date != date_str:
                    print(
                        f"[diagnose-tz] DATE MISMATCH  UUID={photo.uuid}  "
                        f"counted={date_str}  local={local_date}  "
                        f"file={photo.original_filename}",
                        file=sys.stderr,
                    )
                else:
                    print(
                        f"[diagnose-tz] no-tz (UTC)    UUID={photo.uuid}  "
                        f"date={date_str}  (same in local tz)  "
                        f"file={photo.original_filename}",
                        file=sys.stderr,
                    )

    if raw_only:
        print(f"Filtered to {filtered_count} RAW images", file=sys.stderr)

    if missing_raw_count:
        print(
            f"Warning: {missing_raw_count} RAW files not available locally; "
            "their sizes are not included in the totals",
            file=sys.stderr,
        )

    return date_counter, size_counter


def main():
    parser = argparse.ArgumentParser(
        description="Count photos by date from macOS Photos library"
    )
    parser.add_argument(
        "-s", "--sort",
        choices=["count", "date", "size"],
        default="count",
        help="Sort by count (default), date, or total file size"
    )
    parser.add_argument(
        "-r", "--reverse",
        action="store_true",
        help="Reverse sort order"
    )
    parser.add_argument(
        "-n", "--top",
        type=int,
        metavar="N",
        help="Show only top N results"
    )
    parser.add_argument(
        "--library",
        metavar="PATH",
        help="Path to Photos library (default: system default)"
    )
    parser.add_argument(
        "--raw-only",
        action="store_true",
        help="Count only RAW images"
    )
    parser.add_argument(
        "--photos-only",
        action="store_true",
        help="Exclude videos (count photos only)"
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Print debug information for first few photos"
    )
    parser.add_argument(
        "--debug-date",
        metavar="YYYY-MM-DD",
        help="Print all photos for specific date (for debugging)"
    )
    parser.add_argument(
        "--date-field",
        choices=["date", "date_original", "date_added"],
        default="date",
        help="Date field to use for grouping: date (default, matches Photos.app), "
             "date_original (original EXIF date before any edits), "
             "date_added (import date)"
    )
    parser.add_argument(
        "--diagnose-tz",
        action="store_true",
        help="Report photos with missing timezone data that may be counted on the wrong date"
    )

    args = parser.parse_args()

    try:
        date_counter, size_counter = count_photos_by_date(args.library, args.raw_only, args.debug, args.debug_date, args.photos_only, args.date_field, args.diagnose_tz)
    except Exception as e:
        print(f"Error loading Photos library: {e}", file=sys.stderr)
        sys.exit(1)

    # Combine into (date, count, size) items
    items = [(d, c, size_counter[d]) for d, c in date_counter.items()]

    # Sort results
    if args.sort == "count":
        # Sort by count (descending by default)
        sorted_items = sorted(items, key=lambda x: x[1], reverse=not args.reverse)
    elif args.sort == "size":
        # Sort by total file size (descending by default)
        sorted_items = sorted(items, key=lambda x: x[2], reverse=not args.reverse)
    else:
        # Sort by date (descending by default - newest first)
        # Put "Unknown" dates always at the end regardless of sort direction
        known_items = [it for it in items if it[0] != "Unknown"]
        unknown_items = [it for it in items if it[0] == "Unknown"]
        known_sorted = sorted(known_items, key=lambda x: x[0], reverse=not args.reverse)
        sorted_items = known_sorted + unknown_items

    # Limit results if requested
    if args.top:
        sorted_items = sorted_items[:args.top]

    # Print results
    print("\n{:<12} {:>6} {:>10}".format("Date", "Count", "Size"))
    print("-" * 30)

    for date_str, count, size in sorted_items:
        print(f"{date_str:<12} {count:>6} {format_size(size):>10}")

    print("-" * 30)
    total_photos = sum(date_counter.values())
    total_size = sum(size_counter.values())
    total_days = len(date_counter)
    print(f"Total: {total_photos} photos, {format_size(total_size)} across {total_days} days")


if __name__ == "__main__":
    main()
