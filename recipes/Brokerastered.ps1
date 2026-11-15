# SPDX-License-Identifier: MIT  (Copyright (c) 2026 phrontisteries; see LICENSE)
# Brokerastered: the Broker role trades and bargains better, negotiates cheaper, mines faster and more,
# and prefers trading, crafting, mining and art work.
#  - Effectors.json: source recipe recipes\Brokerastered\Effectors.json (#APPEND onto the role's effects)
#  - Role.json: built here from the CURRENT game's full Broker role levels, changing only goalPreferences,
#    so the role's requirements (treasury, skills, furniture) and its assign effects are always kept.

$script:Broker = [ordered]@{
    RoleId = "broker"
    # Work preferences removed at every role level (any value)
    RemovePreferences = @("PhysicalLabourPreference", "AnimalPreference", "MeleeCombatPreference", "RangedCombatPreference")
    # Work preferences added at every role level
    AddPreferences    = [ordered]@{ TradingPreference = 5; CraftingPreference = 5; MiningPreference = 5; ArtPreference = 5 }
}

function Build-Brokerastered_Role {
    param( [Parameter(Mandatory)]$RawJson )
    $role = $RawJson.repository | Where-Object { $_.id -eq $Broker.RoleId }
    if (-not $role) { throw "Role '$($Broker.RoleId)' not found in Role.json" }
    $levels = New-DeepCopy $role.roleLevels
    foreach ($level in @($levels)) {
        $prefs = @($level.goalPreferences | Where-Object { $Broker.RemovePreferences -notcontains $_.key -and -not $Broker.AddPreferences.Contains($_.key) })
        foreach ($k in $Broker.AddPreferences.Keys) { $prefs += [pscustomobject]@{ key = $k; value = $Broker.AddPreferences[$k] } }
        $level.goalPreferences = $prefs
    }
    return @{ repository = @([ordered]@{ id = $Broker.RoleId; roleLevels = @($levels) }) }
}
