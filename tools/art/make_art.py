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
    # Cold: icons are made from the game's own icons (make_cold_shelf_icon.py, make_cold_floor_icons.py)
    "Fish_Farming": {"phrontisteries_fish_farm": (models.fish_farm, "building", 33, 1.5)},
    "Fermenting Apple Cider": {"phrontisteries_fermenting_apple_cider": (models.fermenting_apple_cider, "item", 33, 0.5)},
    "Mushroom Cropfield": {"phrontisteries_mushroom_cropfield": (models.mushroom_cropfield, "building", 33, 0.36)},
}
ICON_SIZE = 128   # the game's own icons are 128x128

# mod -> {mesh name: (model, offset from the building's origin tile)} for the Unity project.
# A 3x3 building is centred one tile in from its origin (its collider centre is (1, y, 1)).
MESHES = {
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


# ---------------------------------------------------------------- previews
def font(size, bold=False, sans=False):
    if sans:
        names = ["DejaVuSans.ttf", "segoeui.ttf", "arial.ttf"]
    else:
        names = ["DejaVuSerif-Bold.ttf", "georgiab.ttf"] if bold else ["DejaVuSerif.ttf", "georgia.ttf"]
    for name in names:
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
    bf = font(31, sans=True)
    for line in lines:
        for part in wrap(d, line, bf, 660):
            d.text((x, y), part, font=bf, fill=(232, 220, 196, 255))
            y += 42
        y += 12
    sf = font(24, sans=True)
    d.text((x, H - 96), f"for Going Medieval {GAME_VERSION}   ·   by phrontisteries", font=sf, fill=(222, 190, 120, 255))
    return img.convert("RGB")


def wrap(d, text, f, width):
    """Wrap text into as few lines as fit `width`, then balance them: the narrowest width that still
    gives that many lines, so lines are even and a sentence never ends on a lone word."""
    words = [w for w in text.split(" ") if w]           # ordinary spaces only: non-breaking spaces bind words

    def greedy(limit):
        out, cur = [], ""
        for w in words:
            trial = (cur + " " + w).strip()
            if d.textlength(trial, font=f) <= limit or not cur:
                cur = trial
            else:
                out.append(cur); cur = w
        return out + ([cur] if cur else [])

    lines = greedy(width)
    if len(lines) < 2:
        return lines
    lo, hi = max(d.textlength(w, font=f) for w in words), width
    while hi - lo > 1:                                  # narrowest width with the same number of lines
        mid = (lo + hi) / 2
        if len(greedy(mid)) <= len(lines):
            hi = mid
        else:
            lo = mid
    return greedy(hi)


# ---------------------------------------------------------------- Cold preview art (game assets)
# The game textures are not in the repository: export them with extract_game_texture.py into the folder
# named by GM_ART_WORK (default: work/ next to the repository): shelf (mesh), FloorDiffuseSheet,
# painted_clay_tile_diffuse, marble_floor_diffuse. The Cold textures come from unity/Cold/Texture.
ART_WORK = os.environ.get("GM_ART_WORK", os.path.join(ROOT, "..", "work"))
FROST_HUE, FROST_SAT = 212 / 360, 0.30      # how the frosted parts read in game (blue-grey)
SHELF_AT = (-0.5, -0.5)                     # the shelf stands on the back tile of the 2x2 floor patch


def _in_game(rgb):
    """A frosted colour as it reads in game: its lightness, in the Cold blue-grey."""
    import colorsys
    h, l, s = colorsys.rgb_to_hls(*[c / 255 for c in rgb[:3]])
    return tuple(round(c * 255) for c in colorsys.hls_to_rgb(FROST_HUE, min(0.95, l + 0.04), FROST_SAT))


def _floor_tile(model, origin, vanilla, frosted, tiling, n=40):
    """One floor tile (1x1) as n x n small squares coloured from its texture (world-space, like the game);
    frosted parts (where the Cold texture differs from the game's) in their in-game blue-grey."""
    W, H = vanilla.size
    ox, oz = origin
    for i in range(n):
        for j in range(n):
            x0, z0 = ox + i / n, oz + j / n
            u, v = ((x0 + 0.5 / n) * tiling) % 1, ((z0 + 0.5 / n) * tiling) % 1
            px = (min(W - 1, int(u * W)), min(H - 1, int((1 - v) * H)))
            a, b = vanilla.getpixel(px), frosted.getpixel(px)
            col = _in_game(b) if sum(abs(p - q) for p, q in zip(a[:3], b[:3])) > 24 else a[:3]
            model.quad((x0, 0, z0), (x0 + 1 / n, 0, z0), (x0 + 1 / n, 0, z0 + 1 / n), (x0, 0, z0 + 1 / n), col)


def cold_preview_art(size=400):
    from PIL import Image as I
    work = ART_WORK
    tex = os.path.join(ROOT, "unity", "Cold", "Texture")
    sheet_v = I.open(os.path.join(work, "FloorDiffuseSheet.png")).convert("RGB")
    sheet_f = I.open(os.path.join(tex, "phrontisteries_cold_floor_sheet.png")).convert("RGB")
    c = sheet_v.size[0] // 4

    def cell(img, x, y):                       # sheet square by the game's 1-based offset from bottom-left
        return img.crop(((x - 1) * c, (4 - y) * c, x * c, (5 - y) * c))

    m = model3d.Model()
    floors = [  # (vanilla texture, frosted texture, tiling) for the 2x2 patch
        (cell(sheet_v, 2, 1), cell(sheet_f, 2, 1), 0.6),                                   # clay brick
        (cell(sheet_v, 1, 2), cell(sheet_f, 1, 2), 0.6),                                   # limestone block
        (I.open(os.path.join(work, "painted_clay_tile_diffuse.png")).convert("RGB"),
         I.open(os.path.join(tex, "phrontisteries_cold_clay_decorative_floor_albedo.png")).convert("RGB"), 0.25),
        (I.open(os.path.join(work, "marble_floor_diffuse.png")).convert("RGB"),
         I.open(os.path.join(tex, "phrontisteries_cold_marble_decorative_floor_albedo.png")).convert("RGB"), 0.25),
    ]
    for k, (v, f, t) in enumerate(floors):
        _floor_tile(m, (-1 + k % 2, -1 + k // 2), v, f, t)
    # the game's shelf model with the Cold Shelf's frosted texture, in its in-game blue-grey
    shelf_tex = I.open(os.path.join(tex, "phrontisteries_cold_shelf_albedo.png")).convert("RGB")
    TW, TH = shelf_tex.size
    V, T = [], []
    for line in open(os.path.join(work, "shelf.obj")):
        p = line.split()
        if not p:
            continue
        if p[0] == "v":
            V.append((-float(p[1]) + SHELF_AT[0], float(p[2]) + 0.02, float(p[3]) + SHELF_AT[1]))
        elif p[0] == "vt":
            T.append((float(p[1]), float(p[2])))
        elif p[0] == "f":
            idx = [tuple(int(q) - 1 for q in x.split("/")[:2]) for x in p[1:]]
            for i in range(1, len(idx) - 1):
                tri = [idx[0], idx[i], idx[i + 1]]
                u = sum(T[t][0] for _, t in tri) / 3; vv = sum(T[t][1] for _, t in tri) / 3
                col = _in_game(shelf_tex.getpixel((min(TW - 1, int(u * TW)), min(TH - 1, int((1 - vv) * TH)))))
                m.tri(V[tri[0][0]], V[tri[2][0]], V[tri[1][0]], col)
    body = model3d.rasterize(m, size, pitch=33, margin=0.04)
    # the renderer's violet shadow light turns blue-grey lavender: put frost blues back on the Cold hue
    import colorsys
    px = body.load()
    for yy in range(body.height):
        for xx in range(body.width):
            r, g, b, a = px[xx, yy]
            if a:
                h, l, s_ = colorsys.rgb_to_hls(r / 255, g / 255, b / 255)
                if 0.55 <= h <= 0.80 and s_ > 0.08:
                    nr, ng, nb = colorsys.hls_to_rgb(FROST_HUE, l, min(s_, 0.40))
                    px[xx, yy] = (round(nr * 255), round(ng * 255), round(nb * 255), a)
    shadow = Image.new("RGBA", body.size, (0, 0, 0, 0))
    shadow.paste((0, 0, 0, 140), (0, 0), body.split()[3])
    out = Image.new("RGBA", body.size, (0, 0, 0, 0))
    out.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(size / 40)), (0, 0))
    out.alpha_composite(body)
    return out


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
    "Cold": ("Cold", ["Cold Shelf: actively cooled food storage, 10 piles.", "Cold Floors: every floor material, frost-patterned, in a dedicated build group.", "Lowest two temperature thresholds raised by 1°."],
             cold_preview_art, (36, 70, 104), (14, 26, 44)),
    "Fish_Farming": ("Fish Farming", ["3×3 fish farm producing trout, pike and eel.", "Inputs: dung, vegetables or animal feed.", "Unlocked by the Barrel Making research."],
                     lambda: render_art(models.fish_farm, "building", 400), (30, 82, 96), (12, 32, 40)),
    "Fermenting Apple Cider": ("Apple Cider", ["Fermentation station recipe: apple cider.", "Ferments from apples, the same way as mash."],
                               lambda: render_art(models.fermenting_apple_cider, "item", 400), (110, 52, 34), (40, 18, 12)),
    "Better_Animals": ("Better Animals", ["All animals can be tamed, penned and trained, and can haul and fight.", "Higher hauling capacity; streamlined diets.", "Cats hunt vermin."],
                       lambda: render_art(models.animal_pen, "building", 400), (78, 92, 46), (28, 34, 16)),
    "FasterRegionTravel": ("Faster Region Travel", ["Caravan travel on the region map is 100× faster."],
                           lambda: render_art(models.caravan_cart, "building", 400), (120, 88, 42), (44, 30, 14)),
    "Fine_Clothing_Worker": ("Fine Clothing Worker", ["Superior and Flawless apparel improve work, movement, rest and combat."],
                             lambda: render_art(models.fine_tunic, "building", 400), (74, 46, 104), (26, 16, 40)),
    "More_Prisoners": ("More Prisoners", ["Higher raider surrender chance.", "Merchants stock more prisoners."],
                       lambda: render_art(models.surrender_flag, "building", 400), (70, 70, 76), (24, 24, 28)),
    "Brokerastered": ("Brokerastered", ["Broker role: better trading, bargaining and negotiation.", "Faster, higher-yield mining; preferred work: trading, crafting, mining and art."],
                      lambda: render_art(models.broker_scale, "building", 400), (96, 74, 30), (34, 24, 10)),
    "More_Creation_Points": ("More Creation Points", ["Settler creation: up to 1000 points, 40 perks and 20 passions."],
                      lambda: render_art(models.creation_book, "building", 400), (70, 60, 96), (22, 18, 34)),
    # "Mushroom Cropfield" and "Heavy Crossbow Sniper" keep their own hand-made previews.
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
