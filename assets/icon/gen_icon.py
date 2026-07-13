#!/usr/bin/env python3
"""Generate the PhotoCensus app icon (SVG) — photo-print stacks as a bar chart.

Design philosophy: "Tallied Light" — counting as devotion. White-edged photo
prints stacked at a strict pitch with tiny hand rotations, on a dusk gradient
squircle, warm accents only inside the prints, tallest column earns the
warmest light.
"""
import random
from pathlib import Path

CANVAS = 1024
# Apple macOS icon grid: 824x824 squircle centered, corner radius ~186
ICON = 824
MARGIN = (CANVAS - ICON) / 2
RADIUS = 186

random.seed(20260712)

# Photo print geometry
PRINT_W = 128
PRINT_H = 102
BORDER = 10          # white border of the print
PITCH = 30           # vertical stacking pitch
BASELINE = MARGIN + ICON - 132   # y of the bottom print's bottom edge

# Columns: (x-center offset from icon center, number of prints, accent)
# Skyline cadence: mid, low, tall(hero), mid-low
COLUMNS = [
    (-234, 7, "#7EC8E3"),   # sky
    (-78, 4, "#9FE2BF"),    # seafoam
    (78, 11, "#FF7F6B"),    # coral — the heavy day (hero)
    (234, 6, "#FFC15E"),    # amber
]


def photo_inner(x, y, w, h, color, idx):
    """Inner 'photograph' of a print: tonal field + sun + mountains."""
    cx = x + w * 0.30
    cy = y + h * 0.30
    r = h * 0.14
    m = f"M {x} {y+h} L {x+w*0.34} {y+h*0.46} L {x+w*0.56} {y+h*0.74} " \
        f"L {x+w*0.74} {y+h*0.52} L {x+w} {y+h} Z"
    return f'''
      <rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{color}"/>
      <rect x="{x}" y="{y}" width="{w}" height="{h}" fill="url(#photoShade)"/>
      <circle cx="{cx}" cy="{cy}" r="{r}" fill="#FFFFFF" opacity="0.92"/>
      <path d="{m}" fill="#0E3554" opacity="0.35"/>
    '''


def print_stack(cx_off, n, accent):
    """One column: n prints stacked, only the top one shows the photo."""
    out = []
    cx = CANVAS / 2 + cx_off
    for i in range(n):
        bottom = BASELINE - i * PITCH
        y = bottom - PRINT_H
        x = cx - PRINT_W / 2
        rot = random.uniform(-2.4, 2.4)
        if i == n - 1:
            rot = random.uniform(-3.6, 3.6)
        is_top = i == n - 1
        inner = ""
        if is_top:
            inner = photo_inner(x + BORDER, y + BORDER,
                                PRINT_W - 2 * BORDER, PRINT_H - 2 * BORDER,
                                accent, i)
        else:
            # edge-on prints: white card with a faint tonal strip so the
            # stack reads as accumulated paper, not a solid slab
            inner = (f'<rect x="{x + BORDER}" y="{y + BORDER}" '
                     f'width="{PRINT_W - 2 * BORDER}" height="{PRINT_H - 2 * BORDER}" '
                     f'fill="#E9F0F4"/>')
        out.append(f'''
    <g transform="rotate({rot:.2f} {cx} {bottom})">
      <rect x="{x}" y="{y}" width="{PRINT_W}" height="{PRINT_H}" rx="7"
            fill="#FFFFFF" filter="url(#printShadow)"/>
      {inner}
    </g>''')
    return "".join(out)


def dot_grid():
    """Whisper-faint graph-paper dots inside the squircle."""
    dots = []
    step = 64
    y = MARGIN + step
    while y < MARGIN + ICON - 24:
        x = MARGIN + step
        while x < MARGIN + ICON - 24:
            dots.append(f'<circle cx="{x}" cy="{y}" r="2.6" fill="#FFFFFF" opacity="0.07"/>')
            x += step
        y += step
    return "".join(dots)


columns_svg = "".join(print_stack(*c) for c in COLUMNS)

svg = f'''<svg width="{CANVAS}" height="{CANVAS}" viewBox="0 0 {CANVAS} {CANVAS}" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="dusk" x1="0" y1="0" x2="0.35" y2="1">
      <stop offset="0" stop-color="#1B2E6B"/>
      <stop offset="0.55" stop-color="#14508A"/>
      <stop offset="1" stop-color="#0E8A8F"/>
    </linearGradient>
    <linearGradient id="photoShade" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.16"/>
      <stop offset="1" stop-color="#000000" stop-opacity="0.10"/>
    </linearGradient>
    <radialGradient id="glow" cx="0.62" cy="0.18" r="0.9">
      <stop offset="0" stop-color="#FFFFFF" stop-opacity="0.14"/>
      <stop offset="0.5" stop-color="#FFFFFF" stop-opacity="0.0"/>
    </radialGradient>
    <filter id="iconShadow" x="-20%" y="-20%" width="140%" height="140%">
      <feDropShadow dx="0" dy="12" stdDeviation="18" flood-color="#000000" flood-opacity="0.30"/>
    </filter>
    <filter id="printShadow" x="-30%" y="-30%" width="160%" height="160%">
      <feDropShadow dx="0" dy="5" stdDeviation="6" flood-color="#07203A" flood-opacity="0.35"/>
    </filter>
    <clipPath id="squircle">
      <rect x="{MARGIN}" y="{MARGIN}" width="{ICON}" height="{ICON}" rx="{RADIUS}"/>
    </clipPath>
  </defs>

  <rect x="{MARGIN}" y="{MARGIN}" width="{ICON}" height="{ICON}" rx="{RADIUS}"
        fill="url(#dusk)" filter="url(#iconShadow)"/>
  <g clip-path="url(#squircle)">
    <rect x="{MARGIN}" y="{MARGIN}" width="{ICON}" height="{ICON}" fill="url(#glow)"/>
    {dot_grid()}
    <line x1="{CANVAS/2 - 234 - 88}" y1="{BASELINE + 16}" x2="{CANVAS/2 + 234 + 88}" y2="{BASELINE + 16}"
          stroke="#FFFFFF" stroke-opacity="0.28" stroke-width="5" stroke-linecap="round"/>
    {columns_svg}
  </g>
</svg>
'''

out = Path(__file__).resolve().parent / "photocensus-icon.svg"
out.write_text(svg)
print(f"wrote {out}")
