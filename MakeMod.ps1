<# Going Medieval Mod Scriptor
    Author: phrontisteries
    Last Modified: 2026-11-15
    Version: 0.7
    Requires: PowerShell 7+

    How To Use:

    1. Set your Author name and the game's StreamingAssets location in Settings.ps1
       (or set the GM_AUTHOR / GM_STREAMING_ASSETS environment variables).
    2. Every mod has a recipe in .\recipes: <ModName>.ps1, and/or a folder .\recipes\<ModName>\ of source JSON.
    3. Run:  .\MakeMod.ps1                 (menu)
             .\MakeMod.ps1 -ModName Cold    (one mod)
             .\MakeMod.ps1 -All             (every recipe, e.g. after a game update)
       Output goes to .\Mods\<ModName>\ (ModInfo.json, Preview.png, Data\Models\*.json).
    4. Check the result against the game:  .\tools\Test-Mods.ps1

    Versioning attempts to match the game: v = your version, x.y.z = game version, creates mod version: x.v.y.z
    (auto-increments v on the same game version, resets v to 0 when the game version changes).

    RECIPE SCRIPT  (.\recipes\<ModName>.ps1)
    In function names, <ModName> is the folder name with spaces and other symbols removed
    (e.g. "Mushroom Cropfield" -> Build-MushroomCropfield_Research).

function Set-BetterEnemySurrender_ModInfo { # Process will use first available: HERE, existing ModInfo.json (auto-versioning), lastly as generic defaults
    return @{
        # id          = "phrontisteries.betterenemysurrender"
        # name        = "Better Enemy Surrender" # Names will be created from the ModName spaced on Capital Letters (if this is blank or the mod does not already exist)
        description = "Tweaks surrender logic for more realistic behavior."
        # author      = "phrontisteries"
        # modVersion  = "0.3.28.38"
        # gameVersion = "0.28.38"
        tags        = @("General", "AI", "Combat")
    }
}
    Then create any additional logic functions you want ( One Per File that you will reference/create )
    NAME THEM THIS WAY: "Build-<ModName>_<FileYouWantToModify>". Do not include extention or path, it will find the file if it exists.
    The function receives the CURRENT vanilla file as -RawJson and returns the mod's version of the file.
    As example:
function Build-BetterEnemySurrender_RaidSurrenderChanceBySettlersAlive { # Reads the original JSON, applies softened curve, returns a new JSON object with identical structure.
    param([object]$RawJson)
    function Get-SoftenedValue { # Applies the √-linear softened curve using anchors: 3 → 0.5 , 8 → 1.0
        param([double]$x)
        $x1 = 3 ; $y1 = 0.5
        $x2 = 8 ; $y2 = 1.0
        $t = ($x - $x1) / ($x2 - $x1)
        $linear = $y1 + ($y2 - $y1) * $t
        if ($linear -lt 0) { $linear = 0 }
        return [math]::Sqrt($linear)
    }
    $newList = foreach ($k in 3..38) { # Generate keys 3 through 38 (should end at 2)
        [pscustomobject]@{
            key   = $k
            value = [math]::Round((Get-SoftenedValue $k), 6)
        }
    }
    return [pscustomobject]@{
        threshold = $RawJson.threshold
        list      = $newList
    }
}

    SOURCE JSON  (.\recipes\<ModName>\<File>.json)  - no code needed
    Any JSON file here is built into the mod unless a Build-<ModName>_<File> function exists for it.
    Entries are copied as written, except an entry with "#template": "<vanilla id>": it is rebuilt from
    the CURRENT vanilla model with that id, and then the fields you wrote replace the vanilla ones.
    Use it for every NEW id (new ids must be complete models; the template keeps them complete
    when the game adds fields). Write only the fields you change.

    {
      "repository": [
        { "#template": "fermenting_mash", "id": "fermenting_apple_cider", "iconPath": "fermenting_apple_cider" }
      ]
    }

    And remember to enable your Mod in Game! Enjoy!
#>
[CmdletBinding()]
param(
    [string]$ModName,
    [switch]$All
)

. (Join-Path $PSScriptRoot "Settings.ps1")
if (-not $Global:GameVersion) { throw "Game version unknown: check StreamingAssets in Settings.ps1 ('$($Global:StreamingAssets)')" }
$Global:RecipesRoot = Join-Path $PSScriptRoot "recipes"
$Global:ModsRoot = Join-Path $PSScriptRoot "Mods"

