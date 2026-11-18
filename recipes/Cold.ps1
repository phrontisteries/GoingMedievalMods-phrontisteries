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

    # Cold Floors: a Cold copy of every vanilla floor (in the vanilla order), grouped in a build-menu group of
    # their own. Ids are cold_<vanilla id>; the clay brick one keeps its original id (cold_floor) for old saves.
    # Icons: recipes\Cold\Sprites\phrontisteries_cold_<vanilla id>.png (tools\art\make_cold_floor_icons.py).
    Floors                  = @("wood_floor", "wicker_floor", "limestone_floor", "limestone_block_floor", "clay_brick_floor",
                                "stone_decorative_floor", "clay_decorative_floor", "marble_decorative_floor",
                                "metal_grated_platform", "wicker_mesh_floor")
    FloorIdOverride         = @{ clay_brick_floor = "cold_floor" }
    # Frosted look (tools\art\make_cold_floors.py): on every floor the most elements possible with none touching
    # are frosted. Floors that use a square of the game's floor sheet use one frosted copy of the whole sheet
    # (their square, bump map and tiling stay as they are; their tint is baked into the copy, so it is reset);
    # the decorative floors use frosted copies of their own textures.
    FloorSheet              = "phrontisteries_cold_floor_sheet"
    FloorOwnTexture         = "phrontisteries_cold_{0}_albedo"          # {0} = vanilla floor id
    # Edge pieces (border rails): _ElementColor, set to land on the Cold Shelf's frosted-board shade in game.
    FloorEdgeColor          = "#6F8471"
    # Until the frosted textures are built: a cool tint of the vanilla floor instead.
    FloorTintMultiply       = "#CFE3FF"
    FloorTintAdd            = "#04101C"
    # Build-menu group for Cold Floors. The game's sub-categories are a fixed list; NotInUse1-3 are spare
    # slots the game never uses, so Cold Floors get a group of their own (always listed last under Base).
    FloorMenuGroup          = "NotInUse1"
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
    # Cold Floors, one per vanilla floor (ids: cold_<vanilla id>; the clay brick one keeps its original id cold_floor)
    cold_wood_floor = [ordered]@{ English = "Cold Wood Floor"; Chinese = "冷木地板"; French = "Sol froid en bois"; Spanish = "Piso frío de madera"; German = "Kalter Holzboden"; Russian = "Холодный деревянный пол"; Japanese = "コールド木の床"; Portugese = "Piso Frio de Madeira"; Korean = "차가운 나무 바닥"; Polish = "Zimna drewniana podłoga"; Turkish = "Soğuk Ahşap Zemin"; Italian = "Pavimento Freddo in Legno" }
    cold_wicker_floor = [ordered]@{ English = "Cold Wicker Floor"; Chinese = "冷柳条地板"; French = "Sol froid en osier"; Spanish = "Piso frío de mimbre"; German = "Kalter Weidenboden"; Russian = "Холодный плетёный пол"; Japanese = "コールド枝編みの床"; Portugese = "Piso Frio de Vime"; Korean = "차가운 고리버들 바닥"; Polish = "Zimna wiklinowa podłoga"; Turkish = "Soğuk Hasır Zemin"; Italian = "Pavimento Freddo in Vimini" }
    cold_limestone_floor = [ordered]@{ English = "Cold Limestone Floor"; Chinese = "冷石灰石地板"; French = "Sol froid en calcaire"; Spanish = "Piso frío de piedra caliza"; German = "Kalter Kalksteinboden"; Russian = "Холодный известняковый пол"; Japanese = "コールド石灰岩の床"; Portugese = "Piso Frio de Calcário"; Korean = "차가운 석회암 바닥"; Polish = "Zimna wapienna podłoga"; Turkish = "Soğuk Kireçtaşı Zemin"; Italian = "Pavimento Freddo in Calcare" }
    cold_limestone_block_floor = [ordered]@{ English = "Cold Limestone Block Floor"; Chinese = "冷石灰石砖地板"; French = "Sol froid en blocs de calcaire"; Spanish = "Piso frío de bloques de caliza"; German = "Kalter Kalksteinblockboden"; Russian = "Холодный пол из известняковых блоков"; Japanese = "コールド石灰岩ブロックの床"; Portugese = "Piso Frio de Blocos de Calcário"; Korean = "차가운 석회암 블록 바닥"; Polish = "Zimna podłoga z bloków wapiennych"; Turkish = "Soğuk Kireçtaşı Blok Zemin"; Italian = "Pavimento Freddo in Blocchi di Calcare" }
    cold_floor = [ordered]@{ English = "Cold Clay Brick Floor"; Chinese = "冷黏土砖地板"; French = "Sol froid en briques d'argile"; Spanish = "Piso frío de ladrillo de arcilla"; German = "Kalter Lehmziegelboden"; Russian = "Холодный пол из глиняного кирпича"; Japanese = "コールド粘土レンガの床"; Portugese = "Piso Frio de Tijolo de Argila"; Korean = "차가운 점토 벽돌 바닥"; Polish = "Zimna podłoga z cegły glinianej"; Turkish = "Soğuk Kil Tuğla Zemin"; Italian = "Pavimento Freddo in Mattoni d'Argilla" }
    cold_stone_decorative_floor = [ordered]@{ English = "Cold Decorative Stone Floor"; Chinese = "冷装饰石地板"; French = "Sol froid en pierre décorative"; Spanish = "Piso frío de piedra decorativa"; German = "Kalter dekorativer Steinboden"; Russian = "Холодный декоративный каменный пол"; Japanese = "コールド装飾石の床"; Portugese = "Piso Frio de Pedra Decorativa"; Korean = "차가운 장식용 돌 바닥"; Polish = "Zimna ozdobna kamienna podłoga"; Turkish = "Soğuk Dekoratif Taş Zemin"; Italian = "Pavimento Freddo in Pietra Decorativa" }
    cold_clay_decorative_floor = [ordered]@{ English = "Cold Decorative Clay Floor"; Chinese = "冷装饰黏土地板"; French = "Sol froid en argile décorative"; Spanish = "Piso frío de arcilla decorativa"; German = "Kalter dekorativer Tonboden"; Russian = "Холодный декоративный глиняный пол"; Japanese = "コールド装飾粘土の床"; Portugese = "Piso Frio de Argila Decorativa"; Korean = "차가운 장식용 점토 바닥"; Polish = "Zimna ozdobna gliniana podłoga"; Turkish = "Soğuk Dekoratif Kil Zemin"; Italian = "Pavimento Freddo in Argilla Decorativa" }
    cold_marble_decorative_floor = [ordered]@{ English = "Cold Marble Floor"; Chinese = "冷大理石地板"; French = "Sol froid en marbre"; Spanish = "Piso frío de mármol"; German = "Kalter Marmorboden"; Russian = "Холодный мраморный пол"; Japanese = "コールド大理石の床"; Portugese = "Piso Frio de Mármore"; Korean = "차가운 대리석 바닥"; Polish = "Zimna marmurowa podłoga"; Turkish = "Soğuk Mermer Zemin"; Italian = "Pavimento Freddo in Marmo" }
    cold_metal_grated_platform = [ordered]@{ English = "Cold Metal Grate"; Chinese = "冷金属格栅"; French = "Grille métallique froide"; Spanish = "Rejilla metálica fría"; German = "Kaltes Metallgitter"; Russian = "Холодная металлическая решётка"; Japanese = "コールド金属格子"; Portugese = "Grade de Metal Fria"; Korean = "차가운 금속 격자"; Polish = "Zimna metalowa krata"; Turkish = "Soğuk Metal Izgara"; Italian = "Grata Metallica Fredda" }
    cold_wicker_mesh_floor = [ordered]@{ English = "Cold Wicker Mesh Floor"; Chinese = "冷柳条网地板"; French = "Sol froid en treillis d'osier"; Spanish = "Piso frío de malla de mimbre"; German = "Kalter Weidengeflechtboden"; Russian = "Холодный пол из плетёной сетки"; Japanese = "コールド枝編みメッシュの床"; Portugese = "Piso Frio de Malha de Vime"; Korean = "차가운 고리버들 망 바닥"; Polish = "Zimna podłoga z siatki wiklinowej"; Turkish = "Soğuk Hasır Örgü Zemin"; Italian = "Pavimento Freddo a Rete di Vimini" }
}
function Get-ColdLocKeys {
    param( [Parameter(Mandatory)][string]$Id, [Parameter(Mandatory)][string]$InfoKey )
    foreach ($lang in $script:ColdNames[$Id].Keys) {
        [pscustomobject]@{ languageName = $lang; name = $script:ColdNames[$Id][$lang]; info = $InfoKey }
    }
}

