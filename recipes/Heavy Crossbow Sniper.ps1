# SPDX-License-Identifier: MIT  (Copyright (c) 2026 phrontisteries; see LICENSE)
# Heavy Crossbow Sniper: the heavy crossbow becomes a long-range sniper weapon, and NPCs (raiders, other
# factions) no longer spawn with it. Both files are rebuilt from the CURRENT game data on every build.

$script:Sniper = [ordered]@{
    WeaponId  = "heavy_crossbow"
    # Primary (shooting) mode. Only these fields change; every other field keeps the game's value.
    Primary   = [ordered]@{
        damage           = 360     # vanilla 36
        ignoresArmor     = 1       # vanilla 0.92
        armorDamage      = 0       # vanilla 0.5
        buildingDamage   = 0
        precision        = 1
        precisionFalloff = 0       # vanilla 0.01 per metre
        range            = 45      # vanilla 25
        attackSpeed      = 1       # time between shots; vanilla 13.5
        projectileSpeed  = 13      # vanilla 1.3
        hpLossPerUse     = 0       # no wear; vanilla 1
        loseHpOnMiss     = $false
    }
    # Secondary (melee bash) mode
    Secondary = [ordered]@{
        damage         = 80        # vanilla 8
        ignoresArmor   = 1
        armorDamage    = 0
        buildingDamage = 0
        attackSpeed    = 1         # vanilla 6.3
        hpLossPerUse   = 0
        loseHpOnMiss   = $false
    }
    MeleeCover  = 1                # vanilla 0.25
    RangedCover = 1                # vanilla 0
}

function Set-HeavyCrossbowSniper_ModInfo {
    return @{
        name = "Heavy Crossbow Sniper"
        tags = @("General", "Combat")
    }
}

function Build-HeavyCrossbowSniper_Equipment {
    param( [Parameter(Mandatory)]$RawJson )
    $vanilla = $RawJson.repository | Where-Object { $_.id -eq $Sniper.WeaponId }
    if (-not $vanilla) { throw "'$($Sniper.WeaponId)' not found in Equipment.json" }
    # Weapon modes are objects: a partial object would REPLACE the game's one and drop required fields
    # (projectile, wound effects...), so start from the game's full modes and change only our fields.
    $primary = New-DeepCopy $vanilla.primaryWeaponMode
    foreach ($k in $Sniper.Primary.Keys) { $primary | Add-Member -NotePropertyName $k -NotePropertyValue $Sniper.Primary[$k] -Force }
    $secondary = New-DeepCopy $vanilla.secondaryWeaponMode
    foreach ($k in $Sniper.Secondary.Keys) { $secondary | Add-Member -NotePropertyName $k -NotePropertyValue $Sniper.Secondary[$k] -Force }
    return @{ repository = @([ordered]@{
        id                  = $Sniper.WeaponId
        primaryWeaponMode   = $primary
        secondaryWeaponMode = $secondary
        meleeCover          = $Sniper.MeleeCover
        rangedCover         = $Sniper.RangedCover
    }) }
}

function Build-HeavyCrossbowSniper_NPCPresets {
    param( [Parameter(Mandatory)]$RawJson )
    # Only the presets that carry the weapon, with it removed from their equipment lists (any quality/material,
    # e.g. "sturdy_wood_heavy_crossbow"). itemGroups is a list, so the whole current list is written back.
    $suffix = "_$($Sniper.WeaponId)"
    $out = @()
    foreach ($preset in $RawJson.repository) {
        $groups = New-DeepCopy $preset.itemGroups
        $changed = $false
        foreach ($g in @($groups)) {
            if (-not ($g.PSObject.Properties.Name -contains 'equipment')) { continue }
            $keep = @($g.equipment | Where-Object { -not ([string]$_).EndsWith($suffix) })
            if ($keep.Count -eq @($g.equipment).Count) { continue }
            if ($keep.Count -eq 0) { throw "Preset '$($preset.id)' group '$($g.groupName)' would be left with no equipment" }
            $g.equipment = $keep; $changed = $true
        }
        if ($changed) { $out += [ordered]@{ id = $preset.id; itemGroups = @($groups) } }
    }
    Write-Host "($($out.Count) presets) " -NoNewline
    return @{ repository = $out }
}
