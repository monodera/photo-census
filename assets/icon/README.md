# PhotoCensus icon

- `gen_icon.py` — generates `photocensus-icon.svg` (deterministic; edit and re-run)
- `icon-design-philosophy.md` — the design philosophy behind the icon

## Regenerating AppIcon.icns

macOS only (uses QuickLook + iconutil):

```bash
python3 gen_icon.py
rm -rf AppIcon.iconset && mkdir AppIcon.iconset
while read -r size name; do
  rm -f photocensus-icon.svg.png
  qlmanage -t -s "$size" -o . photocensus-icon.svg >/dev/null 2>&1
  /bin/mv -f photocensus-icon.svg.png "AppIcon.iconset/$name.png"
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
