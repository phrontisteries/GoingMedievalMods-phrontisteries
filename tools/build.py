"""Rebuild the Cold mod's new models from the current vanilla data.

New ids must be complete models, so each Cold building is regenerated from the
current vanilla entry it was cloned from, then only the Cold-specific fields are
applied on top. Re-run this after future game updates.

usage: python3 -I build.py <StreamingAssets dir> <mod Data/Models dir>
"""
import copy, json, sys

VANILLA, MODELS = sys.argv[1], sys.argv[2]


def load(path):
    with open(path, encoding="utf-8-sig") as f:
        return json.load(f)


def save(name, data):
    with open(f"{MODELS}/{name}", "w", encoding="utf-8", newline="\r\n") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write("\n")


vanilla = {e["id"]: e for e in load(f"{VANILLA}/Constructables/BaseBuildingRepository.json")["repository"]}
old = {e["id"]: e for e in load(f"{MODELS}/BaseBuildingRepository.json")["repository"]}

# id -> (vanilla source id, fields that make it the Cold version)
COLD = {
    "cold_shelf": ("shelf", {"shelfComponentID": "cold_shelf_storage", "defaultThermalModelID": "cold_temp"}),
    "cold_floor": ("clay_brick_floor", {"defaultThermalModelID": "cold_temp"}),
}
buildings = []
for cold_id, (src, overrides) in COLD.items():
    entry = copy.deepcopy(vanilla[src])
    entry["id"] = cold_id
    entry["locKeys"] = old[cold_id]["locKeys"]  # keep the existing translated names
    entry.update(overrides)
    buildings.append(entry)
save("BaseBuildingRepository.json", {"repository": buildings})

# One display slot per pile, filed under the storage id (vanilla convention).
# 10 piles: 4 on the top board, 3 on each lower board, shrunk to fit side by side.
BOARDS = [(1.776, [-0.3, -0.1, 0.1, 0.3]), (0.934, [-0.25, 0.0, 0.25]), (0.234, [-0.25, 0.0, 0.25])]
slots = []
for y, xs in BOARDS:
    for x in xs:
        slots.append({
            "id": str(len(slots) + 1),
            "positionOffset": {"x": x, "y": y, "z": 0},
            "rotationOffset": {"x": 0, "y": 90, "z": 0},
            "scaleOffset": {"x": -0.55, "y": -0.55, "z": -0.55},
        })
storage = load(f"{MODELS}/UniversalStorage.json")
max_piles = storage["repository"][0]["maxPileCount"]
assert len(slots) == max_piles, (len(slots), max_piles)
save("ShelfComponentRepository.json", {"repository": [{
    "id": "cold_shelf_storage",
    "storageIDs": ["cold_storage"],
    "multipleTransformSettingsArray": [{"id": "cold_storage", "transformSettingsArray": slots}],
}]})
print("built", [b["id"] for b in buildings], "slots", len(slots))