# Recommended Languages
# $recommendedLanguages = @("English","Chinese","French","Spanish","German","Russian","Japanese","Portugese","Korean","Polish","Turkish","Italian")

# Helpers for Mod Files
function ConvertTo-PSCustomObject {
    param([Parameter(Mandatory)]$InputObject)

    if ($InputObject -is [System.Collections.IDictionary]) {
        $obj = [PSCustomObject]@{}
        foreach ($key in $InputObject.Keys) {
            $obj | Add-Member -NotePropertyName $key -NotePropertyValue (ConvertTo-PSCustomObject $InputObject[$key])
        }
        return $obj
    }
    elseif ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -notlike '*string*') {
        return @($InputObject | ForEach-Object { ConvertTo-PSCustomObject $_ })
    }
    else {
        return $InputObject
    }
}
function ConvertTo-Hashtable {
    param($obj)
    if ($obj -is [System.Collections.IDictionary]) {
        $h = @{}
        foreach ($k in $obj.Keys) { $h[$k] = ConvertTo-Hashtable $obj[$k] }
        return $h
    }
    elseif ($obj -is [System.Collections.IEnumerable] -and $obj -notlike '*string*') {
        return @($obj | ForEach-Object { ConvertTo-Hashtable $_ })
    }
    return $obj
}
function New-DeepCopy {
    param([Parameter(Mandatory=$true)][object]$InputObject)
    return ($InputObject | ConvertTo-Json -Depth 100 | ConvertFrom-Json)
}
function New-LocKeys {
    param( [string]$NameKey, [string]$InfoKey )
    $obj = [pscustomobject]@{
        languageName = "English"
        name         = $NameKey
    }
    if ($InfoKey) { $obj | Add-Member -MemberType NoteProperty -Name "info" -Value $InfoKey }
    return @($obj)
}
function Compress-JSONToSingleLine {
    param(
        [Parameter(Mandatory=$true)][object]$obj,
        [Parameter(Mandatory=$true)][string]$keyName
    )
    if ($obj -is [System.Collections.IDictionary] -or $obj -is [PSCustomObject]) {
        foreach ($key in $obj.PSObject.Properties.Name) {
            if ($key -eq $keyName -and $obj.$key -is [System.Array]) {
                $obj.$key = ($obj.$key | ConvertTo-Json -Compress); continue
            }
            Compress-JSONToSingleLine $obj.$key $keyName
        }
    } elseif ($obj -is [System.Collections.IEnumerable] -and $obj -isnot [string]) {
        foreach ($item in $obj) { Compress-JSONToSingleLine $item $keyName }
    }
}

