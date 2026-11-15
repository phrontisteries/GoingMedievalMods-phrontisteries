# SPDX-License-Identifier: MIT  (Copyright (c) 2026 phrontisteries; see LICENSE)
<#
.SYNOPSIS
    Checks Going Medieval mod folders against the installed game's data.

.DESCRIPTION
    For every JSON file in <Mod>\Data\Models the checker finds the game file with the same
    name under StreamingAssets and reports:

      ERROR  file   - the game has no file with that name any more.
      ERROR  field  - a field (at any depth) that no entry in the game file uses. Usually a
                      field the game renamed or removed; the game ignores it or fails on it.
      WARN   new    - a model with a new id that lacks fields the closest vanilla model has.
                      New ids must be complete models, so these are often required fields.
      INFO   ref    - a list-operator (#APPEND/#REMOVE) or override on an id the game no
                      longer has.

    Exit code is the number of ERROR lines (0 = clean), so it can gate a build or CI run.

.EXAMPLE
    .\tools\Test-Mods.ps1                       # every mod under .\Mods
    .\tools\Test-Mods.ps1 -Mod Cold,Fish_Farming
    .\tools\Test-Mods.ps1 -StreamingAssets "D:\Games\Going Medieval\Going Medieval_Data\StreamingAssets"
#>
[CmdletBinding()]
param(
    [string[]]$Mod,
    [string]$ModsRoot,
    [string]$StreamingAssets
)

. (Join-Path $PSScriptRoot "..\Settings.ps1")
if (-not $ModsRoot) { $ModsRoot = Join-Path $PSScriptRoot "..\Mods" }
if (-not $StreamingAssets) { $StreamingAssets = $Global:StreamingAssets }
if (-not (Test-Path $StreamingAssets)) { throw "StreamingAssets not found: '$StreamingAssets'. Set it in Settings.ps1 or pass -StreamingAssets." }

$script:errors = 0
$script:gameFiles = @{}
Get-ChildItem -Path $StreamingAssets -Recurse -File -Filter *.json -ErrorAction SilentlyContinue |
    ForEach-Object { if (-not $script:gameFiles.ContainsKey($_.Name)) { $script:gameFiles[$_.Name] = $_.FullName } }

function Get-CleanKey([string]$Key) { return ($Key -replace '#(APPEND|REMOVE)$', '') }

function Add-Paths {
    # Collects every field path in $Node into $Set ("a.b[].c"), ignoring list-operator suffixes.
    param($Node, [string]$Prefix, [System.Collections.Generic.HashSet[string]]$Set)
    if ($Node -is [System.Management.Automation.PSCustomObject]) {
        foreach ($p in $Node.PSObject.Properties) {
            $path = if ($Prefix) { "$Prefix.$(Get-CleanKey $p.Name)" } else { Get-CleanKey $p.Name }
            [void]$Set.Add($path)
            Add-Paths $p.Value $path $Set
        }
    }
    elseif ($Node -is [System.Collections.IEnumerable] -and $Node -isnot [string]) {
        foreach ($item in $Node) { Add-Paths $item "$Prefix[]" $Set }
    }
}

function Get-Paths($Node) {
    $set = New-Object System.Collections.Generic.HashSet[string]
    Add-Paths $Node "" $set
    return $set
}

function Write-Finding([string]$Level, [string]$Kind, [string]$Where, [string]$Text) {
    $color = @{ ERROR = 'Red'; WARN = 'Yellow'; INFO = 'DarkGray' }[$Level]
    if ($Level -eq 'ERROR') { $script:errors++ }
    Write-Host ("  {0,-5} {1,-5} {2}: {3}" -f $Level, $Kind, $Where, $Text) -ForegroundColor $color
}

$modDirs = Get-ChildItem -Path $ModsRoot -Directory | Where-Object { Test-Path (Join-Path $_.FullName "ModInfo.json") }
if ($Mod) { $modDirs = $modDirs | Where-Object { $Mod -contains $_.Name } }

foreach ($dir in $modDirs) {
    Write-Host "== $($dir.Name)" -ForegroundColor Cyan
    $info = Read-JsonFile (Join-Path $dir.FullName "ModInfo.json")
    if ($info.gameVersion -and $Global:GameVersion -and $info.gameVersion -ne $Global:GameVersion) {
        Write-Finding WARN ver "ModInfo.json" "gameVersion $($info.gameVersion), game is $($Global:GameVersion)"
    }
    $models = Join-Path $dir.FullName "Data\Models"
    foreach ($file in Get-ChildItem -Path $models -Filter *.json -File -ErrorAction SilentlyContinue) {
        if (-not $script:gameFiles.ContainsKey($file.Name)) {
            Write-Finding ERROR file $file.Name "no game file with this name"; continue
        }
        $modJson = Read-JsonFile $file.FullName
        $gameJson = Read-JsonFile $script:gameFiles[$file.Name]

        if ($gameJson.PSObject.Properties.Name -contains 'repository' -and $modJson.PSObject.Properties.Name -contains 'repository') {
            $byId = @{}
            foreach ($e in $gameJson.repository) { if ($e.id) { $byId[[string]$e.id] = $e } }
            $known = Get-Paths $gameJson.repository   # every path any vanilla entry uses ("[].x.y")
            foreach ($entry in $modJson.repository) {
                $id = [string]$entry.id
                $where = "$($file.Name) '$id'"
                foreach ($p in (Get-Paths @($entry))) {
                    if (-not $known.Contains($p)) { Write-Finding ERROR field $where "'$($p.TrimStart('[]').TrimStart('.'))' is not used anywhere in the game file" }
                }
                if ($byId.ContainsKey($id)) { continue }   # override of an existing model: partial is fine
                $ops = $entry.PSObject.Properties.Name | Where-Object { $_ -match '#(APPEND|REMOVE)$' }
                if ($ops) { Write-Finding INFO ref $where "uses $($ops -join ', ') but the game has no model with this id"; continue }
                # New id: compare top-level fields with the most similar vanilla model.
                $mine = @($entry.PSObject.Properties.Name)
                $best = $null; $bestScore = -1
                foreach ($e in $gameJson.repository) {
                    $theirs = @($e.PSObject.Properties.Name)
                    $shared = @($mine | Where-Object { $theirs -contains $_ }).Count
                    $score = $shared / [math]::Max(1, ($mine + $theirs | Select-Object -Unique).Count)
                    if ($score -gt $bestScore) { $best = $e; $bestScore = $score }
                }
                if ($best) {
                    $missing = @($best.PSObject.Properties.Name | Where-Object { $mine -notcontains $_ })
                    if ($missing) { Write-Finding WARN new $where "new model lacks fields that closest vanilla '$($best.id)' has: $($missing -join ', ')" }
                }
            }
        }
        else {
            $known = Get-Paths $gameJson
            foreach ($p in (Get-Paths $modJson)) {
                if (-not $known.Contains($p)) { Write-Finding ERROR field $file.Name "'$p' is not in the game file" }
            }
        }
    }

    # Rule: a shelf that shows its items needs one display slot per pile, filed under the storage id
    # (the game's own shelves all follow this; breaking it caused Cold's NullReferenceException on load).
    $shelfPath = Join-Path $models "ShelfComponentRepository.json"
    if (Test-Path $shelfPath) {
        $piles = @{}
        foreach ($src in @($script:gameFiles["UniversalStorage.json"], (Join-Path $models "UniversalStorage.json"))) {
            if ($src -and (Test-Path $src)) { foreach ($s in (Read-JsonFile $src).repository) { $piles[[string]$s.id] = $s.maxPileCount } }
        }
        foreach ($shelf in (Read-JsonFile $shelfPath).repository) {
            $sets = @($shelf.multipleTransformSettingsArray)
            if ($sets.Count -eq 0) { continue }   # hidden storage (chests) shows no items
            foreach ($storageId in @($shelf.storageIDs)) {
                $set = $sets | Where-Object { $_.id -eq $storageId } | Select-Object -First 1
                $where = "ShelfComponentRepository.json '$($shelf.id)'"
                if (-not $set) { Write-Finding ERROR rule $where "no display slots filed under storage id '$storageId' (slot sets: $(($sets.id) -join ', '))"; continue }
                $slots = @($set.transformSettingsArray).Count
                if ($piles.ContainsKey($storageId) -and $slots -ne $piles[$storageId]) {
                    Write-Finding ERROR rule $where "'$storageId' holds $($piles[$storageId]) piles but has $slots display slots"
                }
            }
        }
    }
}
Write-Host ""
Write-Host "$($script:errors) error(s)" -ForegroundColor ($(if ($script:errors) { 'Red' } else { 'Green' }))
exit $script:errors
