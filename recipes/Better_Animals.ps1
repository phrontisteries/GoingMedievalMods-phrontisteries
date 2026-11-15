# SPDX-License-Identifier: MIT  (Copyright (c) 2026 phrontisteries; see LICENSE)
$carryCapacityMultiplier = 100
$populationControl = @{
#   deer    =   10
#   hare    =   15
    wolf    =   12  # 8
#   boar    =   8
    pheasant=   "2x"  # 15
#   mallard =   15
#   fox     =   10
#   rat     =   15
#   water_vole= 15
#   polecat =   10
#   cow     =   12
#   goat    =   12
#   sheep   =   12
#   donkey  =   10
#   cow     =   12
    chicken =   "2x"    # 15
#   cat     =   10
#   dog     =   10
    bear    =   10      # 3
}
$eatThese = @("shrub_generic", "shrub_ivy", "hay_patch", "reed_patch", "mushroom_patch", "hay", "animal_feed")
function Set-Better_Animals_ModInfo {
    # Process will use first available: HERE, existing ModInfo.json (auto-versioning), lastly as generic defaults
    return @{
        # id          = "phrontisteries.better_animals"
        # name        = "Better Animals"
        description = @"
Animals (all): Tame-Pen-Train-Haul-Attack, Haul $($carryCapacityMultiplier)x.
Population changes (max): $($script:populationControlChanges).
Eat only $(Get-EatTheseDescription).
Cat pest control: rat, polecat, water_vole ONLY.
Workers: can now haul $($script:humanCarry) (new people; not enemies).
"@
        # author      = "phrontisteries"
        # modVersion  = "0.99.99.99"
        # gameVersion = "0.28.38"
        tags        = @("General")
    }
}
$jsonReplace = @{ # must be [hashtable] (*NOT [PSCustomObject])
    'DietModelRepository' = @(
@('"phases":\s*\[([^\]]*)\]','"phases": [$1]'),
@('"phases": \[(.*?)\]',{'"phases": [ '+($args[0].Groups[1].Value -replace '[\r\n\t]', '')+' ] '}),
@('"phases": \[(.*?)\]',{'"phases": [ '+($args[0].Groups[1].Value -replace ' { 2, } ', '')+' ] '})
    )
}

