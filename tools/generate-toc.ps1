param(
    [ValidateSet("Generate", "Verify")]
    [string]$Mode = "Generate",
    [string]$ReportPath = (Join-Path $PSScriptRoot "..\README.md")
)

$ErrorActionPreference = "Stop"

function Get-HeadingEntries {
    param([string]$Content)

    $entries = New-Object System.Collections.Generic.List[object]
    $inFence = $false
    $lines = $Content -split "\r?\n"
    $tocStart = $false

    foreach ($line in $lines) {
        if ($line -match '^\s*```') {
            $inFence = -not $inFence
            continue
        }
        if ($line -match '^#\s+Contenido\s*$') {
            $tocStart = $true
            continue
        }
        if (-not $tocStart -or $inFence -or $line -match '^\s*<!--\s*TOC:(START|END)\s*-->') {
            continue
        }

        $match = [regex]::Match($line, '^(#{1,6})\s+(.+?)\s*#*\s*$')
        if (-not $match.Success) {
            continue
        }

        $title = $match.Groups[2].Value.Trim()
        if ($title -eq "Tabla de contenido") {
            continue
        }
        [void]$entries.Add([pscustomobject]@{
            Level = $match.Groups[1].Value.Length
            Title = $title
        })
    }

    return $entries
}

function Convert-ToGitHubAnchor {
    param([string]$Title)

    $plain = [regex]::Replace($Title, '<[^>]+>', '')
    $plain = $plain -replace '[\[\]]', ''
    $plain = $plain.ToLowerInvariant()
    $plain = [regex]::Replace($plain, '[^\p{L}\p{N}\s_-]', '')
    $plain = [regex]::Replace($plain, '\s', '-')
    return $plain.Trim("-")
}

function New-Toc {
    param([System.Collections.Generic.List[object]]$Entries)

    if ($Entries.Count -eq 0) {
        throw "No se encontraron encabezados para generar la tabla de contenido."
    }

    $usedAnchors = @{}
    $firstLevel = $Entries[0].Level
    $lines = New-Object System.Collections.Generic.List[string]

    foreach ($entry in $Entries) {
        $anchor = Convert-ToGitHubAnchor $entry.Title
        if ([string]::IsNullOrWhiteSpace($anchor)) {
            throw "El encabezado '$($entry.Title)' no produce un ancla valida."
        }
        if ($usedAnchors.ContainsKey($anchor)) {
            $usedAnchors[$anchor]++
            $anchor = "$anchor-$($usedAnchors[$anchor])"
        }
        else {
            $usedAnchors[$anchor] = 0
        }

        $indent = "  " * [Math]::Max(0, $entry.Level - $firstLevel)
        [void]$lines.Add("$indent- [$($entry.Title)](#$anchor)")
    }

    return ($lines -join "`n")
}

if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
    Write-Error "No se encontro el informe: $ReportPath"
    exit 2
}

try {
    $path = (Get-Item -LiteralPath $ReportPath).FullName
    $content = [IO.File]::ReadAllText($path, [Text.Encoding]::UTF8)
    $newline = if ($content.Contains("`r`n")) { "`r`n" } else { "`n" }
    $markers = [regex]::Match(
        $content,
        '(?ms)^(?<start>\s*<!--\s*TOC:START\s*-->\s*)$.*?^(?<end>\s*<!--\s*TOC:END\s*-->\s*)$'
    )
    if (-not $markers.Success) {
        throw "No se encontro el bloque administrado <!-- TOC:START --> ... <!-- TOC:END -->."
    }

    $toc = New-Toc (Get-HeadingEntries $content)
    $normalizedToc = $toc.Replace("`n", $newline)
    $replacement = "<!-- TOC:START -->$newline$normalizedToc$newline<!-- TOC:END -->"
    $updated = $content.Substring(0, $markers.Index) + $replacement +
        $content.Substring($markers.Index + $markers.Length)

    if ($Mode -eq "Verify") {
        if ($updated -ne $content) {
            Write-Error "La tabla de contenido esta desactualizada. Ejecute el modo Generate."
            exit 1
        }
        Write-Output "Tabla de contenido verificada: sin diferencias."
        exit 0
    }

    [IO.File]::WriteAllText($path, $updated, (New-Object Text.UTF8Encoding($false)))
    Write-Output "Tabla de contenido generada: $path"
    exit 0
}
catch {
    Write-Error $_.Exception.Message
    exit 2
}
