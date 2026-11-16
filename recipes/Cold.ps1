# SPDX-License-Identifier: MIT  (Copyright (c) 2026 phrontisteries; see LICENSE)
function Set-Cold_ModInfo {
    # Process will use first available: HERE, existing ModInfo.json (auto-versioning), lastly as generic defaults
    return @{
        # id          = "phrontisteries.cold"
        # name        = "Cold"
        description = @"
Active Cooling
Cold Shelf: holds 10 (no Coin, Carcass, or Fermenting)
Cold Floor: Clay (end of selection list)
Temperature Modification: threshold from 0 to 1 and 1 to 2.
"@
        # author      = "phrontisteries"
        # modVersion  = "0.99.99.99"
        # gameVersion = "0.28.39"
        tags        = @("General")
    }
}
$script:Cold = [ordered]@{
    ResearchUnlockId        = "cold_shelf"
    ThermalModelId          = "cold_temp"

    ShelfComponentRepository= "ShelfComponentRepository.json"
    ShelfComponentId_From   = "shelf_storage"
    ShelfComponentId        = "cold_shelf_storage"

    UniversalStorageId      = "cold_storage"
    MaxPileCount            = 10
    resourceGroups          = "ResourceGroups.json"
    notStore                = @("Carcass","FoodFermenting","Coin")

    BaseBuildingRepository  = "BaseBuildingRepository.json"
    BuildingId_Shelf_From   = "shelf"
    BuildingId_Shelf_Id     = "cold_shelf"
    BuildingId_Shelf_Name   = "Cold Shelf"
    BuildingId_Shelf_Icon   = "phrontisteries_cold_shelf"

    BuildingId_Floor_From   = "clay_brick_floor"
    BuildingId_Floor_Id     = "cold_floor"
    BuildingId_Floor_Name   = "Cold Floor"
    BuildingId_Floor_Icon   = "phrontisteries_cold_floor"
    FloorTintMultiply       = "#CFE3FF"                     # _FloorColorMultiply: cools the clay colour (vanilla: #FFFFFF); used until the frosted-brick texture is built
    FloorTintAdd            = "#04101C"                     # _FloorColorAdd: a little blue lift (vanilla clay: #000000)
    # Frosted bricks: the clay herringbone with 9 bricks per repeat (no two touching) in the frost colour of the
    # Cold Shelf's boards; the rest stays plain clay. unity\Cold\Texture\phrontisteries_cold_floor_albedo.png,
    # made by tools\art\make_cold_floor.py. The bump map is the game's own clay-brick one.
    FloorTexture            = "phrontisteries_cold_floor_albedo"
    FloorNormal             = "clay_brick_floor_normal"
    # In-world look: the game's own shelf model with a light-blue copy of its texture
    # (unity\Cold\Texture\phrontisteries_cold_shelf_albedo.png, made by tools\art\recolor_texture.py)
    ShelfTexture            = "phrontisteries_cold_shelf_albedo"

    # Cold Shelf display: one slot per pile (the game needs a slot for every pile, filed under the storage id).
    # 4 piles on the top board, 3 on each lower board, shrunk to fit side by side.
    ShelfBoards             = @(
        @{ y = 1.776; x = @(-0.3, -0.1, 0.1, 0.3) }
        @{ y = 0.934; x = @(-0.25, 0.0, 0.25) }
        @{ y = 0.234; x = @(-0.25, 0.0, 0.25) }
    )
    ShelfPileScale          = -0.55
}
# Names per language (languages missing here fall back to the English name).
$script:ColdNames = @{
    cold_shelf = [ordered]@{ English = "Cold Shelf"; Chinese = "冷架"; French = "Étagère froide"; Spanish = "Estante frío"; German = "Kaltregal"; Russian = "Холодная полка"; Japanese = "コールドシェルフ"; Portugese = "Prateleira Fria"; Korean = "차가운 선반"; Polish = "Zimna półka"; Turkish = "Soğuk Raf"; Italian = "Scaffale Freddo" }
    cold_floor = [ordered]@{ English = "Cold Floor"; Chinese = "冷地板"; French = "Sol froid"; Spanish = "Piso frío"; German = "Kaltboden"; Russian = "Холодный пол"; Japanese = "コールドフロア"; Portugese = "Piso Frio"; Korean = "차가운 바닥"; Polish = "Zimna podłoga"; Turkish = "Soğuk Zemin"; Italian = "Pavimento Freddo" }
}
function Get-ColdLocKeys {
    param( [Parameter(Mandatory)][string]$Id, [Parameter(Mandatory)][string]$InfoKey )
    foreach ($lang in $script:ColdNames[$Id].Keys) {
        [pscustomobject]@{ languageName = $lang; name = $script:ColdNames[$Id][$lang]; info = $InfoKey }
    }
}

function Build-Cold_ResourceSettings {
    param( [Parameter(Mandatory)]$RawJson )
    $out = $RawJson.PSObject.Copy()
    $out.temperatureThresholds[0] = 1
    $out.temperatureThresholds[1] = 2
    return $out
}

function Build-Cold_Research {
    param( [Parameter(Mandatory)]$RawJson )
    return @{
        repository = @(
            @{
                id = "preserving_food_lvl1"
                "unlocks#APPEND" = @(
                    @{ unlockId = $Cold.ResearchUnlockId }
                )
            }
        )
    }
}

