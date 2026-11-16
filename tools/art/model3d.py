# SPDX-License-Identifier: MIT  (Copyright (c) 2026 phrontisteries; see LICENSE)
"""Tiny low-poly modeller + software renderer for Going Medieval-style art.

* Build models from boxes, cylinders, barrels, cones and spheres (units: metres, Y up).
* render_icon(): the game's icon look - three-quarter view, warm key light, violet
  shadows, cyan rim; "building" icons sit on an olive tile with a grid and glow,
  "item" icons get a thick white outline on transparency.
* export_obj(): the same model as an .obj + palette .png for Foxy Voxel's Unity
  modding project (Meshes -> Mesh folder, palette -> Texture folder).

Only numpy and Pillow are needed.
"""
import math
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

# ------------------------------------------------------------------ model building
class Model:
    def __init__(self):
        self.tris = []      # (v0, v1, v2) as np arrays
        self.cols = []      # (r, g, b) 0..255 per triangle

    def add(self, other, offset=(0, 0, 0)):
        o = np.array(offset, float)
        for t, c in zip(other.tris, other.cols):
            self.tris.append(tuple(v + o for v in t)); self.cols.append(c)
        return self

    def tri(self, a, b, c, col):
        self.tris.append((np.array(a, float), np.array(b, float), np.array(c, float))); self.cols.append(col)

    def quad(self, a, b, c, d, col):
        self.tri(a, b, c, col); self.tri(a, c, d, col)

    def box(self, center, size, col, top=None, side=None):
        cx, cy, cz = center; sx, sy, sz = (s / 2 for s in size)
        p = [(cx + x * sx, cy + y * sy, cz + z * sz) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)]
        P = lambda i, j, k: p[i * 4 + j * 2 + k]
        top = top or col; side = side or col
        self.quad(P(0, 1, 0), P(0, 1, 1), P(1, 1, 1), P(1, 1, 0), top)      # +Y
        self.quad(P(0, 0, 0), P(1, 0, 0), P(1, 0, 1), P(0, 0, 1), col)      # -Y
        self.quad(P(0, 0, 1), P(1, 0, 1), P(1, 1, 1), P(0, 1, 1), side)     # +Z
        self.quad(P(0, 0, 0), P(0, 1, 0), P(1, 1, 0), P(1, 0, 0), side)     # -Z
        self.quad(P(1, 0, 0), P(1, 1, 0), P(1, 1, 1), P(1, 0, 1), side)     # +X
        self.quad(P(0, 0, 0), P(0, 0, 1), P(0, 1, 1), P(0, 1, 0), side)     # -X
        return self

    def lathe(self, center, profile, col, seg=16, cap_top=None, cap_bottom=None, cols=None, axis="y"):
        """Revolve [(radius, height), ...] around the axis. cols: optional per-segment colours."""
        cx, cy, cz = center
        def pt(r, h, a):
            u, v = r * math.cos(a), r * math.sin(a)
            if axis == "y": return (cx + u, cy + h, cz + v)
            if axis == "x": return (cx + h, cy + u, cz + v)
            return (cx + u, cy + v, cz + h)
        for s in range(seg):
            a0, a1 = 2 * math.pi * s / seg, 2 * math.pi * (s + 1) / seg
            c = cols[s % len(cols)] if cols else col
            for (r0, h0), (r1, h1) in zip(profile, profile[1:]):
                self.quad(pt(r0, h0, a0), pt(r1, h1, a0), pt(r1, h1, a1), pt(r0, h0, a1), c)
            if cap_top is not None:
                r, h = profile[-1]; self.tri(pt(0, h, 0), pt(r, h, a1), pt(r, h, a0), cap_top)
            if cap_bottom is not None:
                r, h = profile[0]; self.tri(pt(0, h, 0), pt(r, h, a0), pt(r, h, a1), cap_bottom)
        return self

    def cylinder(self, center, r, h, col, seg=16, top=None, axis="y", cols=None):
        return self.lathe(center, [(r, 0), (r, h)], col, seg, cap_top=top or col, cap_bottom=col, axis=axis, cols=cols)

    def barrel(self, center, r, h, wood, hoop, seg=14, top=None, axis="y", lid=True):
        """Staved barrel: bulging body, alternating stave shades, dark hoops."""
        prof = [(r * 0.84, 0), (r * 0.95, h * 0.2), (r, h * 0.5), (r * 0.95, h * 0.8), (r * 0.84, h)]
        light, dark = wood, tuple(int(c * 0.82) for c in wood)
        self.lathe(center, prof, wood, seg, cap_top=(top or tuple(int(c * 0.9) for c in wood)) if lid else None,
                   cap_bottom=dark, cols=[light, dark], axis=axis)
        for t in (0.12, 0.88):     # hoops
            rr = [p for p in prof]
            hh = h * t
            rad = np.interp(hh, [p[1] for p in prof], [p[0] for p in prof]) + 0.012
            self.lathe(center, [(rad, hh - 0.035), (rad, hh + 0.035)], hoop, seg, axis=axis)
        return self

    def cone(self, center, r, h, col, seg=8):
        return self.lathe(center, [(r, 0), (0.001, h)], col, seg, cap_bottom=col)

    def sphere(self, center, r, col, seg=10, rings=6, stem=None):
        prof = [(r * math.sin(math.pi * i / rings) + 1e-4, -r * math.cos(math.pi * i / rings)) for i in range(rings + 1)]
        self.lathe(center, prof, col, seg)
        if stem:
            self.box((center[0], center[1] + r + 0.02, center[2]), (0.015, 0.05, 0.015), stem)
        return self

    def bounds(self):
        pts = np.array([v for t in self.tris for v in t])
        return pts.min(0), pts.max(0)


