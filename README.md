# GoingMedievalMods-phrontisteries

[Going Medieval](https://store.steampowered.com/app/1029780/Going_Medieval/) mods by **phrontisteries**, and the PowerShell tooling that builds them from the game's own data, so they can be rebuilt after every game update.

Built for game version **1.2.20**.

## The mods

Found a bug or have an idea? [Open an issue](https://github.com/phrontisteries/GoingMedievalMods-phrontisteries/issues). Every mod's description links here.

| Mod | Workshop | What it does |
|---|---|---|
| [Better_Animals](Mods/Better_Animals) | [3681706355](https://steamcommunity.com/sharedfiles/filedetails/?id=3681706355) | All animals can be tamed, penned, trained, haul and attack; 100x carrying; population caps; simpler diets; cat pest control; settlers carry more. |
| [Brokerastered](Mods/Brokerastered) | (local) | The Broker trades, bargains and negotiates better, mines faster and more, and prefers trade, crafting, mining and art. |
| [Cold](Mods/Cold) | [3681706554](https://steamcommunity.com/sharedfiles/filedetails/?id=3681706554) | Cold Shelf (10 piles, actively cooled), a Cold Floor of every floor material in their own build group, adjusted temperature thresholds. |
| [Faster Region Travel](Mods/FasterRegionTravel) | [3681708275](https://steamcommunity.com/sharedfiles/filedetails/?id=3681708275) | Caravans cross the region map 100x faster. |
| [Fermenting Apple Cider](Mods/Fermenting%20Apple%20Cider) | [3681708241](https://steamcommunity.com/sharedfiles/filedetails/?id=3681708241) | The fermentation station makes apple cider. |
| [Fine Clothing Worker](Mods/Fine_Clothing_Worker) | [3681706422](https://steamcommunity.com/sharedfiles/filedetails/?id=3681706422) | Settlers in Superior/Flawless apparel work, walk, rest and fight better. |
| [Fish Farming](Mods/Fish_Farming) | [3681706482](https://steamcommunity.com/sharedfiles/filedetails/?id=3681706482) | A fish farm that breeds trout, pike and eel (unlocked with barrel making). |
| [Heavy Crossbow Sniper](Mods/Heavy%20Crossbow%20Sniper) | [3458906692](https://steamcommunity.com/sharedfiles/filedetails/?id=3458906692) | The heavy crossbow becomes a long-range sniper weapon (360 armor-piercing damage, 45 m, perfect accuracy, fast reload, full cover); NPCs no longer spawn with it. |
| [More Creation Points](Mods/More_Creation_Points) | (local) | New settlers get up to 1000 creation points, 40 perks and 20 passions. |
| [More Prisoners](Mods/More_Prisoners) | [3681706523](https://steamcommunity.com/sharedfiles/filedetails/?id=3681706523) | Raiders surrender more readily; merchants trade more prisoners. |
| [Mushroom Cropfield](Mods/Mushroom%20Cropfield) | [3458079756](https://steamcommunity.com/sharedfiles/filedetails/?id=3458079756) | Plantable, fast-spreading mushrooms that grow on any terrain. |

To play one without the Workshop, copy its folder from `Mods\` to `Documents\Foxy Voxel\Going Medieval\Mods\` and enable it in the game's Mods menu.

## Repository layout

```
MakeMod.ps1          Builds mods from recipes (menu, -ModName <name>, or -All)
Settings.ps1         Your author name and the game's StreamingAssets path
recipes\             What each mod changes (the source of truth)
  Descriptions.json    In-game description of every mod: one short line in each of the 12 languages
  <Mod>.ps1            script recipe: Build-<Mod>_<File> functions that transform the vanilla file
  <Mod>\<File>.json    source recipe: JSON copied into the mod, "#template" entries rebuilt from vanilla
Mods\                Built mods, ready for the game and the Workshop (generated; do not edit by hand)
tools\
  Test-Mods.ps1        Checks built mods against the installed game
  ModTranslationPatcher.ps1  Fills in locKeys for the game's languages (MyMemory translation API)
  art\                 Original art: 3D models, game-style icon renderer, previews, Unity mesh export (Python)
unity\                In-world models for Foxy Voxel's Unity modding project, with build steps
docs\MODDING-NOTES.md  How the game merges mod JSON, and the pitfalls these tools guard against
docs\GRAPHICS.md      Icons, previews and other art: what the game supports and how ours are made
```

## Requirements

- Windows with Going Medieval installed (Steam, GOG or Epic)
- Windows PowerShell 5.1 (built into Windows 10/11) or [PowerShell 7+](https://learn.microsoft.com/powershell/scripting/install/installing-powershell-on-windows). Both produce identical files.
- If scripts are blocked, allow them for your user once: `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned`

## Using it

1. Fork or clone this repo.
2. Edit `Settings.ps1`: set `$Global:Author` to your own handle, `$Global:StreamingAssets` to your install's `Going Medieval_Data\StreamingAssets` folder, and `$Global:RepoUrl` to your fork. That link is added to the end of every mod description so players can find the source and report issues; leave it empty for no link. Or set `GM_AUTHOR`, `GM_STREAMING_ASSETS` and `GM_REPO_URL` instead of editing.
3. Build:
   ```powershell
   .\MakeMod.ps1                  # pick from a menu (run it in a console window, not the ISE)
   .\MakeMod.ps1 -ModName Cold    # one mod
   .\MakeMod.ps1 -All             # every mod
   ```
4. Check:
   ```powershell
   .\tools\Test-Mods.ps1          # exit code = number of errors
   ```
5. Copy the mod folder from `Mods\` to `Documents\Foxy Voxel\Going Medieval\Mods\`, test it in game (existing save and a new game), then upload from the game's Mods menu.

Mod versions follow `x.v.y.z`: game version `x.y.z` with your revision `v` in the second place. `MakeMod.ps1` bumps `v` on each build and resets it to 0 when the game version changes.

### After a game update

```powershell
.\MakeMod.ps1 -All
.\tools\Test-Mods.ps1
git diff Mods        # what changed in the built mods, because the game changed
```

Recipes start from the current vanilla data each time, so most game changes flow in automatically. `Test-Mods.ps1` reports what still needs a human:

| Finding | Meaning | Usual fix |
|---|---|---|
| `ERROR file` | The game no longer has a file with that name. | Find where the data moved; rename the recipe file or `Build-` function. |
| `ERROR field` | A field no game entry uses any more (renamed or removed). | Rename or drop it in the recipe. |
| `ERROR rule` | A cross-file rule is broken (e.g. shelf display slots). | See `docs\MODDING-NOTES.md`. |
| `WARN new` | A new model lacks fields the closest vanilla model has. | Add a `"#template"` to it, or add the fields. |
| `ERROR info` | `ModInfo.json` would not load: a missing field, a nested `tags` list, or a tag the game does not know (only General, Localization, Scenario, Character, Map). The mod would be missing from the Mods menu. | Fix the recipe's `Set-<Mod>_ModInfo`; MakeMod drops unknown tags. |
| `WARN ver` | `ModInfo.json` targets another game version. | Rebuild with `MakeMod.ps1`. |

### Making a new mod

**No code:** create `recipes\<ModName>\` and put game-named JSON files in it, written as the game's merge rules expect (see the notes). Give every new model a template:

```json
{
  "repository": [
    { "#template": "fermenting_mash", "id": "fermenting_apple_cider", "iconPath": "fermenting_apple_cider" }
  ]
}
```

The built model is the current vanilla `fermenting_mash` with the fields you wrote replacing its own. Overrides of existing ids (and `#APPEND` / `#REMOVE` lists) are copied as written.

**Script:** create `recipes\<ModName>.ps1` with a `Build-<ModName>_<File>` function per file. Each function receives the current vanilla file as `-RawJson` and returns the mod's version. Add `Set-<ModName>_ModInfo` to control the name, description and tags. In function names, leave out spaces (`Mushroom Cropfield` → `Build-MushroomCropfield_Research`). See `recipes\Cold.ps1` and the header of `MakeMod.ps1`.

A mod can use both. A `Build-` function wins over a source file with the same name.

**Description:** add the mod to `recipes\Descriptions.json` with one short line per language (English, Chinese, French, Spanish, German, Russian, Japanese, Portugese, Korean, Polish, Turkish, Italian). The game shows a single description to every player, so each line is labelled with its language. A mod missing from the file keeps the description from its `Set-<ModName>_ModInfo` or existing `ModInfo.json`.

**Art (optional):** `recipes\<ModName>\Sprites\<iconPath>.png` (64×64) is copied to the mod's `Data\Sprites`, and `recipes\<ModName>\Preview.png` becomes the mod's preview. See `docs\GRAPHICS.md`.

Script files are saved as UTF-8 **with** a BOM so Windows PowerShell 5.1 reads them correctly. Keep it when editing (VS Code: "UTF-8 with BOM"). Mod JSON is written as UTF-8 without a BOM through `Write-JsonFile` in `Settings.ps1`; use it (not `ConvertTo-Json | Out-File`) in new tools so 5.1 and 7 give the same bytes.

## License

Everything in this repository is released under the [MIT License](LICENSE): the tooling, the recipes and the mods. The exceptions are images made from the game's own art, which stays Foxy Voxel's: the textures in `unity/Cold/Texture/` and the bundles built from them (recoloured game textures); the Cold build-menu icons in `recipes/Cold/Sprites/` (recoloured game icons) and the Cold preview (drawn with game textures); and the Mushroom Cropfield icon, preview and `tools/art/assets/mushrooms_cutout.png` (the game's mushrooms, cut from an in-game screenshot, on the game's stockpile icon). Every built mod folder carries a copy as `LICENSE.txt`. Going Medieval and its game data remain the property of Foxy Voxel / Mythwright; see their [modding policy](https://foxyvoxel.io/2025/03/13/modding-guide-policy/) before publishing.
