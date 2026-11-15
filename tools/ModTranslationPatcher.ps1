<# Mod Translation Patcher v20260330 -phrontisteries | License/Copyright: MITx11 | AKA: Enjoy #>
# Our authoring language (the language the original text is in)
$script:ourLanguage = "English" # Assumed "English" if not changed here.
# Language list (order locked)
$script:recommendedLanguages = @(
    "English",
    "Chinese",
    "French",
    "Spanish",
    "German",
    "Russian",
    "Japanese",
    "Portugese",
    "Korean",
    "Polish",
    "Turkish",
    "Italian" # Not in the standard list of Going Medieval, but highly requested-downloaded
)
# Folder to patch: $env:GM_TRANSLATE_FOLDER, else the repo's Mods folder (when run from the repo's tools folder), else the game's Mods folder.
$script:modFolder = if ($env:GM_TRANSLATE_FOLDER) { $env:GM_TRANSLATE_FOLDER }
    elseif (Test-Path (Join-Path $PSScriptRoot "..\Mods")) { (Resolve-Path (Join-Path $PSScriptRoot "..\Mods")).Path }
    else { Join-Path ([Environment]::GetFolderPath("MyDocuments")) "Foxy Voxel\Going Medieval\Mods" }
# Language → Code Map, Plus: Source language code for MyMemory (based on ourLanguage)
$LanguageCodes = @{
    English   = "en"
    Chinese   = "zh"
    French    = "fr"
    Spanish   = "es"
    German    = "de"
    Russian   = "ru"
    Japanese  = "ja"
    Portugese = "pt"
    Korean    = "ko"
    Polish    = "pl"
    Turkish   = "tr"
    Italian   = "it"
} # ISO standard names or RFC3066
$SourceLangCode = $LanguageCodes[$ourLanguage]

# NewLines Handling
<# function Convert-LiteralEscapesToRealNewlines {
    param([string]$Text)
    $Text = $Text -replace "\\r\\n", "`r`n"
    $Text = $Text -replace "\\n", "`n"
    $Text = $Text -replace "\\r", "`r"
    return $Text
} #>

# Levenshtein Distance Formula : (Changes: plurals, specifically 's', are weighted only as 0.25; case-insensitive)
function Get-LevenshteinDistance {
    param(
        [string]$A,
        [string]$B
    )

    # Case-insensitive normalization
    $A = $A.ToLowerInvariant()
    $B = $B.ToLowerInvariant()

    $lenA = $A.Length
    $lenB = $B.Length

    # Build jagged matrix
    $matrix = @()
    for ($i = 0; $i -le $lenA; $i++) {
        $row = New-Object int[] ($lenB + 1)
        $matrix += ,$row
    }

    for ($i = 0; $i -le $lenA; $i++) { $matrix[$i][0] = $i }
    for ($j = 0; $j -le $lenB; $j++) { $matrix[0][$j] = $j }

    for ($i = 1; $i -le $lenA; $i++) {
        for ($j = 1; $j -le $lenB; $j++) {

            $charA = $A[$i-1]
            $charB = $B[$j-1]

            # Weighted substitution rules
            if ($charA -eq $charB) {
                $cost = 0
            }
            elseif (($charA -eq 's') -or ($charB -eq 's')) {
                # Pluralization drift penalty
                $cost = 0.25
            }
            else {
                $cost = 1
            }

            $delete  = $matrix[$i-1][$j] + 1
            $insert  = $matrix[$i][$j-1] + 1
            $replace = $matrix[$i-1][$j-1] + $cost

            $min = [Math]::Min($delete, $insert)
            $matrix[$i][$j] = [Math]::Min($min, $replace)
        }
    }

    return $matrix[$lenA][$lenB]
}

function Get-TranslationScore {
    param(
        [string]$Original,
        [string]$Reverse
    )

    $dist = Get-LevenshteinDistance -A $Original -B $Reverse
    $maxLen = [Math]::Max($Original.Length, $Reverse.Length)

    if ($maxLen -eq 0) { return 1 }

    return 1 - ($dist / $maxLen)
}

# MyMemory Translation (Free)
function Invoke-NormalizationForMyMemoryOutput {
    param([string]$Text)

    if (-not $Text) { return "" }

    # Trim leading/trailing whitespace
    $t = $Text.Trim()

    # Collapse multiple spaces
    $t = $t -replace '\s+', ' '

    return $t
}

$script:capturedTranslations = @{}
foreach ( $lang in $script:recommendedLanguages ){
    $script:capturedTranslations[$lang] = @{
        to = @()
        from = @()
    }
}

function Get-Translation {
    param(
        [Parameter(Mandatory)][string]$Text, # max encoded chars of 500
        [Parameter(Mandatory)][string]$Language, # from the 
        [string]$email = "someone@example.com", # with: 50,000 , without: 5,000 (chars/day)
        [switch]$from
    )
    # if someone switched the inputs
    if (-not $LanguageCodes.ContainsKey($Language)) {
        if ($LanguageCodes.ContainsKey($Text)) {
            $temp = $Text
            $Text = $Language
            $Language = $temp
        }else{throw "$Language Not Listed in LanguageCodes"}
    }
    $langPair = @($SourceLangCode, $LanguageCodes[$Language])
    $to = "to"
    if ($from) { $langPair = $langPair[-1..0] ; $to = "from" }
    # API Documentation: # https://mymemory.translated.net/doc/spec.php
    # eg. "https://api.mymemory.translated.net/get?q=$([uri]::EscapeDataString($Text))&langpair=en|it)&de=someone@example.com"
    $uri = "https://api.mymemory.translated.net/get?q="
    $uri += "$([uri]::EscapeDataString($Text))"
    $uri += "&langpair=$($langPair -join "|")"
    if ($email) { $uri += "&de=$email" }

    $response = Invoke-RestMethod -Uri $uri -Method Get

    $script:capturedTranslations[$Language][$to] += $response

    if ($response.responseStatus -ne 200) { return "" }
    return $response.responseData.translatedText
}

