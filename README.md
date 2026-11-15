# GoingMedievalMod-Cold

Going Medieval mod **Cold**, updated for game version **1.2.17**.

- **Cold Shelf:** a food-storage shelf that holds 10 piles (no Coin, Carcass or Fermenting). Unlocked by Preserving Food I.
- **Cold Floor:** a clay brick floor with active cooling. It is at the end of the floor list.
- **Temperature thresholds:** the first two thresholds change from 0 and 1 to 1 and 2.

## Install

Copy this folder to `Documents\Foxy Voxel\Going Medieval\Mods\Cold`, or subscribe on the Steam Workshop. The `tools` folder and this README are not needed by the game.

## Updating for a new game version

New buildings must be complete models. `tools/build.py` regenerates `cold_shelf` and `cold_floor` from the current vanilla `shelf` and `clay_brick_floor`, and rebuilds the shelf's display slots:

```
python tools/build.py "<Going Medieval>/Going Medieval_Data/StreamingAssets" Data/Models
```

Then set `gameVersion` in `ModInfo.json`.

## 1.2.0.17 changes

- Fixed the load crash (NullReferenceException) and the shelf turning into an empty rack: the shelf now has one display slot per pile, filed under its own storage id.
- Added the fields the current game requires on the shelf (`inflationCurve`, `marketCap`) and the floor (`upgradeToFlag`).
