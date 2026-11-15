# Modding notes

What we have learned about how Going Medieval loads JSON mods, and the problems these tools guard against. Last checked against game version 1.2.17.

## Where things are

| What | Where |
|---|---|
| Vanilla data | `<Steam>\steamapps\common\Going Medieval\Going Medieval_Data\StreamingAssets\` (in subfolders such as `Constructables`, `Resources`, `Settings`) |
| Game version | `Going Medieval_Data\globalgamemanagers`: the first `x.y.z` in the first 64 KB (`Get-GameVersion` in `Settings.ps1`) |
| Installed mods | `Documents\Foxy Voxel\Going Medieval\Mods\<Mod>\` |
| Game log | `%USERPROFILE%\AppData\LocalLow\Foxy Voxel\Going Medieval\Player.log` |
| Official guide | <https://foxyvoxel.io/2025/03/13/modding-guide-policy/> |

A mod folder holds `ModInfo.json`, `Preview.png` (640×360 or 1280×720, under 1 MB) and `Data\Models\*.json`. A mod JSON file has the **same file name** as the vanilla file it changes, whichever subfolder the vanilla file is in. `WorkshopId.json` is written by the game when you upload. Keep it so later uploads update the same Workshop item.

## How the game merges mod files

- Files with a `repository` array are merged **by `id`**.
- **Existing id:** the fields you write replace vanilla's, and fields you leave out keep vanilla values. Partial entries are fine.
- **New id:** the model is added as written, so it **must be complete**. When the game later adds a required field, every new model without it breaks (often a `NullReferenceException` on load). This is why new models should use `"#template"` (source recipes) or clone the vanilla model inside the `Build-` function (script recipes).
- **Lists replace** the vanilla list. Add `#APPEND` or `#REMOVE` to the field name to add or remove items instead, for example `"unlocks#APPEND": [ { "unlockId": "cold_shelf" } ]`.
- Files without a `repository` array (most of `Settings\`) replace the matching top-level fields.

## Pitfalls found so far

### ModInfo.json tags must be a flat list of known tags (mod missing from the menu)
The game reads `ModInfo.json` into `NSMedieval.Modding.ModModel` with `string[] tags` mapped to the `ModTag` enum: `General`, `Localization`, `Scenario`, `Character`, `Map`. A nested list (`[["General","Combat"]]`, an old MakeMod bug) stops the mod loading and it disappears from the Mods menu; tags such as `Combat` or `Food` are not game tags. `Test-Mods.ps1` checks both; MakeMod drops unknown tags with a warning.

### Shelves need one display slot per pile (Cold, 1.2.x)
`ShelfComponentRepository.json` lists display slots in `multipleTransformSettingsArray`, grouped by an `id` that must equal a storage id in `storageIDs`. Each group needs exactly as many slots as that storage's `maxPileCount` in `UniversalStorage.json`. Every vanilla shelf follows this. Hidden storage such as chests and barrels has no slots at all. Cold's shelf cloned `shelf_storage`, so it kept 3 slots filed under `general_storage` for a 10-pile `cold_storage`. In 1.2 that crashed loading with a `NullReferenceException`, and stocked shelves turned into empty racks. `Test-Mods.ps1` checks this rule.

### Fields added in the Diplomacy update (1.2.x)
Buildings and resources gained `marketCap` and `inflationCurve`, and floors gained `upgradeToFlag`. New models copied from 1.0.x lacked them.

### Game ids are not always spelled right
Some vanilla ids contain typos, such as `feermnting_alcohol` and `fermneting_wine` in `DecayModifiers.json`. Reference them exactly as the game spells them.

### Templates can carry flags you don't want
A template copies **every** field. For example, `cabbage_cropfield` has `"isDefault": true`, so a cropfield templated on it would skip its research unlock. Only template when you want the whole model. Otherwise write the full model and let `Test-Mods.ps1` warn about missing fields.

## Reference values

`Resources\Resource Categories.txt` in StreamingAssets explains the resource category bit flags. `Stockpile\ResourceGroups.json` lists the valid `storableResourceGroups`. `Map\VoxelTypes.json` lists the terrain ids used by `growsOn`.