function Get-FloorTextures { # A floor's own albedo/normal texture names ('' = it uses a square of the shared floor sheet).
    param([Parameter(Mandatory)]$Model)
    $out = @{ Albedo = ""; Normal = "" }
    foreach ($list in @($Model.variationLists)) { foreach ($v in @($list.variations)) { foreach ($slot in @($v.slots)) {
        if ($slot.slotType -eq 'Texture' -and $slot.slot -eq 'floorAlbedo' -and $slot.value) { $out.Albedo = $slot.value }
        if ($slot.slotType -eq 'Texture' -and $slot.slot -eq 'floorNormal' -and $slot.value) { $out.Normal = $slot.value }
    } } }
    return $out
}
function Set-FloorAlbedo { # Points a floor's albedo texture at another texture; everything else stays.
    param([Parameter(Mandatory)]$Model, [Parameter(Mandatory)][string]$Albedo)
    foreach ($list in @($Model.variationLists)) { foreach ($v in @($list.variations)) { foreach ($slot in @($v.slots)) {
        if ($slot.slotType -eq 'Texture' -and $slot.slot -eq 'floorAlbedo') { $slot.value = $Albedo }
    } } }
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

    $floors = foreach ($vid in $Cold.Floors) {
        $vanillaFloor = $RawJson.repository | Where-Object { $_.id -eq $vid }
        if (-not $vanillaFloor) { Write-Warning "Floor '$vid' not found in $($Cold.BaseBuildingRepository); skipped"; continue }
        $id = if ($Cold.FloorIdOverride.ContainsKey($vid)) { $Cold.FloorIdOverride[$vid] } else { "cold_$vid" }
        $floorClone = New-DeepCopy $vanillaFloor
        $floorClone.id = $id
        $floorClone.iconPath = "phrontisteries_cold_$vid"                 # recipes\Cold\Sprites\<iconPath>.png
        $floorClone | Add-Member -NotePropertyName defaultThermalModelID -NotePropertyValue $Cold.ThermalModelId -Force
        $floorClone.locKeys = @(Get-ColdLocKeys -Id $id -InfoKey $vanillaFloor.locKeys[0].info)
        if ($Cold.FloorMenuGroup) { $floorClone.buildingSubCategoryUI = $Cold.FloorMenuGroup }   # own build-menu group

        $own = Get-FloorTextures $vanillaFloor
        $texture = if ($own.Albedo) { $Cold.FloorOwnTexture -f $vid } else { $Cold.FloorSheet }
        if (Test-ModAddressables "Cold" -Asset $texture) {
            Set-FloorAlbedo -Model $floorClone -Albedo $texture             # frosted elements; square, bump map, tiling unchanged
            if (-not $own.Albedo) {                                         # the sheet copy has the floor's tint baked in
                Set-ShaderParam -Model $floorClone -Name "_FloorColorMultiply" -Value "#FFFFFF"
                Set-ShaderParam -Model $floorClone -Name "_FloorColorAdd" -Value "#000000"
            }
            Set-ShaderParam -Model $floorClone -Name "_ElementColor" -Value $Cold.FloorEdgeColor   # frosted edge rails
        }
        else {
            Set-ShaderParam -Model $floorClone -Name "_FloorColorMultiply" -Value $Cold.FloorTintMultiply
            Set-ShaderParam -Model $floorClone -Name "_FloorColorAdd" -Value $Cold.FloorTintAdd
        }
        $floorClone
    }

    # Light-blue shelf, once its Addressables are built (unity\README.md); until then the vanilla wooden look.
    if (Test-ModAddressables "Cold" -Asset $Cold.ShelfTexture) { Set-ModelTexture -Model $shelfClone -Texture $Cold.ShelfTexture }

    return @{ repository = @(@($shelfClone) + @($floors)) }
}