#  Recursively finds *.json files containing "locKeys"
function Get-LocKeyJsonFiles {
    param()

    Get-ChildItem -Path $script:modFolder -Recurse -Filter *.json -File |
        Where-Object {
            Select-String -Path $_.FullName -Pattern '"locKeys"' -SimpleMatch -Quiet
        }
}

function Test-IsReferenceString {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $true
    }

    # No whitespace?
    if ($Value -notmatch '\s') {
        # Only alphanumerics and underscores?
        if ($Value -match '^[A-Za-z0-9_]+$') {
            return $true
        }
    }

    return $false
}

#  Returns ONLY: TranslateName - TranslateInfo, If both are false, caller will skip the entry.
function Test-LocKeyTranslationNeed {
    param([psobject]$LocKey)

    # NAME always exists
    if (Test-IsReferenceString $LocKey.name) {
        $translateName = $false
        $referenceName = $LocKey.name
    } else {
        # Use the English text itself as the translation trigger
        $translateName = $LocKey.name
    }

    # INFO may or may not exist
    if ($LocKey.PSObject.Properties.Name -contains "info") {
        if (Test-IsReferenceString $LocKey.info) {
            $translateInfo = $false
            $referenceInfo = $LocKey.info
        } else {
            # Use the English text itself as the translation trigger
            $translateInfo = $LocKey.info
        }
    }
    else {
        $translateInfo = $null   # DNE
    }

    return [pscustomobject]@{
        TranslateName = $translateName
        ReferenceName = $referenceName
        TranslateInfo = $translateInfo
        ReferenceInfo = $referenceInfo
    }
}

#  Recursively extracts ALL locKeys arrays from a JSON object AND records the JSON path for each one.
function Get-LocKeysFromObject {
    param(
        [object]$Obj,
        [string]$Path = ""
    )

    $results = @()

    if ($null -eq $Obj) { return $results }

    # If this object has a locKeys property, capture it with its path
    if ($Obj.PSObject.Properties.Name -contains "locKeys") {
        $locPath = if ($Path) { "$Path.locKeys" } else { "locKeys" }

        $results += [pscustomobject]@{
            Path    = $locPath
            LocKeys = $Obj.locKeys
        }
    }

    foreach ($prop in $Obj.PSObject.Properties) {
        $value = $prop.Value
        $propName = $prop.Name

        # Arrays
        if ($value -is [System.Collections.IEnumerable] -and
            $value -notlike [string]) {

            $index = 0
            foreach ($item in $value) {
                if ($item -is [psobject]) {

                    $childPath = if ($Path) {
                        "$Path.$propName[$index]"
                    } else {
                        "$propName[$index]"
                    }

                    $results += Get-LocKeysFromObject -Obj $item -Path $childPath
                }
                $index++
            }
        }
        # Nested object
        elseif ($value -is [psobject]) {

            $childPath = if ($Path) {
                "$Path.$propName"
            } else {
                $propName
            }

            $results += Get-LocKeysFromObject -Obj $value -Path $childPath
        }
    }

    return $results
}

function Get-ModInfo {
    param()

    $modInfos = @()

    # Find all ModInfo.json files under the root
    $files = Get-ChildItem -Path $script:modFolder -Recurse -Filter ModInfo.json -File

    foreach ($file in $files) {
        $json = Get-Content $file.FullName -Raw | ConvertFrom-Json

        $modInfos += [pscustomobject]@{
            ModRoot = Split-Path $file.FullName -Parent
            ModId   = $json.id
            ModName = $json.name
        }
    }

    return $modInfos
}

