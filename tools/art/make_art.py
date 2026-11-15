# SPDX-License-Identifier: MIT  (Copyright (c) 2026 phrontisteries; see LICENSE)
"""Draws the repo's original mod art: 64x64 item icons and 1280x720 Workshop previews.

Everything is drawn from simple shapes (no game assets), so it can be MIT-licensed.
Output goes into recipes\\<Mod>\\Sprites\\<icon>.png and recipes\\<Mod>\\Preview.png;
MakeMod.ps1 copies them into the built mod.

    python tools/art/make_art.py            (needs: pip install pillow)
"""
import math, os, sys
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
GAME_VERSION = "1.2.17"
S = 8                      # supersampling factor for smooth edges
OUT = 4                    # outline width (at 64px scale, before supersampling)

# ---------------------------------------------------------------- palette
INK = (38, 28, 22, 255)
WOOD, WOOD_D, WOOD_L = (150, 98, 56, 255), (104, 66, 38, 255), (186, 132, 82, 255)
CLAY, CLAY_D, CLAY_L = (176, 92, 62, 255), (128, 62, 42, 255), (204, 124, 90, 255)
ICE, ICE_D, ICE_L = (120, 190, 235, 255), (64, 132, 196, 255), (214, 240, 255, 255)
WATER, WATER_D = (70, 140, 170, 255), (44, 98, 128, 255)
APPLE, APPLE_D, LEAF = (196, 52, 44, 255), (140, 30, 30, 255), (96, 150, 60, 255)
GOLD = (222, 176, 78, 255)
IRON, IRON_D = (140, 146, 150, 255), (92, 98, 104, 255)


