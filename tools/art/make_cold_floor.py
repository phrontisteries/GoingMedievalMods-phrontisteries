# SPDX-License-Identifier: MIT  (Copyright (c) 2026 phrontisteries; see LICENSE)
"""Cold Floor texture: the game's clay herringbone floor with some bricks frosted.

    pip install numpy scipy networkx pillow
    python make_cold_floor.py <clay_brick_floor_diffuse.png> <cold_shelf_albedo.png> <base_texture_png.png> <shelf.obj> <out.png> [count] [#colour]

Inputs: the game's clay floor texture and shelf texture/model (export them with extract_game_texture.py:
clay_brick_floor_diffuse, base_texture_png, shelf) and the Cold Shelf's frosted texture.

1. Finds every brick (the texture repeats, so bricks that run off one edge continue on the other).
2. Builds the "touching" graph: in herringbone every brick borders exactly 6 others.
3. Picks `count` bricks (default 9, the most possible) with no two touching, spread as evenly as
   possible on the repeating floor.
4. Colours those bricks with the frost colour of the Cold Shelf's boards, keeping each brick's shading.
   The floor faces the light and uses another shader, so the same texture colour shows brighter on a
   floor than on the shelf: pass #colour (the bricks' average texture colour) to match them on screen.
   The Cold Floor uses #948B83, measured from an in-game screenshot to land on the shelf boards' shade.
"""
import itertools
import sys

import networkx as nx
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage


def find_bricks(img):
    h, w = img.shape[:2]
    brick = img.mean(2) > 70
    lab, n = ndimage.label(np.tile(brick, (3, 3)))
    ids = np.arange(1, n + 1)
    sizes = ndimage.sum(np.ones_like(lab), lab, ids)
    centres = ndimage.center_of_mass(np.ones_like(lab), lab, ids)
    masks, info = [], []
    for i, s, (cy, cx) in zip(ids, sizes, centres):
        if s > 4000 and h <= cy < 2 * h and w <= cx < 2 * w:      # each brick once, from the middle copy
            ys, xs = np.where(lab == i)
            m = np.zeros((h, w), bool)
            m[(ys - h) % h, (xs - w) % w] = True
            masks.append(m)
            info.append((cx - w, cy - h))
    return masks, info


def touching_graph(masks, reach=9):
    h, w = masks[0].shape
    grown = []
    for m in masks:
        t = ndimage.binary_dilation(np.tile(m, (3, 3)), structure=np.ones((2 * reach + 1,) * 2))
        grown.append(t[h:2 * h, w:2 * w])
    g = nx.Graph()
    g.add_nodes_from(range(len(masks)))
    for i, j in itertools.combinations(range(len(masks)), 2):
        if (grown[i] & masks[j]).any():
            g.add_edge(i, j)
    return g


def pick(g, centres, size, count):
    w, h = size
    comp = nx.complement(g)
    best = max(len(c) for c in nx.find_cliques(comp))
    count = min(count, best)
    sets = [c for c in nx.enumerate_all_cliques(comp) if len(c) == count]

    def spacing(c):
        if len(c) < 2:
            return 0
        d = []
        for a, b in itertools.combinations(c, 2):
            dx = abs(centres[a][0] - centres[b][0]); dy = abs(centres[a][1] - centres[b][1])
            d.append(min(dx, w - dx) ** 2 + min(dy, h - dy) ** 2)
        return min(d)

    return max(sets, key=spacing), best


def shelf_board_colour(shelf_png, base_png, shelf_obj):
    frost = Image.open(shelf_png).convert("RGB")
    base = Image.open(base_png).convert("RGB")
    w, h = base.size
    uv = [tuple(map(float, l.split()[1:3])) for l in open(shelf_obj) if l.startswith("vt ")]
    pairs = {(base.getpixel((min(w - 1, int(u * w)), min(h - 1, int((1 - v) * h)))),
              frost.getpixel((min(w - 1, int(u * w)), min(h - 1, int((1 - v) * h))))) for u, v in uv}
    boards = [np.array(f, float) for o, f in pairs if o[0] >= 200]     # the light wood of the boards
    return np.mean(boards, 0)


def main(floor_png, shelf_png, base_png, shelf_obj, out_png, count=9, colour=None):
    img = np.asarray(Image.open(floor_png).convert("RGB")).astype(float)
    masks, centres = find_bricks(img)
    g = touching_graph(masks)
    chosen, best = pick(g, centres, img.shape[1::-1], count)
    print(f"{len(masks)} bricks, {set(dict(g.degree()).values())} neighbours each, at most {best} not touching; using {len(chosen)}")
    if colour:
        colour = np.array([int(colour[i:i + 2], 16) for i in (1, 3, 5)], float)
    else:
        colour = shelf_board_colour(shelf_png, base_png, shelf_obj)
    lum = img @ np.array([0.299, 0.587, 0.114])
    m = np.zeros(img.shape[:2], bool)
    for i in chosen:
        m |= masks[i]
    frosted = np.clip(colour * (lum / lum[m].mean())[..., None], 0, 255)
    soft = np.asarray(Image.fromarray((m * 255).astype("uint8")).filter(ImageFilter.GaussianBlur(0.8))).astype(float)[..., None] / 255
    Image.fromarray((img * (1 - soft) + frosted * soft).round().astype("uint8")).save(out_png)


if __name__ == "__main__":
    main(*sys.argv[1:6], *([int(sys.argv[6])] if len(sys.argv) > 6 else []), *(sys.argv[7:8]))