function Get-ModForFile {
    param(
        [string]$FilePath,
        [array]$ModInfos
    )

    foreach ($mod in $ModInfos) {
        if ($FilePath.StartsWith($mod.ModRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $mod
        }
    }

    return $null
}

#  Entries where BOTH TranslateName and TranslateInfo are FALSE are NOT recorded.
function Find-LocKeys {
    param()
    
    $modInfos = Get-ModInfo
    $files    = Get-LocKeyJsonFiles

    # Output grouped by ModId
    $mods = @{}

    foreach ($file in $files) {

        # Determine which mod this file belongs to
        $mod = Get-ModForFile -FilePath $file.FullName -ModInfos $modInfos
        if ($null -eq $mod) { continue }

        $json  = Get-Content $file.FullName -Raw | ConvertFrom-Json
        $found = Get-LocKeysFromObject -Obj $json

        foreach ($entry in $found) {

            # ALWAYS force to array
            $currentLanguages = @(
                $entry.LocKeys |
                    ForEach-Object { $_.languageName } |
                    Where-Object { $_ } |
                    Sort-Object -Unique
            )

            # Boolean: does this block contain English?
            $hasEnglish = "English" -in $currentLanguages

            # Skip if this block already contains ALL recommended languages
            $hasAllLanguages = $true
            foreach ($lang in $script:recommendedLanguages) {
                if ($lang -notin $currentLanguages) {
                    $hasAllLanguages = $false
                    break
                }
            }
            if ($hasAllLanguages) { continue }

            # Pick the English entry if present, otherwise the first entry
            $lk = $entry.LocKeys | Where-Object { $_.languageName -eq "English" } | Select-Object -First 1
            if (-not $lk) {
                $lk = $entry.LocKeys | Select-Object -First 1
            }

            # Evaluate translation need ONCE per locKeys block
            $eval = Test-LocKeyTranslationNeed -LocKey $lk

            # Skip if neither field needs translation
            if (-not $eval.TranslateName -and -not $eval.TranslateInfo) {
                continue
            }

            # 🔥 CREATE THE MOD BUCKET *ONLY NOW* - when we KNOW we have a real entry
            if (-not $mods.ContainsKey($mod.ModId)) {
                $mods[$mod.ModId] = [ordered]@{
                    ModId   = $mod.ModId
                    ModName = $mod.ModName
                    ModRoot = $mod.ModRoot
                    Entries = @()
                }
            }

            # Add ONE entry per locKeys block
            $mods[$mod.ModId].Entries += [pscustomobject]@{
                ModId            = $mod.ModId
                ModName          = $mod.ModName
                ModRoot          = $mod.ModRoot

                File             = $file.FullName
                JSONFile         = [System.IO.Path]::GetFileNameWithoutExtension($file.FullName)
                Path             = $entry.Path

                TranslateName    = $eval.TranslateName
                TranslateInfo    = $eval.TranslateInfo

                ReferenceName    = $eval.ReferenceName
                ReferenceInfo    = $eval.ReferenceInfo

                CurrentLanguages = $currentLanguages
                English          = $hasEnglish

                LocKey           = $lk
            }
        }

    }
    return $mods
}

<# Chunking for API:
1. We gather all English strings in the mod
NAME + INFO, in order.

2. We join them using a delimiter that:
never appears in text
survives translation
survives reverse translation
survives chunking
survives splitting

3. We create a giant combined string: NAME1␟INFO1␟NAME2␟INFO2␟NAME3␟...

4. We split into chunks ONLY at safe boundaries:
Prefer splitting at . (end of sentence)
If no . available before the limit, fallback to splitting at the delimiter
Never split inside a UTF-8 escape sequence
Never split inside a delimiter

5. Each chunk must be ≤ 400 encoded characters
We measure: [uri]::EscapeDataString($chunk).Length

6. We translate each chunk
Forward + reverse.

7. We reassemble the chunks
ForwardCombined = join all forward chunks
ReverseCombined = join all reverse chunks

8. We split back into individual strings
Using the delimiter.

9. We feed them back into your existing scoring + correction loop.

#>

$script:BatchEmoji = "🙃"

<# function Set-NormalizedDelimiter {
    param(
        [string]$Original,   # BEFORE batching
        [string]$Mutated     # AFTER translation
    )
    $emoji = [regex]::Escape($script:BatchEmoji)
    # 1 - Determine whether the ORIGINAL string had punctuation before the emoji.
    $origHadPunctBefore = $Original -match "([\.\u3002])\s*$emoji"

    # 2 - Fix BEFORE-emoji punctuation ONLY if it was NOT in the original.
    if (-not $origHadPunctBefore) {
        # Remove ONLY the punctuation WE added before the emoji
        $Mutated = $Mutated -replace "[\.\u3002]+\s*($emoji)", "$script:BatchEmoji"
    } else {
        # Original had punctuation → collapse extras but KEEP ONE
        $Mutated = $Mutated -replace "([\.\u3002])\1+($emoji)", '$1$2'
    }

    # 3 - Remove spaces and periods AFTER emoji
    $Mutated = $Mutated -replace "($emoji)\s*\.{0,}", "$($script:BatchEmoji)."
    return $Mutated
} #>
function Set-NormalizedDelimiter {
    param(
        [string]$Original,   # BEFORE batching
        [string]$Mutated     # AFTER translation
    )

    $emoji = [regex]::Escape($script:BatchEmoji)

    #
    # We now expect the delimiter to be: ". 🙃. "
    # But translators may mutate it into any of these:
    #   "。🙃。"
    #   ".🙃."
    #   " .🙃. "
    #   "。 🙃 。"
    #   "🙃."
    #   "🙃。"
    #   "🙃 ."
    #   etc.
    #
    # So we normalize ANY of these patterns back to the canonical:
    #       ". 🙃. "
    #

    # 1 — Normalize BEFORE-emoji punctuation
    $origHadPunctBefore = $Original -match "([\.\u3002])\s*$emoji"

    if (-not $origHadPunctBefore) {
        # Remove punctuation WE added before emoji
        $Mutated = $Mutated -replace "[\.\u3002]+\s*($emoji)", "$script:BatchEmoji"
    } else {
        # Collapse extras but keep one
        $Mutated = $Mutated -replace "([\.\u3002])\1+($emoji)", '$1$2'
    }

    #
    # 2 — Normalize AFTER-emoji punctuation AND spaces
    #
    # ANY of these:
    #   🙃.
    #   🙃。
    #   🙃 . .
    #   🙃。 .
    #   🙃.  
    #   🙃。  
    #
    # Should become:
    #   "🙃. "
    #
    $Mutated = $Mutated -replace "($emoji)\s*[\.\u3002]*\s*", "$($script:BatchEmoji). "

    #
    # 3 — Now enforce the FULL delimiter: ". 🙃. "
    #
    # Replace ANY of these:
    #   ".🙃. "
    #   "。 🙃。 "
    #   ". 🙃."
    #   "。🙃。"
    #
    # With the canonical:
    #   ". 🙃. "
    #
    $Mutated = $Mutated -replace "[\.\u3002]\s*$emoji\.\s*", ". $($script:BatchEmoji). "

    return $Mutated
}

function Split-IntoSentenceAwareChunks {
    param(
        [string]$Text,
        [int]$MaxEncodedLength = 400
    )

    # $delimiter = "$($script:BatchEmoji)."
    $delimiter = ". $($script:BatchEmoji). "
    $delEsc    = [regex]::Escape($delimiter)

    # Split on the delimiter
    $parts  = $Text -split $delEsc
    $chunks = @()
    $current = ""

    foreach ($p in $parts) {

        $candidate = if ($current -eq "") { $p } else { "$current$delimiter$p" }

        if ([uri]::EscapeDataString($candidate).Length -gt $MaxEncodedLength) {

            # Split inside the part at ". "
            $sentences = $p -split '(?<=\.\s)'

            foreach ($s in $sentences) {
                $candidate2 = if ($current -eq "") { $s } else { "$current$delimiter$s" }

                if ([uri]::EscapeDataString($candidate2).Length -gt $MaxEncodedLength) {
                    if ($current -ne "") { $chunks += $current }
                    $current = $s
                }
                else {
                    $current = $candidate2
                }
            }
        }
        else {
            $current = $candidate
        }
    }

    if ($current -ne "") { $chunks += $current }

    return $chunks
}

