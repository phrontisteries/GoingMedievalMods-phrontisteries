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


def cold_shelf(goods=False):
    """Empty by default: in game the stored piles sit on the boards. goods=True adds sample food (not used)."""
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
    """3x3 building, drawn centred on (0, 0): an empty staved tub (water and fish are not part of the model;
    the game shows its 'working' effect while the farm produces)."""
    m = Model()
    r, h = 1.30, 0.72
    m.barrel((0, 0, 0), r, h, WOOD, IRON, seg=32, lid=False)
    m.lathe((0, 0, 0), [(r * 0.86, 0.08), (r * 0.86, h * 0.97)], WOOD_D, seg=32)          # inner wall
    m.cylinder((0, 0, 0), r * 0.86, 0.08, WOOD_D, seg=32, top=(150, 96, 52))              # empty plank floor
    for x in (-0.75, -0.45, -0.15, 0.15, 0.45, 0.75):                                     # floor seams
        half = (max(0.0, (r * 0.86) ** 2 - x ** 2)) ** 0.5
        m.box((x, 0.082, 0), (0.012, 0.004, 2 * half - 0.05), (118, 74, 40))
    # props, kept inside the 3x3 footprint: water bucket, feed sack, net pole
    m.barrel((1.22, 0, -1.10), 0.16, 0.28, WOOD_L, IRON, seg=10, top=(150, 96, 52))
    m.sphere((-1.18, 0.18, 1.12), 0.20, (198, 172, 120), seg=8, rings=5)
    m.box((-1.30, 0.55, -1.15), (0.05, 1.1, 0.05), WOOD_D)
    m.lathe((-1.30, 1.05, -1.0), [(0.16, 0.0), (0.12, -0.14)], (214, 204, 170), seg=8)
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


# ---- preview art for mods without new items (rendered like the game's icons)
CLOTH, CLOTH_D = (250, 250, 246), (220, 220, 214)
PURPLE, PURPLE_D, GOLD = (118, 70, 168), (88, 50, 128), (226, 182, 78)
WOOL, WOOL_D, SKIN = (232, 236, 240), (206, 212, 220), (60, 52, 48)
HAY, HAY_D = (226, 196, 108), (196, 164, 80)
CANVAS = (232, 220, 186)


def surrender_flag():
    """More Prisoners: a white flag of surrender planted in the ground, with a merchant's coin purse."""
    m = Model()
    m.cylinder((0, 0, 0), 0.035, 1.9, WOOD_D, seg=8)                              # pole
    m.sphere((0, 1.92, 0), 0.05, WOOD_L, seg=8, rings=5)
    # waving cloth: strips that ripple along the pole
    import math
    cols = 8
    for i in range(cols):
        x0, x1 = 0.04 + i * 0.14, 0.04 + (i + 1) * 0.14
        z0, z1 = 0.025 * math.sin(i * 0.9) + 0.06 * i, 0.025 * math.sin((i + 1) * 0.9) + 0.06 * (i + 1)   # flies slightly toward the light
        sag0, sag1 = 0.03 * i, 0.03 * (i + 1)
        m.quad((x0, 1.88 - sag0, z0), (x1, 1.88 - sag1, z1), (x1, 1.16 - sag1, z1), (x0, 1.16 - sag0, z0), CLOTH)
    m.cylinder((0, 0, 0), 0.22, 0.05, (110, 92, 70), seg=10)                     # mound of earth
    m.sphere((0.38, 0.13, 0.22), 0.14, (150, 104, 60), seg=9, rings=6)           # coin purse
    m.cylinder((0.38, 0.25, 0.22), 0.05, 0.06, (120, 80, 46), seg=8)
    for (x, z) in ((0.58, 0.12), (0.64, 0.30), (0.52, 0.36)):
        m.cylinder((x, 0, z), 0.06, 0.02, GOLD, seg=10)                           # coins
    return m


def sheep():
    m = Model()
    m.box((0, 0.48, -0.05), (0.40, 0.34, 0.56), WOOL, top=WOOL)                   # body (long along z)
    for dz in (-0.22, -0.05, 0.12):                                               # woolly lumps
        m.sphere((0, 0.66, dz), 0.14, WOOL_D if dz else WOOL, seg=7, rings=4)
    m.box((0.05, 0.6, 0.27), (0.16, 0.18, 0.18), SKIN)                             # head, facing the viewer (+z)
    m.box((0.15, 0.67, 0.25), (0.08, 0.03, 0.06), SKIN); m.box((-0.05, 0.67, 0.25), (0.08, 0.03, 0.06), SKIN)  # ears
    for x in (-0.12, 0.12):
        for z in (-0.25, 0.14):
            m.box((x, 0.16, z), (0.07, 0.32, 0.07), SKIN)                         # legs
    return m


