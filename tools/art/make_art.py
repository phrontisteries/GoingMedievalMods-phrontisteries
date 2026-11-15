# SPDX-License-Identifier: MIT  (Copyright (c) 2026 phrontisteries; see LICENSE)
"""Makes the repo's original mod art (no game assets, so it is all MIT-licensed):

  * icons: 3D renders of the low-poly models in models.py, lit and framed like the
    game's own icons (128x128) -> recipes\\<Mod>\\Sprites\\<iconPath>.png
  * Workshop previews (1280x720) -> recipes\\<Mod>\\Preview.png
  * in-world meshes for Foxy Voxel's Unity modding project (.obj + palette texture)
    -> unity\\<Mod>\\Mesh, unity\\<Mod>\\Texture (see unity\\README.md)

MakeMod.ps1 copies the icons and previews into the built mods.

    python tools/art/make_art.py            (needs: pip install pillow numpy)
"""
import math, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import model3d, models
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


# mod -> {sprite name (= iconPath): (model, icon kind, camera pitch, footprint half-size in tiles)}
ICONS = {
    "Cold": {"phrontisteries_cold_shelf": (models.cold_shelf, "building", 33, 0.5),
             "phrontisteries_cold_floor": (models.cold_floor, "building", 48, 0.5)},
    "Fish_Farming": {"phrontisteries_fish_farm": (models.fish_farm, "building", 33, 1.5)},
    "Fermenting Apple Cider": {"phrontisteries_fermenting_apple_cider": (models.fermenting_apple_cider, "item", 33, 0.5)},
}
ICON_SIZE = 128   # the game's own icons are 128x128

# mod -> {mesh name: (model, offset from the building's origin tile)} for the Unity project.
# A 3x3 building is centred one tile in from its origin (its collider centre is (1, y, 1)).
MESHES = {
    "Cold": {"phrontisteries_cold_shelf": (models.cold_shelf, (0, 0, 0))},
    "Fish_Farming": {"phrontisteries_fish_farm": (models.fish_farm, (1, 0, 1))},
}


def render_art(model_fn, kind, size, pitch=33):
    """Large transparent render for previews (items keep their white outline)."""
    m = model_fn()
    if kind == "item":
        return model3d.render_icon(m, "item", size, pitch=pitch)
    body = model3d.rasterize(m, size, pitch=pitch, margin=0.04)
    shadow = Image.new("RGBA", body.size, (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 140), (0, 0), body.split()[3])
    out = Image.new("RGBA", body.size, (0, 0, 0, 0))
    out.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(size / 40)), (0, 0))
    out.alpha_composite(body)
    return out


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
    out.alpha_composite(tiles[1].resize((230, 230), Image.LANCZOS), (170, 170))   # second item behind-right
    out.alpha_composite(tiles[0].resize((330, 330), Image.LANCZOS), (-10, 0))
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
             lambda: combo(lambda: render_art(models.cold_shelf, "building", 400), lambda: render_art(models.cold_floor, "building", 400, 48)), (36, 70, 104), (14, 26, 44)),
    "Fish_Farming": ("Fish Farming", ["Breed trout, pike and eel in a 3x3 fish farm.", "Feed them dung, vegetables or animal feed.", "Unlocked with barrel making."],
                     lambda: render_art(models.fish_farm, "building", 400), (30, 82, 96), (12, 32, 40)),
    "Fermenting Apple Cider": ("Apple Cider", ["The fermentation station makes apple cider.", "Ferments like mash, from apples."],
                               lambda: render_art(models.fermenting_apple_cider, "item", 400), (110, 52, 34), (40, 18, 12)),
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
        for name, (fn, kind, pitch, half) in icons.items():
            path = os.path.join(folder, name + ".png")
            model3d.render_icon(fn(), kind, ICON_SIZE, pitch=pitch, footprint=(half, half)).save(path, optimize=True)
            print("icon   ", os.path.relpath(path, ROOT))
    for mod, meshes in MESHES.items():
        for name, (fn, offset) in meshes.items():
            mesh_dir = os.path.join(ROOT, "unity", mod, "Mesh"); tex_dir = os.path.join(ROOT, "unity", mod, "Texture")
            os.makedirs(mesh_dir, exist_ok=True); os.makedirs(tex_dir, exist_ok=True)
            n, tex = model3d.export_obj(fn(), os.path.join(mesh_dir, name + ".obj"), os.path.join(tex_dir, name + "_palette.png"), name, offset=offset)
            print("mesh   ", f"unity/{mod}/Mesh/{name}.obj", f"({n} triangles, {tex[0]}x{tex[1]} palette)")
            sprite_dir = os.path.join(ROOT, "unity", mod, "Sprite"); os.makedirs(sprite_dir, exist_ok=True)
    for mod, (title, lines, art, top, bottom) in PREVIEWS.items():
        folder = os.path.join(ROOT, "recipes", mod)
        os.makedirs(folder, exist_ok=True)
        path = os.path.join(folder, "Preview.png")
        preview(title, lines, art(), top, bottom).save(path, optimize=True)
        print("preview", os.path.relpath(path, ROOT), f"{os.path.getsize(path) // 1024} KB")


if __name__ == "__main__":
    main()