def canvas(px=64):
    img = Image.new("RGBA", (px * S, px * S), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def P(*pts):               # scale 64-space points to the supersampled canvas
    return [(x * S, y * S) for x, y in pts]


def box(d, x0, y0, x1, y1, fill, r=0, w=OUT):
    d.rounded_rectangle((x0 * S, y0 * S, x1 * S, y1 * S), radius=r * S, fill=fill, outline=INK, width=int(w * S / 2))


def poly(d, pts, fill, w=OUT):
    d.polygon(P(*pts), fill=fill)
    d.line(P(*pts, pts[0]), fill=INK, width=int(w * S / 2), joint="curve")


def ellipse(d, x0, y0, x1, y1, fill, w=OUT):
    d.ellipse((x0 * S, y0 * S, x1 * S, y1 * S), fill=fill, outline=INK if w else None, width=int(w * S / 2))


def snowflake(d, cx, cy, r, color=ICE_L, w=2.2):
    for k in range(6):
        a = math.pi / 3 * k
        x, y = cx + r * math.cos(a), cy + r * math.sin(a)
        d.line(P((cx, cy), (x, y)), fill=color, width=int(w * S))
        for side in (-1, 1):   # little branches
            bx, by = cx + 0.6 * r * math.cos(a), cy + 0.6 * r * math.sin(a)
            b = a + side * math.pi / 4
            d.line(P((bx, by), (bx + 0.35 * r * math.cos(b), by + 0.35 * r * math.sin(b))), fill=color, width=int(w * S * 0.8))


def finish(img, px=64):
    """Downsample and add a soft drop shadow so icons read on any background."""
    small = img.resize((px, px), Image.LANCZOS)
    shadow = Image.new("RGBA", small.size, (0, 0, 0, 0))
    alpha = small.split()[3].point(lambda a: int(a * 0.45))
    shadow.paste((0, 0, 0, 255), (1, 2), alpha)
    shadow = shadow.filter(ImageFilter.GaussianBlur(1.2))
    return Image.alpha_composite(shadow, small)


# ---------------------------------------------------------------- icons
def icon_cold_shelf():
    img, d = canvas()
    box(d, 12, 6, 52, 60, WOOD_D, r=2)                    # frame
    for y in (10, 27, 44):                                # three boards with icy goods
        box(d, 15, y + 11, 49, y + 15, WOOD_L, r=1, w=3)
        box(d, 18, y + 2, 27, y + 11, ICE, r=2, w=3)
        box(d, 29, y + 4, 37, y + 11, (232, 214, 160, 255), r=2, w=3)
        ellipse(d, 39, y + 3, 47, y + 11, APPLE, w=3)
    for x in range(14, 51, 6):                            # frost on top
        poly(d, [(x - 3, 6), (x + 3, 6), (x, 11)], ICE_L, w=2)
    snowflake(d, 50, 12, 9, ICE_D, w=3.2)
    snowflake(d, 50, 12, 9, ICE_L, w=1.8)
    return finish(img)


def icon_cold_floor():
    img, d = canvas()
    poly(d, [(32, 8), (60, 24), (32, 40), (4, 24)], CLAY)          # top face (isometric tile)
    poly(d, [(4, 24), (32, 40), (32, 52), (4, 36)], CLAY_D)        # left side
    poly(d, [(60, 24), (32, 40), (32, 52), (60, 36)], CLAY_D)      # right side
    for t in (0.33, 0.66):                                         # brick joints
        a = (4 + 28 * t, 24 - 16 * t); b = (32 + 28 * t, 40 - 16 * t)
        d.line(P(a, b), fill=INK, width=int(1.6 * S))
        a = (32 - 28 * t, 8 + 16 * t); b = (60 - 28 * t, 24 + 16 * t)
        d.line(P(a, b), fill=INK, width=int(1.6 * S))
    overlay = Image.new("RGBA", img.size, (0, 0, 0, 0))            # blue chill on the top face
    ImageDraw.Draw(overlay).polygon(P((32, 8), (60, 24), (32, 40), (4, 24)), fill=(150, 210, 255, 90))
    img.alpha_composite(overlay)
    d = ImageDraw.Draw(img)
    snowflake(d, 32, 24, 11, ICE_D, w=3.4)
    snowflake(d, 32, 24, 11, ICE_L, w=2.0)
    return finish(img)


def fish(d, cx, cy, size, body, belly, facing=1):
    f = facing
    poly(d, [(cx - f * size * 0.9, cy), (cx - f * size * 1.5, cy - size * 0.55), (cx - f * size * 1.5, cy + size * 0.55)], body, w=2.5)
    ellipse(d, cx - size, cy - size * 0.55, cx + size, cy + size * 0.55, body, w=2.5)
    d.ellipse(((cx - size * 0.6) * S, (cy) * S, (cx + size * 0.6) * S, (cy + size * 0.42) * S), fill=belly)
    d.ellipse(((cx + f * size * 0.5 - 1.3) * S, (cy - size * 0.2 - 1.3) * S, (cx + f * size * 0.5 + 1.3) * S, (cy - size * 0.2 + 1.3) * S), fill=INK)


def icon_fish_farm():
    img, d = canvas()
    poly(d, [(8, 26), (56, 26), (52, 60), (12, 60)], WOOD)          # tub
    for x in (20, 32, 44):
        d.line(P((x, 27), (x - (x - 32) * 0.15, 59)), fill=WOOD_D, width=int(1.8 * S))
    box(d, 7, 32, 57, 36, IRON, r=1, w=3); box(d, 9, 50, 55, 54, IRON, r=1, w=3)
    ellipse(d, 6, 18, 58, 32, WOOD_D)                               # rim
    ellipse(d, 10, 20, 54, 30, WATER, w=0)                          # water
    for x in (18, 30, 42):
        d.arc(((x - 4) * S, 22 * S, (x + 4) * S, 27 * S), 200, 340, fill=(170, 220, 235, 255), width=int(1.6 * S))
    fish(d, 34, 12, 8, (120, 150, 90, 255), (210, 220, 170, 255), facing=-1)   # leaping fish
    for (x, y) in ((22, 14), (18, 8), (46, 9)):
        ellipse(d, x - 1.6, y - 1.6, x + 1.6, y + 1.6, (190, 230, 245, 255), w=1.5)
    return finish(img)


def icon_fermenting_apple_cider():
    img, d = canvas()
    ellipse(d, 10, 14, 50, 60, WOOD)                                # small barrel, side view
    for x in (20, 30, 40):
        d.arc((x * S - 14 * S, 14 * S, x * S + 14 * S, 60 * S), 250, 290, fill=WOOD_D, width=int(1.6 * S))
    box(d, 9, 22, 51, 26, IRON_D, r=1, w=3); box(d, 9, 48, 51, 52, IRON_D, r=1, w=3)
    box(d, 27, 8, 33, 16, WOOD_L, r=1, w=3)                         # bung with airlock bubbles
    for (x, y, r) in ((36, 6, 2.2), (41, 3, 1.6), (45, 7, 1.2)):
        ellipse(d, x - r, y - r, x + r, y + r, (240, 220, 160, 255), w=1.5)
    ellipse(d, 36, 36, 60, 60, APPLE)                               # apple in front
    d.arc((40 * S, 40 * S, 52 * S, 52 * S), 200, 260, fill=(240, 120, 110, 255), width=int(2 * S))
    d.line(P((48, 37), (50, 31)), fill=WOOD_D, width=int(2.4 * S))
    poly(d, [(50, 33), (58, 29), (54, 36)], LEAF, w=2)
    return finish(img)


ICONS = {   # mod -> {sprite name: drawing}
    "Cold": {"phrontisteries_cold_shelf": icon_cold_shelf, "phrontisteries_cold_floor": icon_cold_floor},
    "Fish_Farming": {"phrontisteries_fish_farm": icon_fish_farm},
    "Fermenting Apple Cider": {"phrontisteries_fermenting_apple_cider": icon_fermenting_apple_cider},
}

# ---------------------------------------------------------------- emblems for previews of mods without new items
def emblem_animals():
    img, d = canvas(64)
    ellipse(d, 16, 28, 48, 58, (196, 150, 104, 255))                # paw pad
    for (x, y) in ((12, 18), (24, 9), (40, 9), (52, 18)):
        ellipse(d, x - 7, y - 7, x + 7, y + 7, (196, 150, 104, 255))
    return img


def emblem_travel():
    img, d = canvas(64)
    box(d, 14, 20, 54, 40, WOOD, r=3)                               # cart
    d.pieslice((14 * S, 6 * S, 54 * S, 34 * S), 180, 360, fill=(230, 214, 176, 255), outline=INK, width=int(OUT * S / 2))
    for x in (22, 46):
        ellipse(d, x - 9, 34, x + 9, 52, WOOD_D)
        ellipse(d, x - 2, 41, x + 2, 45, IRON)
    for y in (16, 26, 36):                                          # speed lines
        d.line(P((0, y), (10, y)), fill=(240, 230, 200, 255), width=int(2.6 * S))
    return img


def emblem_clothing():
    img, d = canvas(64)
    poly(d, [(22, 8), (42, 8), (58, 18), (52, 30), (46, 26), (46, 58), (18, 58), (18, 26), (12, 30), (6, 18)], (92, 60, 140, 255))
    d.line(P((32, 10), (32, 58)), fill=GOLD, width=int(2.4 * S))
    box(d, 18, 40, 46, 44, GOLD, r=1, w=2.5)
    poly(d, [(26, 8), (38, 8), (32, 16)], (230, 214, 176, 255), w=2.5)
    return img


def emblem_prisoners():
    img, d = canvas(64)
    for cx in (20, 44):
        d.ellipse(((cx - 13) * S, 30 * S, (cx + 13) * S, 56 * S), outline=INK, width=int(9 * S))
        d.ellipse(((cx - 13) * S, 30 * S, (cx + 13) * S, 56 * S), outline=IRON, width=int(6 * S))
    for i in range(3):                                              # chain
        y = 8 + i * 8
        d.ellipse((28 * S, y * S, 36 * S, (y + 10) * S), outline=INK, width=int(4 * S))
        d.ellipse((28 * S, y * S, 36 * S, (y + 10) * S), outline=IRON_D, width=int(2.4 * S))
    return img


# ---------------------------------------------------------------- previews
def font(size, bold=False):
    for name in (["DejaVuSerif-Bold.ttf", "georgiab.ttf"] if bold else ["DejaVuSerif.ttf", "georgia.ttf"]):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def preview(title, lines, art, top, bottom):
    W, H = 1280, 720
    img = Image.new("RGBA", (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):                                              # vertical gradient
        t = y / (H - 1)
        d.line((0, y, W, y), fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)) + (255,))
    vignette = Image.new("L", (W, H), 0)
    ImageDraw.Draw(vignette).ellipse((-200, -160, W + 200, H + 160), fill=255)
    vignette = vignette.filter(ImageFilter.GaussianBlur(120))
    img = Image.composite(img, Image.new("RGBA", (W, H), (12, 8, 6, 255)), vignette)
    d = ImageDraw.Draw(img)
    d.rectangle((24, 24, W - 25, H - 25), outline=(222, 190, 120, 255), width=3)          # frame
    d.rectangle((36, 36, W - 37, H - 37), outline=(222, 190, 120, 120), width=1)
    # art on the right
    a = art.resize((400, 400), Image.LANCZOS) if art.width != 400 else art
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse((W - 520, 120, W - 80, 560), fill=(255, 240, 200, 50))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(40)))
    img.alpha_composite(a, (W - 500, 160))
    d = ImageDraw.Draw(img)
    # text on the left
    tf = font(84, bold=True)
    x, y = 90, 120
    for part in wrap(d, title, tf, 680):
        d.text((x + 3, y + 4), part, font=tf, fill=(0, 0, 0, 160))
        d.text((x, y), part, font=tf, fill=(246, 230, 196, 255))
        y += 96
    d.line((x, y + 10, x + 260, y + 10), fill=(222, 190, 120, 255), width=3)
    y += 40
    bf = font(34)
    for line in lines:
        for part in wrap(d, line, bf, 700):
            d.text((x, y), part, font=bf, fill=(232, 220, 196, 255))
            y += 46
        y += 8
    sf = font(26)
    d.text((x, H - 96), f"for Going Medieval {GAME_VERSION}   ·   by phrontisteries", font=sf, fill=(222, 190, 120, 255))
    return img.convert("RGB")


