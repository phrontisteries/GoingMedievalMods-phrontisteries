# SPDX-License-Identifier: MIT  (Copyright (c) 2026 phrontisteries; see LICENSE)
# More Creation Points: new settlers get more creation points, more possible perks and more passions.
# GenerationRules.json is a single settings object, so it is built from the CURRENT game's file
# with only these values changed; everything else stays as the game ships it.

$script:Creation = [ordered]@{
    MaxCreationPoints = 1000   # game: 90
    MaxPerks          = 40     # per age category (game: 2-5)
    MaxPassions       = 20     # per passion level (game: 2-4)
}

function Set-More_Creation_Points_ModInfo {
    return @{
        name = "More Creation Points"
        tags = @("General")
    }
}

function Build-More_Creation_Points_GenerationRules {
    param( [Parameter(Mandatory)]$RawJson )
    $out = New-DeepCopy $RawJson
    $rules = $out.repository[0]
    if (-not $rules) { throw "GenerationRules.json has no settings object" }
    $rules.maxCreationPoints = $Creation.MaxCreationPoints
    foreach ($cat in @($rules.ageCategories)) { if ($cat.possiblePerks) { $cat.possiblePerks.max = $Creation.MaxPerks } }
    foreach ($p in @($rules.passions)) { if ($null -ne $p.max) { $p.max = $Creation.MaxPassions } }
    return $out
}