function Get-EatTheseDescription {
    $shrubs = @()
    $patches = @()
    $others  = @()
    foreach ($item in $eatThese) {
        if ($item -like "shrub_*") {
            $name = ($item -replace "^shrub_", "") -replace "_", " "
            if ($name -eq "generic") { $shrubs += "shrub" } else { $shrubs += $name }; continue
        }
        if ($item -like "*_patch") {
            $patches += ($item -replace "_patch$", "") -replace "_", " "; continue
        }
        $others += ($item -replace "_", " ")
    }
    $parts = @()
    if ($others.Count -gt 0) { $parts += ($others -join ", ") }
    if ($patches.Count -gt 0) { $parts += "wild: " + ($patches -join ", ") }
    if ($shrubs.Count -gt 0) { $parts += ($shrubs -join ", ") }
    return ($parts -join ", ")
}
function Get-PopulationOverride {
    param(
        [Parameter(Mandatory)][int]$OriginalMaxCount,
        [Parameter(Mandatory)][object]$override
    )
    # Absolute number
    if ($override -is [int]) {
        if ($override -ne $OriginalMaxCount) {
            return $override
        }
        return $null
    }
    # Multiplier: "2x", "0.5x", etc.
    if ($override -is [string] -and $override -match '^([0-9.]+)x$') {
        $factor = [double]$Matches[1]
        $newValue = [int][math]::Round($OriginalMaxCount * $factor)
        if ($newValue -ne $OriginalMaxCount) {
            return $newValue
        }
        return $null
    }
    throw "Invalid population override format for '$AnimalId': $override"
}
function Get-GlobalCaravanRatio {
    param([object]$Raw)
    $ratios = @()
    foreach ($entry in $Raw.repository) {
        foreach ($phase in $entry.lifePhases) {
            $storage = $phase.storageBase.capacity
            $caravan = $phase.caravanStorageCapacity
            if ($storage -gt 0 -and $caravan -gt 0) {
                $ratios += ($caravan / $storage)
            }
        }
    }
    if ($ratios.Count -eq 0) { throw "No caravan ratios found in file." }
    return ($ratios | Measure-Object -Average).Average
}
function Get-CalculatedCaravanCapacity {
    param(
        [Parameter(Mandatory)][object]$Phase,
        [Parameter(Mandatory)][double]$GlobalRatio
    )
    $storage = $Phase.storageBase.capacity
    $caravan = $Phase.caravanStorageCapacity
    if ($caravan -gt 0) { return $caravan }
    return [math]::Round($storage * $GlobalRatio)
}
function Build-Better_Animals_AnimalBase {
    param([object]$RawJson)
    $globalRatio = Get-GlobalCaravanRatio -Raw $RawJson
    Write-Host "(caravan $([math]::Round($globalRatio,2))x) " -NoNewline
    $flags = @(
        'canBeTamed',
        'canBeInPen',
        'canBeTrained',
        'canHaulAsPet',
        'canAttackAsPet'
    )
    $script:populationControlChanges = ""
    $out = @()
    foreach ($entry in $RawJson.repository) {
        $patch = [ordered]@{
            id                 = $entry.id
            chanceForPregnancy = 0.5
        }
        # Population override (only if: defined globally, maxCount exists, AND override applies)
        if ($entry.PSObject.Properties.Name -contains 'maxCount' -and $populationControl.ContainsKey($entry.id)) {
            $newMax = Get-PopulationOverride $entry.maxCount $populationControl[$entry.id]
            if ($null -ne $newMax) {
                $patch.maxCount = $newMax
                if ($script:populationControlChanges -ne "") { $script:populationControlChanges += ", " }
                $script:populationControlChanges += "$($entry.id) ($newMax)"
            }
        }
        # Only output flags that were originally false
        foreach ($flag in $flags) {
            if ($entry.$flag -eq $false) {
                $patch[$flag] = $true
            }
        }
        # Carry Capacity Change: Life phase patches
        $phasePatches = @()
        foreach ($phase in $entry.lifePhases) {
            $newCaravan = Get-CalculatedCaravanCapacity -Phase $phase -GlobalRatio $globalRatio
            $phasePatches += [ordered]@{
                phaseName              = $phase.phaseName
                storageBase            = @{
                    capacity = [int]($phase.storageBase.capacity * $carryCapacityMultiplier)
                }
                caravanStorageCapacity = [int]($newCaravan * $carryCapacityMultiplier)
            }
        }
        $patch.lifePhases = $phasePatches
        $out += [pscustomobject]$patch
    }
    return @{ repository = $out }
}
function Build-Better_Animals_HumanType {
    param( [Parameter(Mandatory)][object]$RawJson )
    $TargetId = "worker"
    $entry = $RawJson.repository | Where-Object { $_.id -eq $TargetId }
    $OriginalValue = $entry.storageBase.capacity
    $script:humanCarry = [int]([math]::Round($OriginalValue * $carryCapacityMultiplier))
    return [ordered]@{
        repository = @(
            [ordered]@{
                id          = $TargetId
                storageBase = @{
                    capacity = $script:humanCarry
                }
            }
        )
    }
}
function Compare-DietObjects {
    param(
        [Parameter(Mandatory)][object]$A,
        [Parameter(Mandatory)][object]$B
    )
    # Order to keep: More Phases , Higher Priority , neither (return the first)
    if (@($B.phases).Count -gt @($A.phases).Count -or $B.priority -gt $A.priority) { return $B }
    return $A
}
<# function Build-Better_Animals_DietModelRepository {
    param( [Parameter(Mandatory)][object]$RawJson )
    $animalIds = $RawJson.repository | Where-Object { $_.id -like "animal_*" }
    $best = @{}
    foreach ($entry in $animalIds) {
        foreach ($dietObj in $entry.dietResources) {
            $value = $dietObj.value
            if ($EatThese -notcontains $value) { continue } # Skip if not in allowed list
            if (-not $best.ContainsKey($value)) { # If first time seeing this value, store it
                $best[$value] = $dietObj
                continue
            }
            $best[$value] = Compare-DietObjects $best[$value] $dietObj
        }
    }
    $out = @()
    foreach ($entry in $animalIds) {
        $patch = [ordered]@{
            id            = $entry.id
            dietResources = $best.Values
        }
        $out += [pscustomobject]$patch
    }
    return @{ repository = $out }
} #>
function Build-Better_Animals_DietModelRepository {
    param( [Parameter(Mandatory)][object]$RawJson )
    $animalIds = $RawJson.repository | Where-Object { $_.id -like "animal_*" }
    $best = @{}
    foreach ($entry in $animalIds) {
        foreach ($dietObj in $entry.dietResources) {
            $value = $dietObj.value
            if ($eatThese -notcontains $value) { continue }
            if (-not $best.ContainsKey($value)) { $best[$value] = $dietObj; continue }
            $best[$value] = Compare-DietObjects $best[$value] $dietObj
        }
    }
    $out = @()
    foreach ($entry in $animalIds) {
        $removeList = @()
        foreach ($dietObj in $entry.dietResources) {
            if ($eatThese -notcontains $dietObj.value) { $removeList += $dietObj }
        }
        $existingValues = $entry.dietResources.value
        $missing = $eatThese | Where-Object { $existingValues -notcontains $_ }
        $appendList = @()
        foreach ($value in $missing) { if ($best.ContainsKey($value)) { $appendList += $best[$value] } }
        $patch = [ordered]@{ id = $entry.id }
        if ($removeList.Count -gt 0) { $patch["dietResources#REMOVE"] = $removeList }
        if ($appendList.Count -gt 0) { $patch["dietResources#APPEND"] = $appendList }
        $out += [pscustomobject]$patch
    }
    # Compress-JSONToSingleLine $out 'phases'
    return @{ repository = $out }
}
function Build-Better_Animals_AnimalAttackGroupRepository {
    return @{
        repository = @(
            @{
                id = "cat_pest_control"
                entries = @(
                    @{
                        type = "Animals"
                        values = @("rat","polecat","water_vole")
                        wild = $true
                        domestic = $false
                        pet = $false
                        priority = "100"
                        priorityPerDistanceUnit = "0.1"
                    }
                )
            }
        )
    }
}