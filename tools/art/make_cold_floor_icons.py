# SPDX-License-Identifier: MIT  (Copyright (c) 2026 phrontisteries; see LICENSE)
"""Build-menu icons for the Cold Floors: each vanilla floor's own icon, frost-tinted, with a snowflake badge.

    python make_cold_floor_icons.py <vanilla_icon_dir> <out_dir> <floor id> [<floor id> ...]

vanilla_icon_dir holds the game's floor icons (export them with extract_game_texture.py; the icon of a
building is the texture named by its iconPath). Writes phrontisteries_cold_<floor id>.png to out_dir.
Icons are shown in the UI, where the game's colour grading does not apply, so the tint is applied as seen.
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from recolor_texture import frost_pixel  # noqa: E402

TINT = (0.80, 0.90, 1.0)      # pale frost blue
AMOUNT = 0.2                  # how strongly the icon is washed with frost (keeps the material recognisable)
CONTRAST = 1.0


def snowflake(size, colour=(235, 246, 255, 255), outline=(52, 92, 140, 255)):
    """A six-armed snowflake with side branches, drawn at 4x and scaled down for smooth edges."""
    s = size * 4
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = s / 2
    r = s * 0.44
    for width, col in ((int(s * 0.16), outline), (int(s * 0.08), colour)):
        for k in range(6):
            a = math.radians(90 + 60 * k)
            x, y = c + r * math.cos(a), c - r * math.sin(a)
            d.line([(c, c), (x, y)], fill=col, width=width)
            for t in (0.55,):
                bx, by = c + r * t * math.cos(a), c - r * t * math.sin(a)
                for side in (-1, 1):
                    b = a + side * math.radians(45)
                    d.line([(bx, by), (bx + r * 0.32 * math.cos(b), by - r * 0.32 * math.sin(b))], fill=col, width=width)
        d.ellipse([c - width * 0.7, c - width * 0.7, c + width * 0.7, c + width * 0.7], fill=col)
    return img.resize((size, size), Image.LANCZOS)


def make_icon(src, dst):
    im = Image.open(src).convert("RGBA")
    a = np.asarray(im).astype(float) / 255
    out = a.copy()
    for y in range(a.shape[0]):
        for x in range(a.shape[1]):
            if a[y, x, 3] > 0:
                out[y, x, :3] = frost_pixel(tuple(a[y, x, :3]), TINT, AMOUNT, CONTRAST)
    icon = Image.fromarray((out * 255).round().astype("uint8"))
    w, h = icon.size
    badge = snowflake(int(w * 0.36))
    icon.alpha_composite(badge, (w - badge.width - int(w * 0.02), h - badge.height - int(h * 0.02)))
    icon.save(dst)


if __name__ == "__main__":
    src_dir, out_dir, *ids = sys.argv[1:]
    os.makedirs(out_dir, exist_ok=True)
    for fid in ids:
        make_icon(os.path.join(src_dir, fid + ".png"), os.path.join(out_dir, f"phrontisteries_cold_{fid}.png"))
        print("icon", fid)
