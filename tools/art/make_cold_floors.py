# SPDX-License-Identifier: MIT  (Copyright (c) 2026 phrontisteries; see LICENSE)
"""Cold Floors: frosted copies of every floor texture in the game.

For each floor, the texture's elements (planks, flagstones, blocks, bricks, tiles, triangles, panels,
strands or bar segments) are found, and the largest set with no two elements touching is frosted,
spread as evenly as possible. Textures repeat across the floor, so elements that run off one edge
continue on the other and "touching" is checked across the edges too.

    pip install numpy scipy networkx pillow
    python make_cold_floors.py <work_dir> <out_dir> [#colour] [preview.png]

work_dir holds the game textures, exported with extract_game_texture.py:
FloorDiffuseSheet, painted_stone_tile_diffuse, painted_clay_tile_diffuse, marble_floor_diffuse,
plus floors.json (each floor's texture and shader settings, from BaseBuildingRepository.json; see
write_floor_info below).

Outputs in out_dir:
  phrontisteries_cold_floor_sheet.png        the game's 4x4 floor sheet, each floor's square frosted
  phrontisteries_cold_<floor>_albedo.png     frosted copies of the decorative floors' own textures

Floors on the sheet are tinted by the shader (_FloorColorMultiply / _FloorColorAdd); that tint is
baked into the frosted copy, so the Cold Floors set it to plain white / black.
#colour is the average texture colour of a frosted element (#948B83 lands on the Cold Shelf's
frosted boards in game, measured from in-game screenshots).
"""
import itertools
import json
import os
import random
import sys

import networkx as nx
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

# How each floor's elements are found.
#   lum:      elements are lighter than the grout between them
#   tiles:    grout is long straight dark lines; tiles are what lies between; only tiles of at least
#             min_frost pixels are frosted (tiny mosaic squares stay as they are)
#   triangles: a grid of squares, each split along one diagonal (marble)
#   panels:   a grid of square panels (wicker mesh)
#   strands:  long horizontal and vertical strands (wicker)
#   segments: bars between crossings of a lattice (metal grate)
METHODS = {
    "wood_floor":              dict(kind="lum", pct=22, min_size=300, grow=7, seam=5),
    "limestone_floor":         dict(kind="lum", min_size=300),
    "limestone_block_floor":   dict(kind="lum", min_size=300),
    "clay_brick_floor":        dict(kind="lum", min_size=300),
    "stone_decorative_floor":  dict(kind="tiles", line=30, min_size=60, min_frost=700),
    "clay_decorative_floor":   dict(kind="tiles", line=30, min_size=60, min_frost=700),
    "marble_decorative_floor": dict(kind="triangles", grid=8),
    "wicker_mesh_floor":       dict(kind="panels", grid=4),
    "wicker_floor":            dict(kind="strands", length=70, min_size=400),
    "metal_grated_platform":   dict(kind="segments", length=25, grow=6, min_size=150),
}
LUMA = np.array([0.299, 0.587, 0.114])


def hex_rgb(h, default):
    h = (h or "").strip()
    if len(h) < 7:
        return np.array(default, float)
    return np.array([int(h[i:i + 2], 16) for i in (1, 3, 5)], float) / 255


def tiled_components(mask, min_size):
    """Connected regions of mask on the repeating texture: each returned once, wrapped back in."""
    h, w = mask.shape
    lab, n = ndimage.label(np.tile(mask, (3, 3)))
    ids = np.arange(1, n + 1)
    sizes = ndimage.sum(np.ones_like(lab), lab, ids)
    centres = ndimage.center_of_mass(np.ones_like(lab), lab, ids)
    objs = ndimage.find_objects(lab)
    out = []
    for i, s, (cy, cx) in zip(ids, sizes, centres):
        if s >= min_size and h <= cy < 2 * h and w <= cx < 2 * w:
            sl = objs[i - 1]
            ys, xs = np.where(lab[sl] == i)
            ys = ys + sl[0].start; xs = xs + sl[1].start
            m = np.zeros((h, w), bool)
            m[(ys - h) % h, (xs - w) % w] = True
            if m.sum() < 0.5 * h * w:
                out.append(m)
    return out


