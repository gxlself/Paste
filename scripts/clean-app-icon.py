#!/usr/bin/env python3
"""
Remove light semi-transparent halos and bright rim pixels at rounded corners
of Paste app icons. Regenerates macOS AppIcon set, iOS AppIcon, and docs favicons.

Requires: Pillow (pip install Pillow)
Run from repo root: python3 scripts/clean-app-icon.py
"""

from __future__ import annotations

import sys
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Install Pillow: pip install Pillow", file=sys.stderr)
    sys.exit(1)

ROOT = Path(__file__).resolve().parents[1]
W = H = 1024
CORNER = 200  # quadrant size for rounded-corner cleanup


def corner_quadrant(x: int, y: int) -> str | None:
    if x < CORNER and y < CORNER:
        return "TL"
    if x >= W - CORNER and y < CORNER:
        return "TR"
    if x < CORNER and y >= H - CORNER:
        return "BL"
    if x >= W - CORNER and y >= H - CORNER:
        return "BR"
    return None


def clean_icon(im: Image.Image) -> Image.Image:
    im = im.convert("RGBA")
    px = im.load()
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    po = out.load()
    for y in range(H):
        for x in range(W):
            r, g, b, a = px[x, y]
            lum = (r + g + b) / 3.0
            if a == 0:
                po[x, y] = (0, 0, 0, 0)
                continue
            kill = False
            q = corner_quadrant(x, y)

            # Light / white AA fringe (anywhere)
            if 0 < a < 255 and lum >= 128:
                kill = True
            # Bottom-left / bottom-right: milky partial alpha (catches residual ~100–127)
            elif q in ("BL", "BR") and 0 < a < 255 and lum >= 100:
                kill = True
            else:
                if q is not None:
                    d_local = min(
                        x if q in ("TL", "BL") else W - 1 - x,
                        y if q in ("TL", "TR") else H - 1 - y,
                    )
                    if d_local <= 12 and lum >= 128:
                        kill = True
                    elif d_local <= 24 and lum >= 138:
                        kill = True
                    elif d_local <= 40 and lum >= 148:
                        kill = True
            # Bottom edge light rim (both lower corners along last rows)
            if not kill and y >= H - 8 and (x < 240 or x > W - 241) and lum > 82:
                kill = True
            # Outer vertical strips of lower corners (left / right sides)
            if not kill and y > 795 and x < 28 and lum > 92:
                kill = True
            if not kill and y > 795 and x > W - 29 and lum > 92:
                kill = True

            po[x, y] = (0, 0, 0, 0) if kill else (r, g, b, a)
    return out


def square_on_canvas(im: Image.Image) -> Image.Image:
    bbox = im.getbbox()
    if not bbox:
        return im
    l, t, r, b = bbox
    cw, ch = r - l, b - t
    side = max(cw, ch)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    ox = (side - cw) // 2
    oy = (side - ch) // 2
    canvas.paste(im.crop((l, t, r, b)), (ox, oy))
    return canvas


def main() -> None:
    mac_dir = ROOT / "Paste/Assets.xcassets/AppIcon.appiconset"
    src_1024 = mac_dir / "icon_1024.png"
    if not src_1024.exists():
        print(f"Missing {src_1024}", file=sys.stderr)
        sys.exit(1)

    base = Image.open(src_1024)
    cleaned = clean_icon(base)
    cleaned = square_on_canvas(cleaned).resize((1024, 1024), Image.Resampling.LANCZOS)

    sizes = [
        (16, "icon_16.png"),
        (32, "icon_32.png"),
        (64, "icon_64.png"),
        (128, "icon_128.png"),
        (256, "icon_256.png"),
        (512, "icon_512.png"),
        (1024, "icon_1024.png"),
    ]
    for size, name in sizes:
        cleaned.resize((size, size), Image.Resampling.LANCZOS).save(
            mac_dir / name, "PNG", optimize=True
        )
    print("Updated macOS AppIcon.appiconset")

    ios_icon = ROOT / "Paste-iOS/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
    if ios_icon.exists():
        ios = clean_icon(Image.open(ios_icon))
        ios = square_on_canvas(ios).resize((1024, 1024), Image.Resampling.LANCZOS)
        ios.save(ios_icon, "PNG", optimize=True)
        print("Updated iOS AppIcon.png")

    docs = ROOT / "docs"
    if (docs / "favicon-32.png").parent.exists():
        cleaned.resize((32, 32), Image.Resampling.LANCZOS).save(
            docs / "favicon-32.png", "PNG", optimize=True
        )
        cleaned.resize((16, 16), Image.Resampling.LANCZOS).save(
            docs / "favicon-16.png", "PNG", optimize=True
        )
        cleaned.resize((64, 64), Image.Resampling.LANCZOS).save(
            docs / "app-icon-nav.png", "PNG", optimize=True
        )
        apple = cleaned.resize((256, 256), Image.Resampling.LANCZOS)
        apple.resize((180, 180), Image.Resampling.LANCZOS).save(
            docs / "apple-touch-icon.png", "PNG", optimize=True
        )
        print("Updated docs favicons")


if __name__ == "__main__":
    main()