# Helpers for THIS file
function Get-ModFunctionName { # "Mushroom Cropfield" -> "MushroomCropfield" (function names cannot hold spaces)
    param([Parameter(Mandatory=$true)][string]$ModName)
    return ($ModName -replace '[^A-Za-z0-9_]', '')
}
function Get-NextModVersion {
    param( [Parameter()][string]$ExistingModVersion ) # x.v.y.z or $null

    # Parse game version: x.y.z
    $gParts = ($Global:GameVersion).Split('.')
    if ($gParts.Count -ne 3) { throw "GameVersion '$($Global:GameVersion)' must be in format x.y.z" }
    $gMajor = [int]$gParts[0]
    $gMinor = [int]$gParts[1]
    $gPatch = [int]$gParts[2]
    if (-not $ExistingModVersion) { $v = 1; return "$($gMajor).$($v).$($gMinor).$($gPatch)" } # First time: v = 1 → x.1.y.z
    $mParts = $ExistingModVersion.Split('.') # Existing: x.v.y.z
    if ($mParts.Count -ne 4) { throw "ExistingModVersion '$ExistingModVersion' must be in format x.v.y.z" }
    $mMajor = [int]$mParts[0]
    $mV     = [int]$mParts[1]
    $mMinor = [int]$mParts[2]
    $mPatch = [int]$mParts[3]
    $existingGameVersion = "$($mMajor).$($mMinor).$($mPatch)"
    if ($existingGameVersion -eq $Global:GameVersion) { # Same game version → bump v
        $mV++; return "$($mMajor).$($mV).$($mMinor).$($mPatch)"
    } else { # Game version changed → reset v to 0, adopt new game version
        $v = 0; return "$($gMajor).$($v).$($gMinor).$($gPatch)"
    }
}
function Invoke-SpacesBeforeCaptialLetters {
    param( [Parameter(Mandatory=$true)][string]$inputString )
    return ([System.Text.RegularExpressions.Regex]::Replace($inputString, '([a-z])([A-Z])', '$1 $2'))
}
function Set-ForcedArray {
    param([Parameter(Mandatory)]$Value)
    return ,$Value   # the unary comma operator
}
function New-ModInfoObject {
    param(
        [Parameter(Mandatory=$true)][string]$ModName,
        [Parameter()][object]$ExistingModInfo,
        [Parameter()][hashtable]$Overrides
    )
    function Use-ExistingOrDefault {
        param(
            [Parameter(Mandatory=$true)][string]$FieldName,
            [Parameter()][object]$Default
        )
        if ($Overrides -and $Overrides.ContainsKey($FieldName)) { return $Overrides[$FieldName] }
        if ($ExistingModInfo -and $ExistingModInfo.PSObject.Properties.Match($FieldName)) {
            return $ExistingModInfo.$FieldName
        }
        return $Default
    }
    $finalId          = Use-ExistingOrDefault "id"          "$($Global:Author).$($ModName.ToLower() -replace ' ', '_')"
    $finalName        = Use-ExistingOrDefault "name"        $(Invoke-SpacesBeforeCaptialLetters $ModName)
    $finalDescription = Use-ExistingOrDefault "description" "$ModName mod for Going Medieval."
    $finalAuthor      = Use-ExistingOrDefault "author"      $Global:Author
    $finalTags        = Use-ExistingOrDefault "tags"        @("General")
    $existingModVersion = $null
    if ($ExistingModInfo -and $ExistingModInfo.modVersion) {
        $existingModVersion = [string]$ExistingModInfo.modVersion
    }
    $finalModVersion = if ($Overrides -and $Overrides.ContainsKey("modVersion")) {
        $Overrides["modVersion"]
    } else {
        Get-NextModVersion -ExistingModVersion $existingModVersion
    }
    # gameVersion always follows the installed game (the files were just rebuilt from it) unless a recipe pins it.
    $finalGameVersion = if ($Overrides -and $Overrides.ContainsKey("gameVersion")) { $Overrides["gameVersion"] } else { $Global:GameVersion }

    return [pscustomobject]@{
        id          = $finalId
        name        = $finalName
        description = ($finalDescription -replace '\\\\n', '\n')
        author      = $finalAuthor
        modVersion  = $finalModVersion
        gameVersion = $finalGameVersion
        tags        = ,$finalTags
    }
}
function Get-JSONGameFile{
    param(
        [Parameter(Mandatory=$true)][string]$SourceFileName
    )
    $found = Get-ChildItem -Path $Global:StreamingAssets -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $SourceFileName } | Select-Object -First 1
    if (-not $found) { throw "Source file '$SourceFileName' was not found." }
    $sourcePath = $found.FullName
    Write-Host "Found Source File" -NoNewline -ForegroundColor Green
    return (Get-Content $sourcePath -Raw | ConvertFrom-Json)
}
function Merge-WithTemplate { # Copy of the vanilla model, with the fields written in $Entry replacing the vanilla ones.
    param(
        [Parameter(Mandatory=$true)][object]$Entry,
        [Parameter(Mandatory=$true)][object]$RawJson,
        [Parameter(Mandatory=$true)][string]$FileName
    )
    $templateId = $Entry.'#template'
    $vanilla = $RawJson.repository | Where-Object { $_.id -eq $templateId } | Select-Object -First 1
    if (-not $vanilla) { throw "Template '$templateId' (for '$($Entry.id)') was not found in the game's $FileName" }
    $out = New-DeepCopy $vanilla
    foreach ($p in $Entry.PSObject.Properties) {
        if ($p.Name -eq '#template') { continue }
        $out | Add-Member -NotePropertyName $p.Name -NotePropertyValue $p.Value -Force
    }
    return $out
}
function Build-FromSource { # Builds one mod file from .\recipes\<ModName>\<File>.json (see "SOURCE JSON" above).
    param(
        [Parameter(Mandatory=$true)][string]$SourcePath,
        [Parameter(Mandatory=$true)][object]$RawJson
    )
    $source = Get-Content $SourcePath -Raw | ConvertFrom-Json
    if (-not ($source.PSObject.Properties.Name -contains 'repository')) { return $source }
    $fileName = Split-Path $SourcePath -Leaf
    $built = foreach ($entry in $source.repository) {
        if ($entry.PSObject.Properties.Name -contains '#template') { Merge-WithTemplate $entry $RawJson $fileName } else { $entry }
    }
    $out = New-DeepCopy $source
    $out.repository = @($built)
    return $out
}