def grow_to_seams(parts, lum, solid, grow, seam):
    """Grow each element up to `grow` pixels into its own shaded edge, stopping at the dark seams
    (lum <= seam) and at other elements. Works across the texture's edges."""
    if not parts or grow <= 0:
        return parts
    h, w = lum.shape
    label = np.zeros((h, w), int)
    for i, p in enumerate(parts):
        label[p] = i + 1
    big = np.tile(label, (3, 3))
    dist, (iy, ix) = ndimage.distance_transform_edt(big == 0, return_indices=True)
    near = big[iy, ix][h:2 * h, w:2 * w]
    ok = (dist[h:2 * h, w:2 * w] <= grow) & (lum > seam) & solid & (label == 0)
    label = np.where(ok, near, label)
    return [label == i + 1 for i in range(len(parts))]


def elements(rgb, alpha, method):
    h, w = alpha.shape
    solid = alpha > 0.5
    lum = rgb @ LUMA
    k = method["kind"]
    if k == "lum":
        if "pct" in method:                                         # faint seams (wood): a fixed share is grout
            mask = (lum > np.percentile(lum[solid], method["pct"])) & solid
        else:
            lo, mid = np.percentile(lum[solid], [5, 50])
            mask = (lum > (lo + mid) / 2) & solid                  # halfway between grout and element
        mask = ndimage.binary_erosion(np.tile(mask, (3, 3)), iterations=1)[h:2 * h, w:2 * w]
        parts = tiled_components(mask, method["min_size"])
        return grow_to_seams(parts, lum, solid, method.get("grow", 4), np.percentile(lum[solid], method.get("seam", 6)))
    if k == "tiles":
        # grout = long straight dark lines (painted patterns do not make those); tiles = what lies between
        lo, mid = np.percentile(lum[solid], [5, 50])
        dark = np.tile(lum < lo + (mid - lo) * method.get("dark", 0.5), (3, 3))
        L = method["line"]
        grout = ndimage.binary_opening(dark, structure=np.ones((1, L))) | ndimage.binary_opening(dark, structure=np.ones((L, 1)))
        grout = ndimage.binary_dilation(grout, iterations=1)[h:2 * h, w:2 * w]
        return tiled_components(~grout & solid, method["min_size"])
    if k == "triangles":
        n = method["grid"]; c = h // n
        yy, xx = np.mgrid[0:c, 0:c]
        parts = []
        for gy in range(n):
            for gx in range(n):
                sl = (slice(gy * c, gy * c + c), slice(gx * c, gx * c + c))
                cell = rgb[sl]
                # the split runs along whichever diagonal has the bigger colour difference across it
                a1, b1 = yy > xx, yy < xx
                a2, b2 = (yy + xx) > c, (yy + xx) < c
                d1 = np.abs(cell[a1].mean(0) - cell[b1].mean(0)).sum()
                d2 = np.abs(cell[a2].mean(0) - cell[b2].mean(0)).sum()
                halves = (yy > xx + 2, yy < xx - 2) if d1 >= d2 else ((yy + xx) > c + 2, (yy + xx) < c - 2)
                for half in halves:
                    m = np.zeros((h, w), bool)
                    m[sl] = ndimage.binary_erosion(half, iterations=1)
                    parts.append(m)
        return parts
    if k == "panels":
        n = method["grid"]; c = h // n
        parts = []
        for gy in range(n):
            for gx in range(n):
                m = np.zeros((h, w), bool)
                m[gy * c + 3:gy * c + c - 3, gx * c + 3:gx * c + c - 3] = True
                parts.append(m & solid)
        return parts
    if k == "strands":
        L = method["length"]
        hor = ndimage.binary_opening(np.tile(solid, (3, 3)), structure=np.ones((1, L)))[h:2 * h, w:2 * w]
        ver = ndimage.binary_opening(np.tile(solid, (3, 3)), structure=np.ones((L, 1)))[h:2 * h, w:2 * w]
        return tiled_components(hor & ~ver, method["min_size"]) + tiled_components(ver & ~hor, method["min_size"])
    if k == "segments":
        L = method["length"]
        hor = ndimage.binary_opening(np.tile(solid, (3, 3)), structure=np.ones((1, L)))[h:2 * h, w:2 * w]
        ver = ndimage.binary_opening(np.tile(solid, (3, 3)), structure=np.ones((L, 1)))[h:2 * h, w:2 * w]
        cross = ndimage.binary_dilation(np.tile(hor & ver, (3, 3)), iterations=method["grow"])[h:2 * h, w:2 * w]
        return tiled_components((hor | ver) & ~cross, method["min_size"])
    raise ValueError(k)