function Invoke-BatchedTranslation {
    param(
        [string[]]$Strings,
        [string]  $Language
    )

    if (-not $Strings -or $Strings.Count -eq 0) {
        return [pscustomobject]@{
            Forward = @()
            Reverse = @()
        }
    }

    # $delimiter = "$($script:BatchEmoji)."
    $delimiter = ". $($script:BatchEmoji). "
    $delEsc    = [regex]::Escape($delimiter)

    #
    # PREPARE ORIGINAL STRINGS (force trailing period)
    #
    $prepared = foreach ($s in $Strings) {
        if ([string]::IsNullOrWhiteSpace($s)) { "" }
        elseif ($s -match "\.$") { $s }
        else { "$s." }
    }

    #
    # BUILD ONE BIG STRING WITH DELIMITERS, THEN SPLIT INTO CHUNKS
    #
    $joined = ($prepared -join $delimiter)
    $chunks = Split-IntoSentenceAwareChunks -Text $joined -MaxEncodedLength 400

    #
    # TRANSLATE CHUNKS
    #
    $forwardChunks = @()
    $reverseChunks = @()

    foreach ($chunk in $chunks) {

        #
        # BEFORE TRANSLATION — normalize using original chunk
        #
        $chunkNorm = Set-NormalizedDelimiter -Original $chunk -Mutated $chunk

        #
        # FORWARD TRANSLATION
        #
        $f = Get-Translation $chunkNorm $Language

        #
        # NORMALIZE FORWARD RESULT (using original chunk)
        #
        $f = Set-NormalizedDelimiter -Original $chunk -Mutated $f

        #
        # REVERSE TRANSLATION
        #
        $r = Get-Translation $f $Language -from

        #
        # NORMALIZE REVERSE RESULT (using original chunk)
        #
        $r = Set-NormalizedDelimiter -Original $chunk -Mutated $r

        $forwardChunks += $f
        $reverseChunks += $r
    }

    #
    # JOIN ALL CHUNKS
    #
    $forwardAll = ($forwardChunks -join "")
    $reverseAll = ($reverseChunks -join "")

    #
    # SPLIT BACK INTO PARTS
    #
    $forwardParts = $forwardAll -split $delEsc
    $reverseParts = $reverseAll -split $delEsc

    #
    # STRIP DELIMITER REMNANTS
    #
    $forwardParts = $forwardParts | ForEach-Object { $_ -replace $delEsc, "" }
    $reverseParts = $reverseParts | ForEach-Object { $_ -replace $delEsc, "" }

    #
    # RESTORE PERIODS BASED ON ORIGINAL
    #
    function Restore-Periods {
        param($orig, $translated)

        if (-not $translated) { return $translated }

        $origPeriods = 0
        if ($orig -match "(\.+)$") { $origPeriods = $matches[1].Length }

        $transPeriods = 0
        if ($translated -match "(\.+)$") { $transPeriods = $matches[1].Length }

        if ($origPeriods -eq 0) { return ($translated -replace "\.+$","") }
        if ($origPeriods -eq $transPeriods) { return $translated }

        $base = $translated -replace "\.+$",""
        $base + ("." * $origPeriods)
    }

    #
    # MAP BACK TO ORIGINAL STRINGS
    #
    $forwardFinal = @()
    $reverseFinal = @()

    for ($i = 0; $i -lt $Strings.Count; $i++) {
        $orig = $Strings[$i]
        $f = ""; if ($i -lt $forwardParts.Count){ $f = ([string]$forwardParts[$i]).Trim() }
        $r = ""; if ($i -lt $reverseParts.Count){ $r = ([string]$reverseParts[$i]).Trim() }

        $f = Restore-Periods $orig $f
        $r = Restore-Periods $orig $r

        $forwardFinal += $f
        $reverseFinal += $r
    }

    [pscustomobject]@{
        Forward = $forwardFinal
        Reverse = $reverseFinal
    }
}

# Selection Menu
function Show-BinarySelectionMenu {
    param(
        [string]$PromptText,
        [string]$YesText,
        [string]$NoText
    )

    $options = @($YesText, $NoText)
    $index = 0

    function Write-SelectionLine {
        param($idx)

        # Build option blocks
        $yesBlock = if ($idx -eq 0) { "[ $YesText ]" } else { "[ $YesText ]" }
        $noBlock  = if ($idx -eq 1) { "[ $NoText ]"  } else { "[ $NoText ]"  }

        # Rewrite the entire line
        $cursor = $Host.UI.RawUI.CursorPosition
        $Host.UI.RawUI.CursorPosition = @{X=0;Y=$cursor.Y}

        # Write prompt
        Write-Host -NoNewline "$PromptText  " -ForegroundColor Yellow

        # Write Yes block
        if ($idx -eq 0) {
            Write-Host -NoNewline $yesBlock -ForegroundColor Black -BackgroundColor Yellow
        } else {
            Write-Host -NoNewline $yesBlock
        }

        Write-Host -NoNewline "  "

        # Write No block
        if ($idx -eq 1) {
            Write-Host -NoNewline $noBlock -ForegroundColor Black -BackgroundColor Yellow
        } else {
            Write-Host -NoNewline $noBlock
        }
    }

    # Initial draw
    Write-Host ""  # create the line
    $startPos = $Host.UI.RawUI.CursorPosition
    $startPos.Y -= 1
    $Host.UI.RawUI.CursorPosition = $startPos
    Write-SelectionLine -idx $index

    while ($true) {
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        switch ($key.VirtualKeyCode) {
            # Left arrow
            37 {$index--;   if ($index -lt 0) { $index = $options.Count - 1 }; Write-SelectionLine -idx $index}
            # Right arrow
            39 {$index++;   if ($index -ge $options.Count) { $index = 0 };     Write-SelectionLine -idx $index}
            # Space
            32 {return ($index -eq 0)}
            # Enter
            13 {return ($index -eq 0)}
        }
    }
}

