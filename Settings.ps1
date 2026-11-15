# Shared settings for MakeMod.ps1 and the tools. Change these to YOUR details,
# or set the environment variables so you don't have to edit this file.

# Unique identifier used in new mod ids (author.modname) and ModInfo.json "author".
$Global:Author = if ($env:GM_AUTHOR) { $env:GM_AUTHOR } else { "phrontisteries" }

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
