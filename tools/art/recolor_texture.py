# SPDX-License-Identifier: MIT  (Copyright (c) 2026 phrontisteries; see LICENSE)
"""Make a tinted copy of a game texture (e.g. the shelf's palette texture) for a mod building.

The copy keeps every texel's light and dark (so planks, edges and shading still read) and
moves its colour to the target tint. Only the mod's own building uses the copy.

    python recolor_texture.py <in.png> <out.png> [#AFD8F5] [strength 0..1]
"""
import colorsys
import sys

from PIL import Image


def recolor(src, dst, tint="#AFD8F5", strength=1.0):
    tr, tg, tb = (int(tint[i:i + 2], 16) / 255 for i in (1, 3, 5))
    th, tl, ts = colorsys.rgb_to_hls(tr, tg, tb)
    im = Image.open(src).convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            h, l, s = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
            # keep relative brightness, lift it towards the tint's lightness
            nl = tl * 0.55 + l * 0.45 + (l - 0.45) * 0.35
            nl = min(0.95, max(0.25, nl))
            nr, ng, nb = colorsys.hls_to_rgb(th, nl, ts)
            k = strength
            px[x, y] = (round((r / 255 * (1 - k) + nr * k) * 255), round((g / 255 * (1 - k) + ng * k) * 255),
                        round((b / 255 * (1 - k) + nb * k) * 255), a)
    im.save(dst)


if __name__ == "__main__":
    recolor(sys.argv[1], sys.argv[2], *(sys.argv[3:4] or ["#AFD8F5"]), *([float(sys.argv[4])] if len(sys.argv) > 4 else []))