# Create the Mod
function New-Mod {
    param([Parameter(Mandatory=$true)][string]$ModName)

    $fn = Get-ModFunctionName $ModName
    $sourceDir = Join-Path $Global:RecipesRoot $ModName
    $hasSource = Test-Path $sourceDir -PathType Container

    # Ensure and Load Mod specific functions and file details
    $modScript = Join-Path $Global:RecipesRoot "$($ModName).ps1"
    if (Test-Path $modScript) {
        . $modScript   # dot-source to load functions into scope
        Write-Host "Mod Configuration Script Loaded: " -NoNewline -ForegroundColor Green
        Write-Host "'" -NoNewline
        Write-Host "$($ModName).ps1" -NoNewline -ForegroundColor Cyan
        Write-Host "'" -NoNewline
    } elseif (-not $hasSource) { throw "No recipe for '$ModName': expected '$modScript' and/or folder '$sourceDir'." }

    # Work list: file base name -> Build function name, or source JSON path
    $work = [ordered]@{}
    if ($hasSource) {
        foreach ($f in Get-ChildItem -Path $sourceDir -Filter *.json -File) { $work[$f.BaseName] = $f.FullName }
    }
    # Find all functions matching Build-<ModName>_* (these win over a source file of the same name)
    $pattern = "Build-$($fn)_*"
    foreach ($func in Get-Command -CommandType Function | Where-Object { $_.Name -like $pattern }) {
        $work[($func.Name -replace "^Build-$($fn)_", "")] = $func.Name
    }
    if ($work.Count -eq 0) { throw " No build functions or source files found for mod '$ModName'." }
    Write-Host " ... " -NoNewline
    Write-Host "Builds $($work.Count) File" -NoNewline -ForegroundColor DarkGreen
    if($work.Count -gt 1){ Write-Host "s" -NoNewline -ForegroundColor DarkGreen }
    Write-Host ":" -ForegroundColor DarkGreen
    foreach ($k in $work.Keys) {
        $how = if ($work[$k] -like "Build-*") { $work[$k] } else { "recipes\$ModName\$k.json" }
        Write-Host " - $how " -NoNewline -ForegroundColor Cyan
        Write-Host "-> '" -NoNewline
        Write-Host "$($k).json" -NoNewline -ForegroundColor Yellow
        Write-Host "'"
    }

    $modRoot = Join-Path $Global:ModsRoot $ModName
    $modData = Join-Path $modRoot "Data\Models"
    $null = New-Item -ItemType Directory -Force -Path $modData

    foreach ($fileBase in $work.Keys) {
        $fileName = "$($fileBase).json"

        Write-Host "Processing: '$fileName' ... " -NoNewline -ForegroundColor Yellow
        $raw = Get-JSONGameFile $fileName
        Write-Host " - " -NoNewline
        Write-Host "Creating Mod File ... " -NoNewline -ForegroundColor Yellow

        # Run the function, or build from the source JSON
        $modified = if ($work[$fileBase] -like "Build-*") { & $work[$fileBase] -RawJson $raw } else { Build-FromSource -SourcePath $work[$fileBase] -RawJson $raw }
        $newPath = Join-Path $modData $fileName
        $null = New-Item -ItemType Directory -Force -Path (Split-Path $newPath)
        $json = $modified | ConvertTo-Json -Depth 100
        if($jsonReplace -and $jsonReplace.ContainsKey($fileBase)) {
            Write-Host "(Fix Format" -NoNewline
            foreach ($pair in $jsonReplace[$fileBase]) {
                if ($pair[1] -is [scriptblock]) { # dynamic replacement
                    $json = $json -replace $pair[0], { param($m) & $pair[1] $m }
                } else { # static replacement
                    $json = $json -replace $pair[0], $pair[1]
                }
                Write-Host "." -NoNewline
            }
            Write-Host ") " -NoNewline
        }
        $json | Out-File -Encoding utf8NoBOM -Force $newPath
        Write-Host "Complete." -ForegroundColor Green
    }

    # Update ModInfo.json
    $modInfoPath = Join-Path $modRoot "ModInfo.json"
    $existing = $null
    if (Test-Path $modInfoPath) { $existing = Get-Content $modInfoPath -Raw | ConvertFrom-Json }
    $overrideFunc = "Set-$($fn)_ModInfo"
    $overrides = @{}
    $ifOverride = ""
    if (Get-Command $overrideFunc -ErrorAction SilentlyContinue) {
        $overrides = & $overrideFunc
        $ifOverride = " (with '$overrideFunc')"
    }
    $modInfo = New-ModInfoObject -ModName $ModName -ExistingModInfo $existing -Overrides $overrides
    $modInfo | ConvertTo-Json -Depth 20 | Out-File -Encoding utf8NoBOM -Force $modInfoPath

    if ($existing){
        Write-Host "Updated 'ModInfo.json'$ifOverride" -ForegroundColor Green
    }else{
        Write-Host "Created 'ModInfo.json'$ifOverride" -NoNewline -ForegroundColor Green
    }
    # Ensure Preview.png
    $modPreview = Join-Path $modRoot "Preview.png"
    $genericPreview = Join-Path $Global:StreamingAssets "Modding\PreviewMod.png"
    if (-not (Test-Path $modPreview)) {
        if (-not (Test-Path $genericPreview)) { throw "Generic preview image not found at '$genericPreview'." }
        Copy-Item -Path $genericPreview -Destination $modPreview -Force
        Write-Host " - Added default 'Preview.png'" -ForegroundColor Green
    }

    if ($existing){
        Write-Host "Mod Updated: '" -NoNewline -ForegroundColor Green
    }else{
        Write-Host "Mod Created: '" -NoNewline -ForegroundColor Green
    }
    Write-Host "$ModName" -NoNewline -ForegroundColor Blue
    Write-Host "' (" -NoNewline
    Write-Host "$($modInfo.ModVersion)" -NoNewline -ForegroundColor Blue
    Write-Host ")"
    Write-Host ("file:///" + ($modRoot -replace '\\','/'))
}