# Select Mods
<# function Select-ModsToTranslate {
    param(
        [hashtable]$Mods
    )

    Write-Host "`n========== MOD TRANSLATION SELECTION ==========" -ForegroundColor Cyan
    Write-Host "Found $($Mods.Keys.Count) Mods that can be translated.`n" -ForegroundColor Yellow

    $selectedMods = @{}
    $sortedmods = $Mods.Keys | Sort-Object
    foreach ($modId in $sortedmods) {

        $mod = $Mods[$modId]

        # Collect unique JSON filenames this mod will modify
        $jsonFiles = $mod.Entries.JSONFile | Sort-Object -Unique

        Write-Host "$($mod.ModName)" -ForegroundColor Cyan -NoNewline
        Write-Host " ( ID: $($mod.ModId) )" -ForegroundColor DarkGray
        Write-Host "$($mod.ModRoot)" -ForegroundColor Green
        foreach ($jf in $jsonFiles) { Write-Host "`t- $jf.json" }

        $choice = Show-BinarySelectionMenu "$($mod.ModName):" "Translate" "Skip"

        if ($choice) {
            $selectedMods[$modId] = $mod
            Write-Host " → Added to Queue.`n" -ForegroundColor Green
        } else {
            Write-Host " → Skipped.`n" -ForegroundColor Yellow
        }
    }

    return $selectedMods
} #>

function Show-ModMultiSelectMenu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Mods,      # <-- NOW accepts Find-LocKeys output directly
        [string]$SubmitText = "Translate"
    )

    $ToggleText = "Toggle Selection"
    $ESC = [char]27
    $check = "☑"
    $uncheck = "☐"

    $highlightBG = "$ESC[48;5;24m"
    $highlightFG = "$ESC[38;5;15m"
    $selectedBG  = "$ESC[48;5;22m"
    $selectedFG  = "$ESC[38;5;15m"
    $normalBG    = "$ESC[49m"
    $normalFG    = "$ESC[39m"

    $cyan  = "$ESC[38;5;14m"
    $gray  = "$ESC[38;5;245m"
    $green = "$ESC[38;5;10m"

    # Convert hashtable → ordered list for display
    $ModList = foreach ($k in $Mods.Keys) {
        $m = $Mods[$k]
        [pscustomobject]@{
            Key     = $k
            ModId   = $m.ModId
            ModName = $m.ModName
            ModRoot = $m.ModRoot
        }
    }

    $entries = @($ToggleText) + ($ModList.ModName) + @($SubmitText)
    $count   = $entries.Count

    # Track selection by ModId
    $selected = @{}
    foreach ($m in $ModList) { $selected[$m.ModId] = $false }

    $index = 0

    function Set-AllSelections {
        $snapshot = @{}
        foreach ($k in $selected.Keys) { $snapshot[$k] = $selected[$k] }
        foreach ($k in $snapshot.Keys) { $selected[$k] = -not $snapshot[$k] }
    }

    function Get-ModByLabel {
        param([string]$Label)
        $ModList | Where-Object { $_.ModName -eq $Label }
    }

    function Test-IsModLabel {
        param([string]$Label)
        $null -ne (Get-ModByLabel $Label)
    }

    function Show-Menu {
        Clear-Host
        Write-Host "========== MOD TRANSLATION SELECTION ==========`n"
        for ($i = 0; $i -lt $count; $i++) {
            $label = $entries[$i]
            $isCurrent = ($i -eq $index)
            if ($isCurrent) { $bg = $highlightBG; $fg = $highlightFG } else { $bg = $normalBG; $fg = $normalFG }
            if ($label -eq $ToggleText) {
                Write-Host "$bg$fg << $label >>$normalBG$normalFG"
                continue
            } elseif ($label -eq $SubmitText) {
                Write-Host "$bg$fg << $label >>$normalBG$normalFG"
                continue
            }
            $mod = Get-ModByLabel $label
            if ($selected[$mod.ModId] -and -not $isCurrent) { $bg = $selectedBG; $fg = $selectedFG }
            $box = if ($selected[$mod.ModId]) { $check } else { $uncheck }
            Write-Host "$bg$fg $box  $cyan$($mod.ModName)$gray ( ID: $($mod.ModId) )$normalBG$normalFG"
            Write-Host "$bg$fg     $green$($mod.ModRoot)$normalBG$normalFG"
        }
        Write-Host "`nUse ↑/↓ to move, ←/→/Space/Enter to toggle, Enter on Submit to finish."
    }

    function Test-OnKeyForReturn {
        param(
            [string]$label,
            [switch]$canSubmit
        )
        if ($label -eq $ToggleText) {
            Set-AllSelections
        } elseif (Test-IsModLabel $label) {
            $mod = Get-ModByLabel $label
            $selected[$mod.ModId] = -not $selected[$mod.ModId]
        } elseif ($canSubmit -and $label -eq $SubmitText) {
            # RETURN FILTERED HASHTABLE (same shape as Find-LocKeys)
            $result = @{}
            foreach ($m in $ModList) {
                if ($selected[$m.ModId]) {
                    $result[$m.Key] = $Mods[$m.Key]
                }
            }
            return $result
        }
    }

    Show-Menu

    while ($true) {
        $key   = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        $label = $entries[$index]

        switch ($key.VirtualKeyCode) {
            38 { if ($index -gt 0) { $index-- } else { $index = $count - 1 } }   # Up
            40 { if ($index -lt $count - 1) { $index++ } else { $index = 0 } }   # Down
            37 { $r = Test-OnKeyForReturn $label }                               # Left
            39 { $r = Test-OnKeyForReturn $label }                               # Right
            32 { $r = Test-OnKeyForReturn $label -canSubmit }                    # Space
            13 { $r = Test-OnKeyForReturn $label -canSubmit }                    # Enter
        }

        if ($r) { return $r }
        Show-Menu
    }
}