# ------------------------------------------------------------------ rendering
KEY = np.array([-0.55, 0.75, 0.38]); KEY /= np.linalg.norm(KEY)
KEY_COL = np.array([1.30, 1.02, 0.70])        # warm key
AMB_COL = np.array([0.30, 0.22, 0.50])        # violet shadow
RIM_COL = np.array([0.35, 0.85, 0.95])        # cyan rim


def _camera(yaw=-38, pitch=33):
    y, p = math.radians(yaw), math.radians(pitch)
    ry = np.array([[math.cos(y), 0, math.sin(y)], [0, 1, 0], [-math.sin(y), 0, math.cos(y)]])
    rx = np.array([[1, 0, 0], [0, math.cos(p), -math.sin(p)], [0, math.sin(p), math.cos(p)]])
    return rx @ ry


def projection(model, size, yaw, pitch, margin, extra=()):
    """Camera rotation, scale and centre that frame the model (plus extra world points)."""
    R = _camera(yaw, pitch)
    pts = [R @ v for t in model.tris for v in t] + [R @ np.array(e, float) for e in extra]
    pts = np.array(pts); lo, hi = pts.min(0), pts.max(0)
    span = max(hi[0] - lo[0], hi[1] - lo[1])
    return R, size * (1 - 2 * margin) / span, ((lo[0] + hi[0]) / 2, (lo[1] + hi[1]) / 2)


def to_screen(points, R, scale, cxy, size):
    out = []
    for p in points:
        q = R @ np.array(p, float)
        out.append(((q[0] - cxy[0]) * scale + size / 2, size / 2 - (q[1] - cxy[1]) * scale))
    return out