function Get-RecipeNames { # recipes\<Name>.ps1 and recipes\<Name>\ folders
    $names = @(Get-ChildItem -Path $Global:RecipesRoot -Filter *.ps1 -File | ForEach-Object { $_.BaseName })
    $names += @(Get-ChildItem -Path $Global:RecipesRoot -Directory | ForEach-Object { $_.Name })
    return @($names | Sort-Object -Unique)
}

# Mod Menu (looks for recipes to select)
function Show-ModSelectionMenu {
    $files = @(Get-RecipeNames)
    if ($files.Count -eq 0) { throw "No recipes found in '$($Global:RecipesRoot)'" }
    $files += "[Cancel]"
    $index = 0
    function Get-DrawnMenu {
        Clear-Host;
        Write-Host "Current Game Version: $($Global:GameVersion)"
        Write-Host ""
        Write-Host "Select a mod recipe:`n"
        for ($i = 0; $i -lt $files.Count; $i++) {
            if ($i -eq $index) {
                Write-Host "> $($files[$i])" -ForegroundColor Cyan
            } else {
                Write-Host "  $($files[$i])"
            }
        }
    }
    Get-DrawnMenu
    while ($true) {
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        switch ($key.VirtualKeyCode) {
            38 { if ($index -gt 0) { $index-- } Get-DrawnMenu } # Up arrow
            40 { if ($index -lt $files.Count - 1) { $index++ } Get-DrawnMenu } # Down arrow
            13 { # Enter
                $selected = $files[$index]
                if ($selected -eq "[Cancel]") { return $null }
                return $selected
            }
        }
    }
}

if ($All) {
    # Each recipe runs in its own scope so one recipe's variables and functions cannot leak into the next.
    foreach ($name in Get-RecipeNames) { & { param($n) New-Mod $n } $name; Write-Host "" }
}
elseif ($ModName) { New-Mod $ModName }
else {
    $selectedMod = Show-ModSelectionMenu
    if($selectedMod){ New-Mod $selectedMod }
}