function Invoke-YourTranslationEngine {
    param(
        [string]$Text,
        [string[]]$TargetLanguages
    )

    # Reuse the proven engine
    $allResults = Invoke-TranslationTest -Text $Text

    # Filter to only the requested languages (and preserve order)
    $filtered = @{}
    foreach ($lang in $TargetLanguages) {
        if ($allResults.Keys -contains $lang) {
            $filtered[$lang] = $allResults[$lang]
        }
    }

    return $filtered
}

<# function Test-TranslationMatchScore {
    param(
        [string]$Original,
        [string]$ReverseTranslated
    )

    return Get-TranslationScore -Original $Original -Reverse $ReverseTranslated
} #>

# Mods Are selected, Start Translating
function Invoke-TranslationForSelectedMods {
    param( [hashtable]$SelectedMods )
    $results = @()

    foreach ($modId in $SelectedMods.Keys) {
        $mod = $SelectedMods[$modId]

        Write-Host "`n=== Translating Mod: $($mod.ModName) ===" -ForegroundColor Cyan
        Write-Host "Path: $($mod.ModRoot)`n" -ForegroundColor DarkGray
        
        # 1) Gather all strings for this mod (NAME then INFO per entry)
        $allTexts = @()
        $map      = @()   # per-entry index mapping

        foreach ($entry in $mod.Entries) {
            $nameIndex = $null
            $infoIndex = $null

            if ($entry.TranslateName) {
                $nameIndex = $allTexts.Count
                $allTexts += $entry.TranslateName
            }

            if ($entry.TranslateInfo) {
                $infoIndex = $allTexts.Count
                $allTexts += $entry.TranslateInfo
            }

            $map += [pscustomobject]@{
                Entry     = $entry
                NameIndex = $nameIndex
                InfoIndex = $infoIndex
            }
        }

        if ($allTexts.Count -eq 0) {
            continue
        }

        # 2) Run batched translation per language (WITH SINGLE-LINE PROGRESS)
        $perLang = @{}

        Write-Host -NoNewline "Running translation: " -ForegroundColor Magenta
        foreach ($lang in $script:recommendedLanguages) {

            Write-Host -NoNewline "$lang" -ForegroundColor Magenta

            if ($lang -eq $script:ourLanguage) {
                # No API call for our language
                $perLang[$lang] = [pscustomobject]@{
                    Forward = $allTexts
                    Reverse = $allTexts
                }
            } else {
                # Batched translation
                $perLang[$lang] = Invoke-BatchedTranslation -Strings $allTexts -Language $lang
            }

            Write-Host -NoNewline "✅ "
        }

        # $global:debugTranslations[$modId] = $perLang

        Write-Host "`n"   # finish the progress line

        # 3) Walk entries again, map back translations, score, and log
        $entryCount = $mod.Entries.Count
        $entryIndex = 0

        foreach ($m in $map) {
            $entry = $m.Entry
            $entryIndex++

            Write-Host " → $($entry.JSONFile).json" -ForegroundColor Yellow
            Write-Host "   $entryIndex of $entryCount" -ForegroundColor Yellow -NoNewline
            Write-Host " $($entry.Path)" -ForegroundColor DarkGray

            $translatedName = $null
            $translatedInfo = $null
            $referenceName  = $null
            $referenceInfo  = $null
            $scoreName      = $null
            $scoreInfo      = $null

            # NAME
            if ($null -ne $m.NameIndex) {

                Write-Host "   NAME: '$($entry.TranslateName)'" -ForegroundColor Cyan

                $translatedName = @{}
                $scoresName = @()

                foreach ($lang in $script:recommendedLanguages) {

                    $f = Invoke-NormalizationForMyMemoryOutput $perLang[$lang].Forward[$m.NameIndex]
                    $r = Invoke-NormalizationForMyMemoryOutput $perLang[$lang].Reverse[$m.NameIndex]
                    $s = Get-TranslationScore -Original $entry.TranslateName -Reverse $r

                    $translatedName[$lang] = [pscustomobject]@{
                        Forward = $f
                        Reverse = $r
                        Score   = $s
                    }
                    $scoresName += $s

                    $scorePct = [math]::Round($s * 100, 1)
                    Write-Host ("       [{0}] {1}%  '{2}'" -f $lang, $scorePct, $r) -ForegroundColor Green
                }

                if ($scoresName.Count -gt 0) {
                    $scoreName = ($scoresName | Measure-Object -Average).Average
                    Write-Host "       → NAME Score: $([math]::Round($scoreName,4))" -ForegroundColor Green
                }
            } else {
                Write-Host "   NAME: Reference string → skipped" -ForegroundColor DarkGray
                $referenceName = $entry.ReferenceName
            }

            # INFO
            if ($null -ne $m.InfoIndex) {
                Write-Host "   INFO: '$($entry.TranslateInfo)'" -ForegroundColor Cyan
                $translatedInfo = @{}
                $scoresInfo = @()
                foreach ($lang in $script:recommendedLanguages) {
                    $f = Invoke-NormalizationForMyMemoryOutput $perLang[$lang].Forward[$m.InfoIndex]
                    $r = Invoke-NormalizationForMyMemoryOutput $perLang[$lang].Reverse[$m.InfoIndex]
                    $s = Get-TranslationScore -Original $entry.TranslateInfo -Reverse $r
                    $translatedInfo[$lang] = [pscustomobject]@{
                        Forward = $f
                        Reverse = $r
                        Score   = $s
                    }
                    $scoresInfo += $s
                    $scorePct = [math]::Round($s * 100, 1)
                    Write-Host ("       [{0}] {1}%  '{2}'" -f $lang, $scorePct, $r) -ForegroundColor Green
                }
                if ($scoresInfo.Count -gt 0) {
                    $scoreInfo = ($scoresInfo | Measure-Object -Average).Average
                    Write-Host "       → INFO Score: $([math]::Round($scoreInfo,4))" -ForegroundColor Green
                }
            } elseif ($entry.TranslateInfo -eq $false -and $entry.ReferenceInfo) {
                Write-Host "   INFO: Reference string → skipped" -ForegroundColor DarkGray

                # NEW: store the original reference text
                $translatedInfo = $null
                $referenceInfo  = $entry.ReferenceInfo

                $scoreInfo = $null
            } else {
                Write-Host "   INFO: (none)" -ForegroundColor DarkGray

                $translatedInfo = $null
                $referenceInfo  = $null
                $scoreInfo      = $null
            }

            Write-Host ""

            # Store result row
            $results += [pscustomobject]@{
                ModId          = $mod.ModId
                ModName        = $mod.ModName
                ModRoot        = $mod.ModRoot
                File           = $entry.File
                JSONFile       = $entry.JSONFile
                Path           = $entry.Path

                OriginalName   = $entry.TranslateName
                OriginalInfo   = $entry.TranslateInfo

                TranslatedName = $translatedName
                TranslatedInfo = $translatedInfo
    
                ReferenceName  = $referenceName
                ReferenceInfo  = $referenceInfo

                ScoreName      = $scoreName
                ScoreInfo      = $scoreInfo
            }
        }
    }

    return $results
}

