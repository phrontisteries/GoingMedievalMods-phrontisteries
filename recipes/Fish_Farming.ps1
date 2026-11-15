# SPDX-License-Identifier: MIT  (Copyright (c) 2026 phrontisteries; see LICENSE)
# Fish_Farming is mostly a source recipe (recipes\Fish_Farming\*.json). This adds one optional step:
# once the custom fish-farm model is built (unity\README.md), the building uses it instead of the saltpeter pit.
function Build-Fish_Farming_BaseBuildingRepository {
    param( [Parameter(Mandatory)]$RawJson )
    $out = Build-FromSource -SourcePath (Join-Path $Global:RecipesRoot "Fish_Farming\BaseBuildingRepository.json") -RawJson $RawJson
    if (Test-ModAddressables "Fish_Farming") {
        $farm = $out.repository | Where-Object { $_.id -eq "fish_farm" }
        Set-ModelMesh -Model $farm -Mesh "phrontisteries_fish_farm" -Texture "phrontisteries_fish_farm_palette"
    }
    return $out
}
