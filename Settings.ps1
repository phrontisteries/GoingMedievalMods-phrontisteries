# SPDX-License-Identifier: MIT  (Copyright (c) 2026 phrontisteries; see LICENSE)
# Shared settings for MakeMod.ps1 and the tools. Change these to YOUR details,
# or set the environment variables so you don't have to edit this file.

# Unique identifier used in new mod ids (author.modname) and ModInfo.json "author".
$Global:Author = if ($env:GM_AUTHOR) { $env:GM_AUTHOR } else { "phrontisteries" }

# Public repository linked at the end of every mod description (leave empty for no link).
$Global:RepoUrl = if ($null -ne $env:GM_REPO_URL) { $env:GM_REPO_URL } else { "https://github.com/phrontisteries/GoingMedievalMods-phrontisteries" }

# The game's StreamingAssets folder (source of the vanilla JSON every recipe starts from).
$Global:StreamingAssets = if ($env:GM_STREAMING_ASSETS) { $env:GM_STREAMING_ASSETS } else {
    "C:\Program Files (x86)\Steam\steamapps\common\Going Medieval\Going Medieval_Data\StreamingAssets"
}

# Reads the installed game's version (x.y.z) from globalgamemanagers, next to StreamingAssets.
function Get-GameVersion {
    $ggmPath = Join-Path (Split-Path $Global:StreamingAssets -Parent) "globalgamemanagers"
    if (-not (Test-Path $ggmPath)) { throw "globalgamemanagers not found at '$ggmPath'" }
    $fs = [System.IO.File]::OpenRead($ggmPath)
    try {
        $buffer = New-Object byte[] 65536   # the version appears in the first 64 KB
        $bytesRead = $fs.Read($buffer, 0, $buffer.Length)
    } finally { $fs.Close() }
    $text = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $bytesRead)
    $match = [regex]::Match($text, "\b\d+\.\d+\.\d+\b")
    if (-not $match.Success) { throw "Unable to extract game version from globalgamemanagers" }
    return $match.Value
}
$Global:GameVersion = try { Get-GameVersion } catch { Write-Warning $_; $null }

# ---- JSON file helpers: identical results in Windows PowerShell 5.1 and PowerShell 7+ ----
# Windows PowerShell 5.1 adds a "Count" member to arrays that makes ConvertTo-Json write {"value":[..],"Count":n}.
if ($PSVersionTable.PSVersion.Major -lt 6) { Remove-TypeData System.Array -ErrorAction SilentlyContinue }

function Read-JsonFile { # Reads UTF-8 (with or without BOM) regardless of the PowerShell version's default encoding.
    param([Parameter(Mandatory)][string]$Path)
    $text = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $Path).ProviderPath, [System.Text.Encoding]::UTF8)
    return (ConvertFrom-Json -InputObject $text)
}

function Format-Json { # Pretty-prints compact JSON with 2-space indents, the same layout PowerShell 7 writes.
    param([Parameter(Mandatory)][string]$Json)
    $sb = New-Object System.Text.StringBuilder ($Json.Length * 2)
    $indent = 0; $inString = $false; $i = 0; $n = $Json.Length
    $nl = "`r`n"
    while ($i -lt $n) {
        $c = $Json[$i]
        if ($inString) {
            if ($c -eq '\') {
                $next = $Json[$i + 1]
                if ($next -eq 'u' -and $i + 5 -lt $n) {
                    # 5.1 escapes ' < > & and some others as \uXXXX; write them as plain characters like PowerShell 7 does.
                    $code = [Convert]::ToInt32($Json.Substring($i + 2, 4), 16)
                    if ($code -ge 0x20 -and $code -ne 0x22 -and $code -ne 0x5C -and ($code -lt 0xD800 -or $code -gt 0xDFFF)) { [void]$sb.Append([char]$code) }
                    else { [void]$sb.Append($Json, $i, 6) }
                    $i += 6; continue
                }
                [void]$sb.Append($c).Append($next); $i += 2; continue
            }
            if ($c -eq '"') { $inString = $false }
            [void]$sb.Append($c); $i++; continue
        }
        switch ($c) {
            '"' { $inString = $true; [void]$sb.Append($c) }
            { $_ -eq '{' -or $_ -eq '[' } {
                $close = if ($c -eq '{') { '}' } else { ']' }
                $j = $i + 1; while ($j -lt $n -and [char]::IsWhiteSpace($Json[$j])) { $j++ }
                if ($j -lt $n -and $Json[$j] -eq $close) { [void]$sb.Append($c).Append($close); $i = $j }   # {} or []
                else { $indent++; [void]$sb.Append($c).Append($nl).Append('  ' * $indent) }
            }
            { $_ -eq '}' -or $_ -eq ']' } { $indent--; [void]$sb.Append($nl).Append('  ' * $indent).Append($c) }
            ',' { [void]$sb.Append(',').Append($nl).Append('  ' * $indent) }
            ':' { [void]$sb.Append(': ') }
            default { if (-not [char]::IsWhiteSpace($c)) { [void]$sb.Append($c) } }
        }
        $i++
    }
    return $sb.ToString()
}

function ConvertTo-StableOrder { # Plain @{} hashtables have no stable key order (it differs per run and per PowerShell version):
    param([AllowNull()]$Node)      # give them one ("id" first, then alphabetical). Ordered and PSCustomObject keep theirs.
    if ($Node -is [System.Collections.Specialized.OrderedDictionary]) {
        $o = [ordered]@{}; foreach ($k in $Node.Keys) { $o[$k] = ConvertTo-StableOrder $Node[$k] }; return $o
    }
    if ($Node -is [System.Collections.IDictionary]) {
        $keys = @($Node.Keys | Sort-Object { if ($_ -eq 'id') { '' } else { [string]$_ } })
        $o = [ordered]@{}; foreach ($k in $keys) { $o[$k] = ConvertTo-StableOrder $Node[$k] }; return $o
    }
    if ($Node -is [System.Management.Automation.PSCustomObject]) {
        $o = [ordered]@{}; foreach ($p in $Node.PSObject.Properties) { $o[$p.Name] = ConvertTo-StableOrder $p.Value }; return [pscustomobject]$o
    }
    if ($Node -is [System.Collections.IEnumerable] -and $Node -isnot [string]) {
        return ,@(foreach ($item in $Node) { ConvertTo-StableOrder $item })
    }
    return $Node
}

function ConvertTo-ModJson { # Object -> formatted JSON text (use instead of ConvertTo-Json when writing files)
    param([Parameter(Mandatory)][AllowNull()]$InputObject, [int]$Depth = 100)
    $stable = ConvertTo-StableOrder $InputObject
    return (Format-Json (ConvertTo-Json -InputObject $stable -Depth $Depth -Compress))
}

function Write-JsonFile { # Writes formatted JSON as UTF-8 without BOM, CRLF line endings.
    param([Parameter(Mandatory)][AllowNull()]$InputObject, [Parameter(Mandatory)][string]$Path, [int]$Depth = 100)
    Write-TextFile -Text ((ConvertTo-ModJson -InputObject $InputObject -Depth $Depth) + "`r`n") -Path $Path
}

function Write-TextFile { # UTF-8 without BOM in every PowerShell version.
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text, [Parameter(Mandatory)][string]$Path)
    $full = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)
    [System.IO.File]::WriteAllText($full, $Text, (New-Object System.Text.UTF8Encoding $false))
}