function Get-AverageTranslationScore {
    param(
        [array]$TranslationResults
    )

    $scores = @()

    foreach ($r in $TranslationResults) {
        if ($r.ScoreName) { $scores += $r.ScoreName }
        if ($r.ScoreInfo) { $scores += $r.ScoreInfo }
    }

    if ($scores.Count -eq 0) { return 0 }

    $avg = ($scores | Measure-Object -Average).Average
    return [math]::Round($avg * 100, 1)  # percentage with 1 decimal
}

function Confirm-TranslationApproval {
    param(
        [double]$AverageScore
    )

    $prompt = "Approve translation?  (Match: $AverageScore`%)"
    return Show-BinarySelectionMenu -PromptText $prompt -YesText "Approve" -NoText "Reject"
}

# Review, Prompt, Modify Translations
function Invoke-ModifySingleEntry {
    param( [array]$TranslationResults )

    Write-Host "`n=== MODIFY ENTRY ===" -ForegroundColor Cyan

    # Step 1 - Choose file
    $files = $TranslationResults.JSONFile | Sort-Object -Unique
    $fileIndex = 0

    Write-Host "Select File:" -ForegroundColor Yellow
    foreach ($f in $files) {
        Write-Host "  [$fileIndex] $f.json"
        $fileIndex++
    }

    $fileChoice = Read-Host "Enter file index"
    $fileName = $files[$fileChoice]

    # Step 2 - Choose LocKey number
    $entries = $TranslationResults | Where-Object { $_.JSONFile -eq $fileName }
    $count = $entries.Count

    Write-Host "`nSelect LocKey (1-$count):" -ForegroundColor Yellow
    $locChoice = [int](Read-Host "Enter LocKey number")
    $entry = $entries[$locChoice - 1]

    # Step 3 - Show entry
    Write-Host "`n=== CURRENT ENTRY ===" -ForegroundColor Cyan
    Write-Host "File: $($entry.JSONFile).json"
    Write-Host "Path: $($entry.Path)"
    Write-Host "Original Name: $($entry.OriginalName)"
    Write-Host "Original Info: $($entry.OriginalInfo)`n"

    # Step 4 - Ask for new English text
    $newText = Read-Host "Enter new English text to test"

    # Step 5 - Re-run translation
    $newResults = Invoke-YourTranslationEngine -Text $newText -TargetLanguages $script:recommendedLanguages

    # Compute new score
    $scores = @()
    foreach ($lang in $script:recommendedLanguages) {
        if ($newResults.Keys -contains $lang) {
            $scores += $newResults[$lang].score
        }
    }
    $avgScore = ($scores | Measure-Object -Average).Average

    # Step 6 - Update the entry
    Write-Host "`nUpdated Score: $([math]::Round($avgScore * 100,1))%" -ForegroundColor Green

    $entry.TranslatedName = $newResults
    $entry.ScoreName      = $avgScore
    $entry.OriginalName   = $newText
}

function Invoke-TranslationModificationLoop {
    param( [array]$TranslationResults )
    while ($true) {
        $choice = Show-BinarySelectionMenu "Modify an entry?" "Modify" "Finish"
        if (-not $choice) { # Done modifying → recompute score and re-ask approval
            $newScore = Get-AverageTranslationScore -TranslationResults $TranslationResults
            $approved = Confirm-TranslationApproval -AverageScore $newScore
            return [pscustomobject]@{
                Approved = $approved
                Results  = $TranslationResults
                Score    = $newScore
            }
        }
        # User wants to modify
        Invoke-ModifySingleEntry -TranslationResults $TranslationResults
    }
}

function Invoke-TranslationReview {
    param( [hashtable]$SelectedMods )
    # Write-Host "`n=== Running Translation Pipeline ===`n" -ForegroundColor Cyan
    $finalResults = @{}
    
    foreach ($modId in $SelectedMods.Keys) {
        $modData = $SelectedMods[$modId]

        # Write-Host "`n=== Processing Mod: $($modData.Name) ($modId) ===`n" -ForegroundColor Yellow

        # Step 1 - translate THIS mod only
        $translationResults = Invoke-TranslationForSelectedMods -SelectedMods @{ $modId = $modData }

        # Step 2 - compute average score for THIS mod only
        $avgScore = Get-AverageTranslationScore -TranslationResults $translationResults

        # Step 3 - ask approval for THIS mod only
        $approved = Confirm-TranslationApproval -AverageScore $avgScore

        if ($approved) {
            # Write-Host " Translation approved for mod: $($modData.Name)" -ForegroundColor Green

            $finalResults[$modId] = [pscustomobject]@{
                # Approved = $true
                Results  = $translationResults
                Score    = $avgScore
                # ModName  = $translationResults.ModName
            }
        } else {
            # Write-Host " Translation rejected for mod: $($modData.Name)" -ForegroundColor Red

            # Enter modification loop for THIS mod only
            $modified = Invoke-TranslationModificationLoop -TranslationResults $translationResults
            if($modified.Approved){
                $finalResults[$modId] = $modified
            }
        }
    }
    Write-Host ""
    return $finalResults # .GetEnumerator() | Where-Object { $_.Value.Approved -eq $true }
}

