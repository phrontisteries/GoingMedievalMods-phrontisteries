# SPDX-License-Identifier: MIT  (Copyright (c) 2026 phrontisteries; see LICENSE)
"""Make a tinted copy of a game texture (e.g. the shelf's palette texture) for a mod building.

The copy keeps every texel's light and dark (so planks, edges and shading still read) and
moves its colour to the target tint. Only the mod's own building uses the copy.

    python recolor_texture.py <in.png> <out.png> [#AFD8F5] [strength 0..1]
    python recolor_texture.py <in.png> <out.png> frost [#DCEFFF] [amount 0..1] [contrast, 1 = unchanged]

"frost" keeps the original colours and lays a pale wash over them (the Cold Shelf uses this):
the texel is lightened, slightly desaturated and blended towards the frost colour.
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


def frost_pixel(rgb, tint=(0.86, 0.94, 1.0), amount=0.3, contrast=1.0, pivot=0.45):
    """One colour (0..1 floats) with a frost wash: warmth drained, shading kept, pale blue laid over.
    contrast > 1 pushes darks darker and lights lighter around the pivot brightness."""
    r, g, b = rgb
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    cr, cg, cb = colorsys.hls_to_rgb(h, l, s * max(0.0, 1 - 1.6 * amount))       # drain the warm colour
    lum = 0.299 * cr + 0.587 * cg + 0.114 * cb
    wash = [t * (0.35 + 0.9 * lum) for t in tint]                                   # frost colour, shaded like the wood
    out = [c * (1 - amount) + w * amount for c, w in zip((cr, cg, cb), wash)]
    return tuple(min(1.0, max(0.0, pivot + (c - pivot) * contrast)) for c in out)


def frost(src, dst, tint="#DCEFFF", amount=0.3, contrast=1.0):
    t = tuple(int(tint[i:i + 2], 16) / 255 for i in (1, 3, 5))
    im = Image.open(src).convert("RGBA")
    px = im.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            out = frost_pixel((r / 255, g / 255, b / 255), t, amount, contrast)
            px[x, y] = tuple(round(v * 255) for v in out) + (a,)
    im.save(dst)


def blend(src, other, dst, k_dark, k_light, l_dark=0.32, l_light=0.78):
    """Per-channel blend from texture src towards texture other, with a separate strength for dark
    and light texels (interpolated by the src texel's brightness). Used to calibrate the Cold Shelf
    against in-game screenshots, where the game's lighting and colour grading shift colours unevenly.
    k_dark / k_light are (r, g, b) strengths; 0 keeps src, 1 gives other."""
    a = Image.open(src).convert("RGBA")
    b = Image.open(other).convert("RGBA")
    pa, pb = a.load(), b.load()
    for y in range(a.height):
        for x in range(a.width):
            r, g, bl, al = pa[x, y]
            r2, g2, b2, _ = pb[x, y]
            l = (0.299 * r + 0.587 * g + 0.114 * bl) / 255
            t = min(1.0, max(0.0, (l - l_dark) / (l_light - l_dark)))
            k = [kd + (kl - kd) * t for kd, kl in zip(k_dark, k_light)]
            pa[x, y] = tuple(min(255, max(0, round(c1 + kk * (c2 - c1)))) for c1, c2, kk in zip((r, g, bl), (r2, g2, b2), k)) + (al,)
    a.save(dst)


if __name__ == "__main__":
    if len(sys.argv) > 3 and sys.argv[3] == "frost":
        frost(sys.argv[1], sys.argv[2], *(sys.argv[4:5] or ["#DCEFFF"]), *[float(v) for v in sys.argv[5:7]])
        sys.exit()
    recolor(sys.argv[1], sys.argv[2], *(sys.argv[3:4] or ["#AFD8F5"]), *([float(sys.argv[4])] if len(sys.argv) > 4 else []))
