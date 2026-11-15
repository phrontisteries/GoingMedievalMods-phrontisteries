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

| Mod | Icons (`iconPath`, 128×128) | In the world | Preview |
|---|---|---|---|
| Cold | `phrontisteries_cold_shelf`, `phrontisteries_cold_floor` | Cold Floor tinted cool blue (floor shader `_FloorColorMultiply` / `_FloorColorAdd`, no build needed). Frosted shelf model once built in Unity. | new |
| Fermenting Apple Cider | `phrontisteries_fermenting_apple_cider` (resource and recipe) | (resource) | new |
| Fish Farming | `phrontisteries_fish_farm` | Fish-tub model once built in Unity (until then the saltpeter-pit model) | new |
| Better_Animals, Faster Region Travel, Fine Clothing Worker, More Prisoners | (no new items) | | new |
| Mushroom Cropfield | (uses the game's `mushroom`) | | keeps its hand-made preview |

**Icons match the game's own:** like the vanilla icons, they are renders of 3D models at 128×128 with the same lighting (warm key, violet shadows, cyan rim). Buildings sit on the olive tile with the light grid and glow. Items have the thick white outline. The low-poly models are in `tools/art/models.py`, and the renderer is `tools/art/model3d.py`.

Icon names are prefixed with `phrontisteries_` so a mod sprite can never replace a vanilla icon of the same name.

Before this branch, seven mods shipped the game's generic `PreviewMod.png` (Foxy Voxel's art). The new previews replace it, so every file in those mods is our own.

## How it is built

- `tools\art\make_art.py` (Python 3 with `pip install pillow numpy`) writes:
  - `recipes\<Mod>\Sprites\<iconPath>.png`: icon renders
  - `recipes\<Mod>\Preview.png`: Workshop previews
  - `unity\<Mod>\Mesh\*.obj` and `unity\<Mod>\Texture\*_palette.png`: in-world models for Unity (see `unity\README.md`)
- `MakeMod.ps1`:
  - copies `recipes\<Mod>\Sprites\*.png` into the mod's `Data\Sprites\`
  - copies `recipes\<Mod>\Preview.png` over the mod's `Preview.png`
  - copies `recipes\<Mod>\AddressableAssets\` (built in Unity) into `Data\AddressableAssets\`
- Recipe helpers in `MakeMod.ps1`:
  - `Set-ShaderParam -Model $m -Name _FloorColorAdd -Value "#..."`: tints through the game's shader parameters
  - `Set-ModelMesh -Model $m -Mesh <name> -Texture <name>`: switches to a custom model
  - `Test-ModAddressables <Mod>`: true once the Unity build is in place, so recipes switch models only when the assets exist

You can also drop hand-made PNGs into `recipes\<Mod>\Sprites\` and skip the script.

## To check in game

- [ ] The new icons appear in the build menu (Cold Shelf, Cold Floor, Fish Farm) and on the cider resource and recipe. (The guide asks for 64×64; ours are 128×128 like the game's own. If they show wrongly, render at 64 with `ICON_SIZE` in `make_art.py`.)
- [ ] The Cold Floor looks cool blue but still like clay; adjust `FloorTintMultiply` / `FloorTintAdd` in `recipes\Cold.ps1`.
- [ ] Icons look right at the game's UI scale and on its dark and light panels.
- [ ] Previews show in the in-game Mods menu and on the Workshop page.
- [ ] Nothing else changed: the Cold Shelf still shows its 10 piles, and saves from 1.0.2.17 still load.

## Ideas for next steps

- Build the two Unity models (`unity\README.md`) and test them in game.
- More models: an apple-cider barrel pile for the resource in the world.
- Hand-painted textures instead of flat palette colours.