def touching(parts, reach):
    """Graph of elements that touch (within `reach` pixels), on the repeating texture."""
    h, w = parts[0].shape
    label = np.zeros((h, w), int)
    for i, p in enumerate(parts):
        label[p] = i + 1
    big = np.tile(label, (3, 3))
    g = nx.Graph()
    g.add_nodes_from(range(len(parts)))
    for i, p in enumerate(parts):
        ys, xs = np.where(p)
        # unwrap the element around its first pixel so it is one piece, then look around it in the tiled labels
        y0, x0 = ys[0], xs[0]
        ys = np.where(ys - y0 > h // 2, ys - h, np.where(ys - y0 < -h // 2, ys + h, ys)) + h
        xs = np.where(xs - x0 > w // 2, xs - w, np.where(xs - x0 < -w // 2, xs + w, xs)) + w
        top, left = ys.min() - reach, xs.min() - reach
        win = np.zeros((ys.max() - ys.min() + 2 * reach + 1, xs.max() - xs.min() + 2 * reach + 1), bool)
        win[ys - top, xs - left] = True
        win = ndimage.binary_dilation(win, structure=np.ones((2 * reach + 1,) * 2))
        near = big[top:top + win.shape[0], left:left + win.shape[1]][win]
        for j in np.unique(near):
            if j and j - 1 != i:
                g.add_edge(i, j - 1)
    return g


def most_spread(g, parts, candidates, tries=800, seed=7):
    """Largest set of candidate elements with no two touching; among those, the most evenly spread."""
    h, w = parts[0].shape
    centres = [ndimage.center_of_mass(p) for p in parts]

    def spacing(s):
        best = float("inf")
        for a, b in itertools.combinations(s, 2):
            dy = abs(centres[a][0] - centres[b][0]); dx = abs(centres[a][1] - centres[b][1])
            best = min(best, min(dx, w - dx) ** 2 + min(dy, h - dy) ** 2)
        return best

    sub = g.subgraph(candidates)
    if len(candidates) <= 40:                                       # exact
        cliques = list(nx.find_cliques(nx.complement(sub)))
        size = max(len(c) for c in cliques)
        return max((c for c in cliques if len(c) == size), key=spacing)
    rng = random.Random(seed)                                       # large: randomised greedy, keep the best
    best, best_key = None, None
    for _ in range(tries):
        order = list(candidates); rng.shuffle(order)
        order.sort(key=lambda n: sub.degree(n) + rng.random())     # fewer neighbours first
        chosen, blocked = [], set()
        for n in order:
            if n not in blocked:
                chosen.append(n); blocked.add(n); blocked.update(sub.neighbors(n))
        key = (len(chosen), spacing(chosen) if len(chosen) < 60 else 0)
        if best_key is None or key > best_key:
            best, best_key = chosen, key
    return best


def frost(rgb, alpha, parts, chosen, colour, lift=1.15):
    lum = rgb @ LUMA
    m = np.zeros(alpha.shape, bool)
    for i in chosen:
        m |= parts[i]
    base = max(lum[m].mean(), 1e-3)
    shade = lum / base
    # on grey materials the frost colour is close to the stone itself; keep its hue but make it at
    # least `lift` lighter than the elements it covers, so frosted elements always read as frost
    c = colour * max(1.0, lift * base / float(colour @ LUMA))
    frosted = np.clip(c[None, None, :] * shade[..., None], 0, 1)
    soft = ndimage.gaussian_filter(m.astype(float), 0.8)[..., None]
    return rgb * (1 - soft) + frosted * soft


def write_floor_info(base_building_repository, out_json):
    rep = json.load(open(base_building_repository, encoding="utf-8-sig"))["repository"]
    info = {}
    for m in rep:
        if m.get("buildingSubCategoryUI") != "SubCtgFloor":
            continue
        slots = [l for l in m["variationLists"] if l["name"] == "list02"][0]["variations"][0]["slots"]
        p = {s["shaderParam"]["variableName"]: s["shaderParam"] for s in slots if s.get("slotType") == "ShaderParam"}
        t = {s["slot"]: s.get("value") for s in slots if s.get("slotType") == "Texture"}
        info[m["id"]] = dict(albedo=t["floorAlbedo"], normal=t["floorNormal"],
                             size=p["_FloorSheetSize"]["vector2Value"], offset=p["_FloorSheetOffset"]["vector2Value"],
                             multiply=p["_FloorColorMultiply"]["colorValue"], add=p["_FloorColorAdd"]["colorValue"])
    json.dump(info, open(out_json, "w"), indent=1)
    return info


def main(work, out, colour="#948B83", preview=None):
    info = json.load(open(os.path.join(work, "floors.json")))
    colour = hex_rgb(colour, (0.58, 0.55, 0.51))
    sheet = np.asarray(Image.open(os.path.join(work, "FloorDiffuseSheet.png")).convert("RGBA")).astype(float) / 255
    cell = sheet.shape[0] // 4
    new_sheet = sheet.copy()
    previews = []
    for fid, method in METHODS.items():
        f = info[fid]
        if f["albedo"]:
            src = np.asarray(Image.open(os.path.join(work, f["albedo"] + ".png")).convert("RGBA")).astype(float) / 255
            mul, add = np.ones(3), np.zeros(3)
        else:
            cx = int(f["offset"]["x"]) - 1; cy = 4 - int(f["offset"]["y"])          # offsets count from 1, bottom-left
            src = sheet[cy * cell:(cy + 1) * cell, cx * cell:(cx + 1) * cell]
            mul, add = hex_rgb(f["multiply"], (1, 1, 1)), hex_rgb(f["add"], (0, 0, 0))
        rgb = np.clip(src[..., :3] * mul + add, 0, 1)                               # bake the floor's tint
        alpha = src[..., 3]
        parts = elements(rgb, alpha, method)
        g = touching(parts, reach=method.get("reach", 10))
        cand = [i for i, p in enumerate(parts) if p.sum() >= method.get("min_frost", 0)]
        chosen = most_spread(g, parts, cand)
        res = np.dstack([frost(rgb, alpha, parts, chosen, colour), alpha])
        print(f"{fid}: {len(parts)} elements, {len(cand)} frostable, {len(chosen)} frosted (none touching)", flush=True)
        if f["albedo"]:
            Image.fromarray((res * 255).round().astype("uint8")).save(
                os.path.join(out, f"phrontisteries_cold_{fid}_albedo.png"))
        else:
            new_sheet[cy * cell:(cy + 1) * cell, cx * cell:(cx + 1) * cell] = res
        previews.append((fid, res))
    Image.fromarray((new_sheet * 255).round().astype("uint8")).save(os.path.join(out, "phrontisteries_cold_floor_sheet.png"))
    if preview:
        size = 300
        img = Image.new("RGB", (5 * (size + 10) + 10, 2 * (size + 30) + 10), (30, 30, 36))
        d = ImageDraw.Draw(img)
        for k, (fid, res) in enumerate(previews):
            t = np.tile(res, (2, 2, 1))
            bg = np.ones_like(t[..., :3]) * np.array([0.33, 0.30, 0.27])            # ground under see-through floors
            rgb = t[..., :3] * t[..., 3:] + bg * (1 - t[..., 3:])
            x = 10 + (k % 5) * (size + 10); y = 30 + (k // 5) * (size + 30)
            img.paste(Image.fromarray((rgb * 255).astype("uint8")).resize((size, size)), (x, y))
            d.text((x, y - 18), fid, fill=(235, 235, 235))
        img.save(preview)


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "--info":
        write_floor_info(sys.argv[2], sys.argv[3])
    else:
        main(*sys.argv[1:5])