def rasterize(model, size, yaw=-38, pitch=33, margin=0.12, ss=4, fit=None, proj=None):
    """Returns RGBA float image (size x size) of the model, shaded in the game's icon lighting."""
    W = size * ss
    R, scale, cxy = proj if proj else projection(model, size, yaw, pitch, margin)
    scale = scale * ss
    tris = np.array([[R @ v for v in t] for t in model.tris])  # (n,3,3)
    cols = np.array(model.cols, float) / 255.0
    sx = (tris[:, :, 0] - cxy[0]) * scale + W / 2
    sy = W / 2 - (tris[:, :, 1] - cxy[1]) * scale
    sz = tris[:, :, 2]
    # normals in world space for lighting
    world = np.array([[np.array(v) for v in t] for t in model.tris])
    n = np.cross(world[:, 1] - world[:, 0], world[:, 2] - world[:, 0])
    nl = np.linalg.norm(n, axis=1, keepdims=True); nl[nl == 0] = 1; n = n / nl
    ncam = (R @ n.T).T
    n = np.where((ncam[:, 2:3] < 0), -n, n)                   # two-sided: face the camera
    ncam = np.where((ncam[:, 2:3] < 0), -ncam, ncam)
    diff = np.clip(n @ KEY, 0, 1)[:, None]
    rim = (1 - np.clip(ncam[:, 2], 0, 1))[:, None] ** 2.2
    up = np.clip(n[:, 1], 0, 1)[:, None]
    shade = cols * (AMB_COL + KEY_COL * diff + 0.10 * up) + RIM_COL * rim * 0.35
    shade = np.clip(shade, 0, 1)

    color = np.zeros((W, W, 3)); alpha = np.zeros((W, W)); zbuf = np.full((W, W), -1e9)
    for i in range(len(tris)):
        xs, ys, zs = sx[i], sy[i], sz[i]
        x0, x1 = int(max(0, math.floor(xs.min()))), int(min(W - 1, math.ceil(xs.max())))
        y0, y1 = int(max(0, math.floor(ys.min()))), int(min(W - 1, math.ceil(ys.max())))
        if x1 < x0 or y1 < y0: continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        d = (ys[1] - ys[2]) * (xs[0] - xs[2]) + (xs[2] - xs[1]) * (ys[0] - ys[2])
        if abs(d) < 1e-9: continue
        w0 = ((ys[1] - ys[2]) * (gx - xs[2]) + (xs[2] - xs[1]) * (gy - ys[2])) / d
        w1 = ((ys[2] - ys[0]) * (gx - xs[2]) + (xs[0] - xs[2]) * (gy - ys[2])) / d
        w2 = 1 - w0 - w1
        inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6)
        if not inside.any(): continue
        z = w0 * zs[0] + w1 * zs[1] + w2 * zs[2]
        sub = zbuf[y0:y1 + 1, x0:x1 + 1]
        win = inside & (z > sub)
        sub[win] = z[win]
        color[y0:y1 + 1, x0:x1 + 1][win] = shade[i]
        alpha[y0:y1 + 1, x0:x1 + 1][win] = 1
    img = np.dstack([color, alpha])
    pil = Image.fromarray((img * 255).astype(np.uint8), "RGBA")
    return pil.resize((size, size), Image.LANCZOS)


