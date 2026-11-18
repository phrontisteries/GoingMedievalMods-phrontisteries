# SPDX-License-Identifier: MIT  (Copyright (c) 2026 phrontisteries; see LICENSE)
"""Build-menu icon for the Cold Shelf: the game's own shelf icon with the shelf recoloured to its
frosted in-game look (blue-grey, light boards, darker posts) and the snowflake badge of the Cold Floors.

    python make_cold_shelf_icon.py <game shelf icon.png> <out.png>

Only the shelf is recoloured: its pixels are the tan wood and the violet shadows of the game's icon
style; the olive tile, cyan glow and grid of the background stay as the game draws them.
"""
import colorsys
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_cold_floor_icons import snowflake  # noqa: E402

FROST_HUE = 212 / 360        # the Cold Shelf's in-game blue-grey
FROST_SAT = 0.30
LIFT = 0.04                  # frost reads a touch lighter than wood


def is_shelf(h, l, s):
    deg = h * 360
    wood = deg <= 50 and s > 0.15                  # tan wood and its red-brown shading
    shadow = deg >= 235 and s > 0.15               # the icon style's violet shadows (round to red)
    return (wood or shadow) and 0.06 < l < 0.95    # the olive tile, cyan glow and white grid are not


def main(src, dst):
    im = Image.open(src).convert("RGBA")
    a = np.asarray(im).astype(float) / 255
    out = a.copy()
    for y in range(a.shape[0]):
        for x in range(a.shape[1]):
            r, g, b, al = a[y, x]
            if al == 0:
                continue
            h, l, s = colorsys.rgb_to_hls(r, g, b)
            if is_shelf(h, l, s):
                out[y, x, :3] = colorsys.hls_to_rgb(FROST_HUE, min(0.95, l + LIFT), FROST_SAT)
    icon = Image.fromarray((out * 255).round().astype("uint8"))
    w, h = icon.size
    badge = snowflake(int(w * 0.36))
    icon.alpha_composite(badge, (w - badge.width - int(w * 0.02), h - badge.height - int(h * 0.02)))
    icon.save(dst)


if __name__ == "__main__":
    main(*sys.argv[1:3])