# Formatting JSON entry to Patch Back
function Convert-TranslationResultsToLocKeys {
    param( [array]$Results )
    $output = @()
    # $modName = $Results[0].ModName
    # Write-Host "$row.ModName" -ForegroundColor DarkRed

    foreach ($row in $Results) {
        $locKeys = @()

        foreach ($lang in $script:recommendedLanguages) {

            # NAME
            $nameValue = $null
            if ($row.TranslatedName -and $row.TranslatedName.ContainsKey($lang)) { # Use translated forward value
                $nameValue = $row.TranslatedName[$lang].Forward
            } elseif ($row.ReferenceName) { # Reference name
                $nameValue = $row.ReferenceName
            } else { # No translation → use original
                $nameValue = $row.OriginalName
            }

            # INFO
            $infoValue = $null
            if ($row.TranslatedInfo -and $row.TranslatedInfo.ContainsKey($lang)) {
                $infoValue = $row.TranslatedInfo[$lang].Forward
            } elseif ($row.ReferenceInfo) {
                $infoValue = $row.ReferenceInfo
            } elseif ($row.OriginalInfo -and $row.OriginalInfo -is [string]) {
                $infoValue = $row.OriginalInfo
            } else {
                $infoValue = $null
            }

            $locKeys += [pscustomobject]@{
                languageName = $lang
                name         = $nameValue
                info         = $infoValue
            }
        }
        $output += [pscustomobject]@{
            ModId    = $row.ModId
            ModName  = $row.ModName
            ModRoot  = $row.ModRoot

            File     = $row.File
            JSONFile = $row.JSONFile
            Path     = $row.Path

            locKeys  = $locKeys
        }
    }
    return $output
}

function Convert-AllModsToLocKeys {
    param( [hashtable]$FinalResults )
    $output = @{}
    foreach ($modId in $FinalResults.Keys) {
        $output[$modId] = Convert-TranslationResultsToLocKeys $FinalResults[$modId].Results
    }
    return $output
}

# Patch Translation BACK into the files
function Get-JsonNodeByPath {
    param(
        [object]$Json,
        [string]$Path
    )
    $node = $Json
    $parts = $Path -split '\.'
    foreach ($part in $parts) {
        # Array index?
        if ($part -match '(.+)\[(\d+)\]') {
            $name  = $matches[1]
            $index = [int]$matches[2]
            $node  = $node.$name[$index]
        } else {
            $node = $node.$part
        }
    }
    return $node
}

function Set-LocKeysInJson {
    param( [hashtable]$Formatted )

    Write-Host "`n========== SAVING MOD TRANSLATIONS ==========`n" -ForegroundColor Cyan

    # $Formatted is a hashtable: ModId → array of entry objects
    foreach ($modId in $Formatted.Keys) {

        $entries = $Formatted[$modId]

        # Extract mod metadata from first entry
        $modName = $entries[0].ModName
        $modRoot = $entries[0].ModRoot

        Write-Host "Patching " -ForegroundColor Yellow -NoNewline
        Write-Host "$modName" -ForegroundColor Cyan -NoNewline
        Write-Host " ( ID: $modId )" -ForegroundColor DarkGray
        Write-Host "$modRoot" -ForegroundColor Green

        # Group entries by file
        $entriesByFile = $entries | Group-Object -Property File

        foreach ($fileGroup in $entriesByFile) {

            $filePath = $fileGroup.Name
            $changes  = $fileGroup.Group
            $jsonFile = $changes[0].JSONFile

            Write-Host "  → $jsonFile " -ForegroundColor Cyan -NoNewline

            # Load JSON once
            $jsonText = Get-Content -Raw -Path $filePath
            $jsonObj  = $jsonText | ConvertFrom-Json -Depth 50

            # Apply all patches for this file
            foreach ($entry in $changes) {
                Write-Host "." -NoNewline -ForegroundColor Yellow

                $parentPath = $entry.Path -replace '\.locKeys$',''
                $parentNode = Get-JsonNodeByPath -Json $jsonObj -Path $parentPath

                if ($null -eq $parentNode) {
                    Write-Host "FAILED TO RESOLVE PARENT PATH: $parentPath" -ForegroundColor Red
                    continue
                }

                $parentNode.locKeys = $entry.LocKeys
            }

            # Write JSON once
            $jsonObj | ConvertTo-Json -Depth 50 | Set-Content -Path $filePath -Encoding UTF8
            Write-Host ""
        }
    }
}

# Main execution
function Invoke-FindSelectTranslateReviewWrite {

    # Find
    $possibleMods = Find-LocKeys

    # Select & Translate
    $selectedMods = Show-ModMultiSelectMenu $possibleMods # Select-ModsToTranslate

    # Review (with translation weighted and scored)
    $approved = Invoke-TranslationReview $selectedMods

    # Format locKeys for insertion
    $formatted = Convert-AllModsToLocKeys $approved

    # Now push our changes
    Set-LocKeysInJson $formatted

    Write-Host "Thank you for using my Mod Translation Patcher`nIf you have any questions, comments, thoughts for improvement,`nplease hit me up on Discord for Going Medieval in #modding`n-phrontisteries"
    Read-Host "Press Enter to Exit"
}

Invoke-FindSelectTranslateReviewWrite