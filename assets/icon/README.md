# PhotoCensus icon

- `gen_icon.py` — generates `photocensus-icon.svg` (deterministic; edit and re-run)
- `icon-design-philosophy.md` — the design philosophy behind the icon

## Regenerating AppIcon.icns

macOS only (uses `rsvg-convert` + iconutil; `brew install librsvg` if missing).

`rsvg-convert` is required over `qlmanage -t` because QuickLook's thumbnailer
mattes SVG transparency to opaque white — the squircle's corners come out as
solid white pixels instead of alpha 0. macOS then detects the icon as a
non-conforming flat square and auto-wraps it in its own white squircle
backing plate (visible as a white border/plate around the whole icon in the
Dock). `rsvg-convert` preserves true alpha in the corners, so no OS-level
auto-masking kicks in.

```bash
python3 gen_icon.py
rm -rf AppIcon.iconset && mkdir AppIcon.iconset
while read -r size name; do
  rsvg-convert -w "$size" -h "$size" photocensus-icon.svg -o "AppIcon.iconset/$name.png"
done <<'EOF'
16 icon_16x16
32 icon_16x16@2x
32 icon_32x32
64 icon_32x32@2x
128 icon_128x128
256 icon_128x128@2x
256 icon_256x256
512 icon_256x256@2x
512 icon_512x512
1024 icon_512x512@2x
EOF
iconutil -c icns AppIcon.iconset -o AppIcon.icns
cp AppIcon.icns ../../PhotoCensus/Sources/AppIcon.icns
rm -rf AppIcon.iconset AppIcon.icns
```
