# Graphics

Branch `1.2.17` explores giving the mods their own art. Everything here is drawn from scratch (no game assets), so it is covered by the repo's MIT license.

## What the game supports

Per Foxy Voxel's [modding guide](https://foxyvoxel.io/2025/03/13/modding-guide-policy/):

| Kind | Where in the mod | Format |
|---|---|---|
| Item/building icons | `Data\Sprites\<name>.png` | 64×64 PNG; `<name>` must equal the model's `iconPath` |
| Workshop / Mods-menu picture | `Preview.png` (mod root) | 640×360 or 1280×720, under 1 MB |
| 3D meshes, textures | `Data\AddressableAssets\` | FBX (1 unit = 1 m, Y up) and PNG, exported as Unity Addressables (needs the Unity editor; see the guide) |

## What is in this branch

| Mod | Icons (`iconPath`) | Preview |
|---|---|---|
| Cold | `phrontisteries_cold_shelf`, `phrontisteries_cold_floor` | new |
| Fermenting Apple Cider | `phrontisteries_fermenting_apple_cider` (resource and recipe) | new |
| Fish Farming | `phrontisteries_fish_farm` | new |
| Better_Animals, Faster Region Travel, Fine Clothing Worker, More Prisoners | (no new items) | new |
| Mushroom Cropfield | (uses the game's `mushroom`) | keeps its existing hand-made preview |

Icon names are prefixed with `phrontisteries_` so a mod sprite can never replace a vanilla icon of the same name.

Before this branch, seven mods shipped the game's generic `PreviewMod.png` (Foxy Voxel's art). The new previews replace it, so every file in those mods is our own.

## How it is built

- `tools\art\make_art.py` draws everything (Python 3 + Pillow: `pip install pillow`, then `python tools\art\make_art.py`). It writes:
  - `recipes\<Mod>\Sprites\<iconPath>.png`
  - `recipes\<Mod>\Preview.png`
- `MakeMod.ps1` copies `recipes\<Mod>\Sprites\*.png` into the mod's `Data\Sprites\`, and `recipes\<Mod>\Preview.png` over the mod's `Preview.png`.
- Recipes point at the sprites: `iconPath` in `recipes\Cold.ps1` and in the `"#template"` entries of the source recipes.

You can also drop hand-made PNGs into `recipes\<Mod>\Sprites\` and skip the script.

## To check in game

- [ ] The new icons appear in the build menu (Cold Shelf, Cold Floor, Fish Farm) and on the cider resource and recipe.
- [ ] Icons look right at the game's UI scale and on its dark and light panels.
- [ ] Previews show in the in-game Mods menu and on the Workshop page.
- [ ] Nothing else changed: the Cold Shelf still shows its 10 piles, and saves from 1.0.2.17 still load.

## Ideas for next steps

- Hand-painted icons closer to the game's own style (the current ones are flat vector art).
- A distinct look for the Cold Shelf and Cold Floor in the world (a blue tint or frost), through a recolored texture or mesh variation. The mod JSON already supports `variationLists` with texture and shader-parameter slots, which might allow a tint without a new mesh. Worth testing before reaching for Unity.
- Custom meshes through Addressables, if a tint is not enough.
