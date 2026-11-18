# SPDX-License-Identifier: MIT  (Copyright (c) 2026 phrontisteries; see LICENSE)
"""Export textures (and optionally meshes as .obj) from the game's Addressables bundle by name.

    pip install UnityPy
    python extract_game_texture.py "<Going Medieval>/Going Medieval_Data/StreamingAssets/aa/StandaloneWindows64" <out_dir> base_texture_png shelf

Used for the Cold Shelf: the shelf model is "shelf" and its texture "base_texture_png" (see the
building's variationLists in BaseBuildingRepository.json). The exported files are the game's art:
use them for your own mod only, do not redistribute them as-is.
"""
import os
import sys

import UnityPy


def main(bundle_dir, out_dir, names):
    os.makedirs(out_dir, exist_ok=True)
    want = set(names)
    for f in sorted(os.listdir(bundle_dir)):
        if not f.endswith(".bundle"):
            continue
        env = UnityPy.load(os.path.join(bundle_dir, f))
        for obj in env.objects:
            if obj.type.name not in ("Texture2D", "Mesh"):
                continue
            d = obj.read()
            if d.m_Name not in want:
                continue
            if obj.type.name == "Texture2D":
                d.image.save(os.path.join(out_dir, d.m_Name + ".png"))
            else:
                with open(os.path.join(out_dir, d.m_Name + ".obj"), "w") as fh:
                    fh.write(d.export())
            print("exported", obj.type.name, d.m_Name)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3:])