def wrap(d, text, f, width):
    words, out, cur = text.split(), [], ""
    for w in words:
        trial = (cur + " " + w).strip()
        if d.textlength(trial, font=f) <= width or not cur:
            cur = trial
        else:
            out.append(cur); cur = w
    return out + ([cur] if cur else [])


def combo(*fns):           # several icons side by side, as one 400x400 picture
    tiles = [f() for f in fns]
    out = Image.new("RGBA", (400, 400), (0, 0, 0, 0))
    out.alpha_composite(tiles[0].resize((250, 250), Image.LANCZOS), (0, 10))
    out.alpha_composite(tiles[1].resize((250, 250), Image.LANCZOS), (150, 150))
    return out


def hires(fn):
    """Re-run an icon drawing without the 64px downsample, for crisp preview art."""
    global finish
    keep = finish
    finish = lambda img, px=64: img
    try:
        return fn().resize((400, 400), Image.LANCZOS)
    finally:
        finish = keep


PREVIEWS = {   # mod -> (title, lines, art, gradient top, gradient bottom)
    "Cold": ("Cold", ["Cold Shelf: a 10-pile, actively cooled food shelf.", "Cold Floor: clay floor that chills the room.", "Adjusted temperature thresholds."],
             lambda: combo(lambda: hires(icon_cold_shelf), lambda: hires(icon_cold_floor)), (36, 70, 104), (14, 26, 44)),
    "Fish_Farming": ("Fish Farming", ["Breed trout, pike and eel in a fish farm.", "Feed them dung, vegetables or animal feed.", "Unlocked with barrel making."],
                     lambda: hires(icon_fish_farm), (30, 82, 96), (12, 32, 40)),
    "Fermenting Apple Cider": ("Apple Cider", ["The fermentation station makes apple cider.", "Ferments like mash, from apples."],
                               lambda: hires(icon_fermenting_apple_cider), (110, 52, 34), (40, 18, 12)),
    "Better_Animals": ("Better Animals", ["Every animal can be tamed, penned, trained, haul and fight.", "Much stronger haulers; tidier diets.", "Cats hunt pests."],
                       lambda: hires(emblem_animals), (78, 92, 46), (28, 34, 16)),
    "FasterRegionTravel": ("Faster Region Travel", ["Caravans cross the region map 100x faster."],
                           lambda: hires(emblem_travel), (120, 88, 42), (44, 30, 14)),
    "Fine_Clothing_Worker": ("Fine Clothing Worker", ["Settlers in Superior or Flawless apparel work, walk, rest and fight better."],
                             lambda: hires(emblem_clothing), (74, 46, 104), (26, 16, 40)),
    "More_Prisoners": ("More Prisoners", ["Raiders surrender more readily.", "Merchants trade more prisoners."],
                       lambda: hires(emblem_prisoners), (70, 70, 76), (24, 24, 28)),
    # "Mushroom Cropfield" keeps its own hand-made preview.
}


def main():
    for mod, icons in ICONS.items():
        folder = os.path.join(ROOT, "recipes", mod, "Sprites")
        os.makedirs(folder, exist_ok=True)
        for name, fn in icons.items():
            fn().save(os.path.join(folder, name + ".png"), optimize=True)
            print("icon   ", os.path.relpath(os.path.join(folder, name + ".png"), ROOT))
    for mod, (title, lines, art, top, bottom) in PREVIEWS.items():
        folder = os.path.join(ROOT, "recipes", mod)
        os.makedirs(folder, exist_ok=True)
        path = os.path.join(folder, "Preview.png")
        preview(title, lines, art(), top, bottom).save(path, optimize=True)
        print("preview", os.path.relpath(path, ROOT), f"{os.path.getsize(path) // 1024} KB")


if __name__ == "__main__":
    main()
