# SPDX-License-Identifier: MIT  (Copyright (c) 2026 phrontisteries; see LICENSE)
# Urgent Haul - Bodies: burying, burning (carcass disposal) and stripping bodies move from the
# Hauling job to the Urgent Haul job, so they are done first.
#  - goals use #REMOVE / #APPEND, so any other goals the game adds to these jobs later are kept
#  - the job tooltips are rebuilt from the CURRENT game's text keys with the matching lines moved

$script:UrgentBody = [ordered]@{
    FromJobId = 1        # Hauling
    ToJobId   = 524288   # Urgent Haul
    Goals     = @("BuryBodyGoal", "ProductionCarcassDisposalGoal", "StripCarcassGoal")
    Tooltips  = @("name_prod_burning_carcass", "worker_action_burybodygoal")
}

function Set-Urgent_Body_ModInfo {
    return @{
        tags = @("General")
    }
}

function Get-UrgentBodyLocKeys {
    param( $Job, [switch]$Add )
    $keys = New-DeepCopy @($Job.locKeys)
    foreach ($k in $keys) {
        $lines = @($k.tooltipLines | Where-Object { $UrgentBody.Tooltips -notcontains $_ })
        if ($Add) { $lines += $UrgentBody.Tooltips }
        $k.tooltipLines = $lines
    }
    return ,$keys
}

function Build-Urgent_Body_Job {
    param( [Parameter(Mandatory)]$RawJson )
    $from = $RawJson.repository | Where-Object { $_.id -eq $UrgentBody.FromJobId }
    $to   = $RawJson.repository | Where-Object { $_.id -eq $UrgentBody.ToJobId }
    if (-not $from -or -not $to) { throw "Hauling or Urgent Haul job not found in Job.json" }
    $missing = @($UrgentBody.Goals | Where-Object { @($from.goals) -notcontains $_ })
    if ($missing) { Write-Warning "Hauling no longer has goal(s): $($missing -join ', ')" }
    return @{ repository = @(
        [ordered]@{ id = $UrgentBody.FromJobId; locKeys = [object[]]@(Get-UrgentBodyLocKeys $from);    "goals#REMOVE" = $UrgentBody.Goals },
        [ordered]@{ id = $UrgentBody.ToJobId;   locKeys = [object[]]@(Get-UrgentBodyLocKeys $to -Add);   "goals#APPEND" = $UrgentBody.Goals }
    ) }
}