def animal_pen():
    """Better Animals: a sheep at a hay-filled trough by a short fence."""
    m = Model()
    m.add(sheep(), (-0.15, 0, 0.05))
    m.box((0.62, 0.18, -0.05), (0.26, 0.2, 0.7), WOOD, top=WOOD_D)                # trough
    m.box((0.62, 0.3, -0.05), (0.2, 0.06, 0.62), HAY, top=HAY)
    m.box((0.95, 0.2, 0.55), (0.42, 0.34, 0.34), HAY, top=HAY_D)                  # hay bale, beside the trough
    for x in (-0.9, -0.3, 0.3, 0.9):                                              # fence behind
        m.box((x, 0.4, -0.95), (0.07, 0.8, 0.07), WOOD_D)
    for y in (0.35, 0.65):
        m.box((0, y, -0.95), (1.9, 0.06, 0.05), WOOD)
    return m


def caravan_cart():
    """Faster Region Travel: a covered travel cart."""
    m = Model()
    m.box((0, 0.48, 0), (1.2, 0.12, 0.7), WOOD_D)                                 # bed
    m.box((0, 0.62, 0.34), (1.2, 0.18, 0.04), WOOD); m.box((0, 0.62, -0.34), (1.2, 0.18, 0.04), WOOD)
    m.lathe((0, 0.62, 0), [(0.36, -0.55), (0.36, 0.55)], CANVAS, seg=16, axis="x")   # canvas cover (a tube...)
    m.box((0, 0.45, 0), (1.15, 0.3, 0.74), WOOD_D)                                # ...whose lower half sits in the bed
    for x in (-0.55, 0.55):
        m.lathe((x, 0.62, 0), [(0.37, -0.03), (0.37, 0.03)], WOOD, seg=16, axis="x")  # hoops
    for z in (-0.42, 0.42):                                                       # wheels
        m.cylinder((0, 0.32, z), 0.32, 0.06, WOOD, seg=14, axis="z", top=WOOD_L)
        m.cylinder((0, 0.32, z + (0.06 if z > 0 else -0.02)), 0.07, 0.02, IRON, seg=8, axis="z")
    m.box((0.95, 0.42, 0), (0.7, 0.05, 0.05), WOOD_D)                             # shaft
    for (x, z) in ((0.2, 0.1), (-0.25, -0.1)):
        m.box((x, 0.72, z), (0.22, 0.16, 0.2), (176, 132, 82))                    # cargo crates peeking out
    return m


def fine_tunic():
    """Fine Clothing Worker: a superior tunic with gold trim on a wooden clothes stand."""
    m = Model()
    m.cylinder((0, 0, 0), 0.26, 0.05, WOOD_D, seg=10)                             # base
    m.cylinder((0, 0, 0), 0.03, 1.55, WOOD_D, seg=8)                              # post
    m.box((0, 1.5, 0), (0.62, 0.05, 0.05), WOOD)                                  # shoulders
    m.box((0, 1.1, 0), (0.48, 0.7, 0.2), PURPLE, top=PURPLE_D)                    # torso
    m.box((0, 0.66, 0), (0.56, 0.22, 0.22), PURPLE_D)                             # skirt
    for s in (-1, 1):
        m.box((s * 0.33, 1.28, 0), (0.18, 0.36, 0.18), PURPLE)                    # sleeves
        m.box((s * 0.33, 1.08, 0), (0.19, 0.05, 0.19), GOLD)                      # cuffs
    m.box((0, 1.1, 0.105), (0.05, 0.68, 0.01), GOLD)                              # placket
    m.box((0, 0.84, 0.0), (0.5, 0.05, 0.215), GOLD)                               # belt
    m.box((0, 0.56, 0.0), (0.57, 0.04, 0.225), GOLD)                              # hem
    m.sphere((0, 1.44, 0.11), 0.05, GOLD, seg=8, rings=5)                         # brooch
    return m


def broker_scale():
    """Brokerastered: a merchant's balance scale weighing coins, with a pickaxe and ore."""
    m = Model()
    m.box((0, 0.04, 0), (0.7, 0.08, 0.4), WOOD_D, top=WOOD)                      # base
    m.cylinder((0, 0.08, 0), 0.03, 1.0, IRON, seg=8)                             # post
    m.box((0, 1.06, 0), (1.0, 0.04, 0.04), IRON)                                 # beam
    for s in (-1, 1):
        x = s * 0.48
        for dz in (-0.06, 0.06):
            m.box((x, 0.88, dz), (0.01, 0.34, 0.01), (200, 196, 180))           # chains
        m.lathe((x, 0.66, 0), [(0.02, 0.0), (0.2, 0.05), (0.21, 0.07)], GOLD, seg=14)   # pan
    for i in range(4):
        m.cylinder((-0.48, 0.73 + i * 0.022, 0), 0.07, 0.02, GOLD, seg=12)      # coin stack
    m.sphere((0.48, 0.79, 0), 0.08, (120, 128, 140), seg=7, rings=4)             # ore lump
    # pickaxe leaning at the base
    m.box((0.62, 0.32, 0.18), (0.04, 0.62, 0.04), WOOD_L)
    m.box((0.62, 0.62, 0.18), (0.36, 0.05, 0.05), IRON)
    return m