function Build-Cold_ShelfComponentRepository {
    param( [Parameter(Mandatory)]$RawJson )
    $vanilla = $RawJson.repository | Where-Object { $_.id -eq $Cold.ShelfComponentId_From }
    if (-not $vanilla) {throw "$($Cold.ShelfComponentId_From) not found in $($Cold.ShelfComponentRepository)"}
    # Keep the vanilla shelf's slot rotation; build one slot per pile, filed under OUR storage id.
    $rotation = $vanilla.multipleTransformSettingsArray[0].transformSettingsArray[0].rotationOffset
    $slots = @()
    foreach ($board in $Cold.ShelfBoards) {
        foreach ($x in $board.x) {
            $slots += [ordered]@{
                id             = "$($slots.Count + 1)"
                positionOffset = [ordered]@{ x = $x; y = $board.y; z = 0 }
                rotationOffset = $rotation
                scaleOffset    = [ordered]@{ x = $Cold.ShelfPileScale; y = $Cold.ShelfPileScale; z = $Cold.ShelfPileScale }
            }
        }
    }
    if ($slots.Count -ne $Cold.MaxPileCount) { throw "Cold shelf has $($slots.Count) slots but holds $($Cold.MaxPileCount) piles" }
    return @{ repository = @([ordered]@{
        id                             = $Cold.ShelfComponentId
        storageIDs                     = @($Cold.UniversalStorageId)
        multipleTransformSettingsArray = @([ordered]@{ id = $Cold.UniversalStorageId; transformSettingsArray = $slots })
    }) }
}

function Build-Cold_ThermalModels {
    param( [Parameter(Mandatory)]$RawJson )
    return @{
        repository = @(
            @{
                id = $Cold.ThermalModelId
                emission = -999999
                emissionRange = 45
                insulation = 1
                insulationVertical = 1
                lightTransmission = 1
            }
        )
    }
}

function Build-Cold_UniversalStorage {
    param( [Parameter(Mandatory)]$RawJson )
    $resourceGroups = Get-JSONGameFile -SourceFileName ($Cold.resourceGroups)
    $depth0 = $resourceGroups.repository |
        Where-Object { $_.id -eq "all_resource_groups" } |
        Select-Object -ExpandProperty resourceGroups |
        Where-Object { $_.depth -eq 0 } |
        Select-Object -ExpandProperty groupId
    $filtered = $depth0 | Where-Object { $Cold.notStore -notcontains $_ }
    return @{
        repository = @(
            @{
                id = $Cold.UniversalStorageId
                zonePriority = 1
                maxPileCount = $Cold.MaxPileCount
                storableResourceGroups = $filtered
            }
        )
    }
}

function Build-Cold_BaseBuildingRepository {
    param( [Parameter(Mandatory)]$RawJson )

    # New ids must be complete models: clone the CURRENT vanilla building, then change only what makes it "Cold".
    $vanillaShelf = $RawJson.repository | Where-Object { $_.id -eq $Cold.BuildingId_Shelf_From }
    if (-not $vanillaShelf) { throw "Shelf '$($Cold.BuildingId_Shelf_From)' not found in $($Cold.BaseBuildingRepository)" }
    $shelfClone = New-DeepCopy $vanillaShelf
    $shelfClone.id = $Cold.BuildingId_Shelf_Id
    $shelfClone.shelfComponentID = $Cold.ShelfComponentId
    $shelfClone.iconPath = $Cold.BuildingId_Shelf_Icon   # recipes\Cold\Sprites\<iconPath>.png
    $shelfClone | Add-Member -NotePropertyName defaultThermalModelID -NotePropertyValue $Cold.ThermalModelId -Force
    $shelfClone.locKeys = @(Get-ColdLocKeys -Id $Cold.BuildingId_Shelf_Id -InfoKey $vanillaShelf.locKeys[0].info)

    $vanillaFloor = $RawJson.repository | Where-Object { $_.id -eq $Cold.BuildingId_Floor_From }
    if (-not $vanillaFloor) { throw "Floor '$($Cold.BuildingId_Floor_From)' not found in $($Cold.BaseBuildingRepository)" }
    $floorClone = New-DeepCopy $vanillaFloor
    $floorClone.id = $Cold.BuildingId_Floor_Id
    $floorClone.iconPath = $Cold.BuildingId_Floor_Icon
    $floorClone | Add-Member -NotePropertyName defaultThermalModelID -NotePropertyValue $Cold.ThermalModelId -Force
    $floorClone.locKeys = @(Get-ColdLocKeys -Id $Cold.BuildingId_Floor_Id -InfoKey $vanillaFloor.locKeys[0].info)
    if (Test-ModAddressables "Cold" -Asset $Cold.FloorTexture) {
        Set-FloorTexture -Model $floorClone -Albedo $Cold.FloorTexture -Normal $Cold.FloorNormal   # frosted bricks, plain clay between
    }
    else {
        Set-ShaderParam -Model $floorClone -Name "_FloorColorMultiply" -Value $Cold.FloorTintMultiply   # cool blue look in the world
        Set-ShaderParam -Model $floorClone -Name "_FloorColorAdd" -Value $Cold.FloorTintAdd
    }

    # Light-blue shelf, once its Addressables are built (unity\README.md); until then the vanilla wooden look.
    if (Test-ModAddressables "Cold" -Asset $Cold.ShelfTexture) { Set-ModelTexture -Model $shelfClone -Texture $Cold.ShelfTexture }

    return @{ repository = @($shelfClone, $floorClone) }
}