def tile_background(size, R, scale, cxy, footprint=(0.5, 0.5)):
    """Olive ground with the game's light tile grid (drawn on real 1 m tiles) and a cyan glow under the object."""
    W = size * 4
    img = Image.new("RGBA", (W, W))
    d = ImageDraw.Draw(img)
    for r in range(W, 0, -4):                              # radial olive gradient
        t = r / W
        d.ellipse((W / 2 - r * 0.9, W / 2 - r * 0.9, W / 2 + r * 0.9, W / 2 + r * 0.9),
                  fill=(int(62 + 48 * (1 - t)), int(66 + 50 * (1 - t)), int(4 + 8 * (1 - t)), 255))
    S = lambda pts: [(x * 4, y * 4) for x, y in to_screen(pts, R, scale, cxy, size)]
    glow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    fx, fz = footprint
    fx, fz = fx * 1.25, fz * 1.25
    ImageDraw.Draw(glow).polygon(S([(-fx, 0, -fz), (fx, 0, -fz), (fx, 0, fz), (-fx, 0, fz)]), fill=(80, 235, 225, 235))
    img = Image.alpha_composite(img, glow.filter(ImageFilter.GaussianBlur(W / 11)))
    grid = Image.new("RGBA", (W, W), (0, 0, 0, 0)); g = ImageDraw.Draw(grid)
    for k in range(-4, 5):                                 # tile edges at x,z = k + 0.5
        e = k + 0.5
        g.line(S([(e, 0, -6), (e, 0, 6)]), fill=(226, 232, 172, 215), width=max(3, W // 48))
        g.line(S([(-6, 0, e), (6, 0, e)]), fill=(226, 232, 172, 215), width=max(3, W // 48))
    img = Image.alpha_composite(img, grid.filter(ImageFilter.GaussianBlur(W / 300)))
    vign = Image.new("L", (W, W), 0)
    ImageDraw.Draw(vign).ellipse((-W * 0.25, -W * 0.25, W * 1.25, W * 1.25), fill=255)
    img = Image.composite(img, Image.new("RGBA", (W, W), (36, 38, 0, 255)), vign.filter(ImageFilter.GaussianBlur(W / 7)))
    return img.resize((size, size), Image.LANCZOS)


def outline(img, width, color=(255, 255, 255, 255)):
    """Thick outline around an RGBA render (the game's item-icon look)."""
    a = img.split()[3]
    grown = a.filter(ImageFilter.MaxFilter(width * 2 + 1)).filter(ImageFilter.GaussianBlur(width * 0.25))
    base = Image.new("RGBA", img.size, (0, 0, 0, 0))
    shadow = Image.new("RGBA", img.size, (0, 0, 0, 0)); shadow.paste((0, 0, 0, 110), (0, 0), grown)
    base = Image.alpha_composite(base, shadow.transform(img.size, Image.AFFINE, (1, 0, -1, 0, 1, -2)).filter(ImageFilter.GaussianBlur(width * 0.6)))
    ring = Image.new("RGBA", img.size, (0, 0, 0, 0)); ring.paste(color, (0, 0), grown)
    base = Image.alpha_composite(base, ring)
    return Image.alpha_composite(base, img)


def render_icon(model, kind, size=128, yaw=-38, pitch=33, margin=0.05, footprint=(0.5, 0.5), tile_fill=None, lift=0.0):
    """tile_fill: frame like the game's cropfield icons instead of fitting the model: the 1 m tile under
    the object spans this fraction of the icon width, centred on the point `lift` metres above it."""
    if kind == "item":
        pad = int(size * 0.08)
        body = rasterize(model, size - 2 * pad, yaw, pitch, margin=0.03)
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0)); canvas.alpha_composite(body, (pad, pad))
        return outline(canvas, max(2, size // 28))
    if tile_fill:
        R = _camera(yaw, pitch)
        c = R @ np.array((0.0, lift, 0.0))
        span = abs(math.cos(math.radians(yaw))) + abs(math.sin(math.radians(yaw)))   # tile width on screen
        proj = (R, size * tile_fill / span, (c[0], c[1]))
    else:
        proj = projection(model, size, yaw, pitch, margin)
    bg = tile_background(size, *proj, footprint=footprint)
    body = rasterize(model, size, yaw, pitch, proj=proj)
    return Image.alpha_composite(bg, body)


# ------------------------------------------------------------------ export for Unity
def export_obj(model, obj_path, png_path, texture_name, offset=(0, 0, 0), unity_mirror=True):
    """Writes the model as OBJ with UVs into a palette texture (one swatch per colour).

    offset: moves the model relative to the building's origin tile (multi-tile buildings are centred
    one or more tiles in from the origin). unity_mirror: Unity's OBJ importer negates X, so the file
    is pre-mirrored and the model arrives in Unity exactly as drawn.
    """
    palette = sorted(set(model.cols)); n = len(palette)
    cells = math.ceil(math.sqrt(n)); px = 8; T = cells * px
    tex = Image.new("RGB", (T, T), (255, 0, 255)); d = ImageDraw.Draw(tex)
    uv = {}
    for i, c in enumerate(palette):
        cx, cy = (i % cells) * px, (i // cells) * px
        d.rectangle((cx, cy, cx + px - 1, cy + px - 1), fill=c)
        uv[c] = ((cx + px / 2) / T, 1 - (cy + px / 2) / T)
    tex.save(png_path)
    lines = [f"# {texture_name} - generated by tools/art/model3d.py (MIT)", f"o {texture_name}"]
    vt_index = {c: i + 1 for i, c in enumerate(palette)}
    for c in palette: lines.append(f"vt {uv[c][0]:.5f} {uv[c][1]:.5f}")
    vi = 1
    ox, oy, oz = offset
    for t, c in zip(model.tris, model.cols):
        verts = [(v[0] + ox, v[1] + oy, v[2] + oz) for v in t]
        if unity_mirror:
            verts = [(-x, y, z) for x, y, z in verts][::-1]          # mirror X and keep faces pointing outward
        for x, y, z in verts: lines.append(f"v {x:.4f} {y:.4f} {z:.4f}")
        k = vt_index[c]
        lines.append(f"f {vi}/{k} {vi + 1}/{k} {vi + 2}/{k}")
        vi += 3
    with open(obj_path, "w", newline="\n") as f: f.write("\n".join(lines) + "\n")
    return len(model.tris), (T, T)
