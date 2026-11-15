# SPDX-License-Identifier: MIT  (Copyright (c) 2026 phrontisteries; see LICENSE)
"""Low-poly models of the mods' new items (metres, Y up, origin = centre of the tile floor)."""
from model3d import Model

WOOD, WOOD_D, WOOD_L = (214, 140, 62), (168, 104, 48), (232, 176, 98)
IRON = (86, 82, 88)
ICE, ICE_L, ICE_D = (150, 214, 245), (226, 246, 255), (96, 170, 220)
CLAY, CLAY_D = (196, 106, 70), (150, 78, 52)
CHEESE, APPLE, APPLE_D, LEAF = (236, 204, 120), (206, 58, 44), (150, 36, 32), (110, 160, 64)
WATER, WATER_D = (64, 150, 176), (40, 104, 136)
FISH, FISH_B = (132, 156, 96), (214, 220, 170)


def cold_shelf(goods=True):
    """goods=False: just the shelf (in game, the stored piles sit on the boards)."""
    m = Model()
    w, d, h = 0.86, 0.46, 2.0                         # footprint and height (fits one tile)
    for x in (-w / 2 + 0.04, w / 2 - 0.04):            # posts
        for z in (-d / 2 + 0.04, d / 2 - 0.04):
            m.box((x, h / 2, z), (0.07, h, 0.07), WOOD_D)
    for y in (0.209, 0.909, 1.751):                    # boards: tops at the game's pile slots (0.234/0.934/1.776)
        m.box((0, y, 0), (w, 0.05, d), WOOD, top=WOOD_L)
        # frost rim along the front edge + icicles
        m.box((0, y + 0.03, d / 2 - 0.03), (w - 0.06, 0.02, 0.05), ICE_L)
        for i, x in enumerate((-0.33, -0.18, -0.02, 0.15, 0.31)):
            m.cone((x, y - 0.025 - (0.10 + 0.04 * (i % 2)), d / 2 - 0.03), 0.022, 0.10 + 0.04 * (i % 2), ICE_L, seg=5)
        if not goods:
            continue
        # goods: ice block, cheese wheel, apples
        m.box((-0.24, y + 0.15, 0.0), (0.22, 0.24, 0.26), ICE, top=ICE_L)
        m.cylinder((0.05, y + 0.025, 0.0), 0.12, 0.10, CHEESE, seg=12, top=(246, 222, 150))
        m.sphere((0.27, y + 0.09, -0.06), 0.065, APPLE, seg=8, rings=5, stem=WOOD_D)
        m.sphere((0.30, y + 0.09, 0.09), 0.065, APPLE_D, seg=8, rings=5, stem=WOOD_D)
    m.box((0, h - 0.02, 0), (w + 0.04, 0.05, d + 0.04), WOOD, top=ICE)     # frosted top
    for x in (-0.34, -0.17, 0.0, 0.17, 0.34):
        m.cone((x, h - 0.14, d / 2 + 0.01), 0.025, 0.12, ICE_L, seg=5)
    return m


def cold_floor():
    m = Model()
    m.box((0, -0.04, 0), (1.0, 0.08, 1.0), (92, 60, 46))                     # grout / bed
    cool = lambda c, k: tuple(int(a * (1 - k) + b * k) for a, b in zip(c, (150, 200, 235)))
    bricks = [(206, 122, 64), (192, 108, 56), (218, 136, 74)]
    # herringbone: pairs of bricks alternating direction
    for i in range(4):
        for j in range(4):
            x, z = -0.375 + i * 0.25, -0.375 + j * 0.25
            horiz = (i + j) % 2 == 0
            for k in (-1, 1):
                off = (0, k * 0.0575) if horiz else (k * 0.0575, 0)
                size = (0.235, 0.05, 0.105) if horiz else (0.105, 0.05, 0.235)
                frosty = (i * 7 + j * 3 + k) % 5 == 0
                c = cool(bricks[(i + 2 * j + k) % 3], 0.10)
                m.box((x + off[0], 0.025, z + off[1]), size, c, top=cool(c, 0.55) if frosty else c)
    return m


def fish_farm():
    m = Model()
    r, h = 0.62, 0.55
    m.barrel((0, 0, 0), r, h, WOOD, IRON, seg=22, lid=False)
    m.lathe((0, 0, 0), [(r * 0.8, h * 0.05), (r * 0.8, h * 0.82)], WOOD_D, seg=22)       # inner wall
    m.cylinder((0, 0, 0), r * 0.8, h * 0.82, WATER, seg=22, top=WATER)                    # water
    for x, z, s in ((-0.18, 0.1, 1), (0.16, -0.12, -1)):                                 # fish under the surface
        m.box((x, h * 0.83, z), (0.20, 0.01, 0.06), WATER_D)
    # leaping fish
    body = Model().sphere((0, 0, 0), 0.08, FISH, seg=8, rings=5)
    for t in body.tris: pass
    fish = Model()
    for tri, c in zip(body.tris, body.cols):
        fish.tri(*[(v[0] * 1.9, v[1], v[2] * 0.7) for v in tri], c)
    fish.tri((-0.14, 0, 0), (-0.24, 0.07, 0), (-0.24, -0.07, 0), FISH)
    fish.box((0.02, -0.03, 0), (0.18, 0.02, 0.07), FISH_B)
    m.add(fish, (0.05, h + 0.22, 0.05))
    for (x, y, z) in ((-0.12, h + 0.08, 0.1), (0.22, h + 0.12, -0.02), (0.0, h + 0.04, -0.15)):
        m.sphere((x, y, z), 0.025, ICE_L, seg=6, rings=4)                                  # splash
    # feed sack and small bucket beside it
    m.sphere((0.72, 0.16, 0.25), 0.17, (198, 172, 120), seg=8, rings=5)
    m.barrel((-0.7, 0, 0.32), 0.13, 0.22, WOOD_L, IRON, seg=10, top=WATER)
    return m


def fermenting_apple_cider():
    m = Model()
    m.barrel((0, 0, 0), 0.30, 0.62, (150, 100, 60), IRON, seg=14, top=(120, 80, 48))
    m.cylinder((0.09, 0.62, 0.07), 0.27, 0.035, (170, 118, 70), seg=14, top=(170, 118, 70))     # round lid, pushed aside\n    for dx in (-0.08, 0.02, 0.12, 0.22):\n        m.box((dx, 0.657, 0.07), (0.012, 0.004, 0.42), WOOD_D)                  # plank seams
    m.cylinder((-0.05, 0.62, -0.06), 0.06, 0.06, (232, 196, 120), seg=8)       # foam / bung
    for (x, z, c) in ((0.34, 0.24, APPLE), (0.20, 0.38, APPLE_D), (0.44, 0.05, APPLE)):
        m.sphere((x, 0.09, z), 0.09, c, seg=9, rings=6, stem=WOOD_D)
    m.box((0.32, 0.19, 0.30), (0.06, 0.012, 0.03), LEAF)
    return m
