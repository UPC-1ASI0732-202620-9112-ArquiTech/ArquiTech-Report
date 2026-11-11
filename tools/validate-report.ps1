param(
    [string]$ReportPath = (Join-Path $PSScriptRoot "..\README.md")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ReportPath -PathType Leaf)) {
    throw "No se encontro el informe: $ReportPath"
}

$reportFile = Get-Item -LiteralPath $ReportPath
$reportRoot = $reportFile.Directory.FullName
$content = Get-Content -LiteralPath $reportFile.FullName -Raw -Encoding UTF8

$requiredSections = @(
    "Requirements Elicitation & Analysis",
    "Product Implementation",
    "Product Verification & Validation",
    "DevOps Practices",
    "Experiment-Driven Development"
)

$missingSections = @(
    $requiredSections | Where-Object {
        $content.IndexOf($_, [System.StringComparison]::Ordinal) -lt 0
    }
)

if ($missingSections.Count -gt 0) {
    throw ("Faltan secciones obligatorias: " + ($missingSections -join ", "))
}

$references = New-Object 'System.Collections.Generic.HashSet[string]' (
    [System.StringComparer]::OrdinalIgnoreCase
)

foreach ($match in [regex]::Matches($content, '(?:\]\(|src=")([^"]+?)(?:\)|")')) {
    $reference = $match.Groups[1].Value
    if (
        $reference.StartsWith("http://") -or
        $reference.StartsWith("https://") -or
        $reference.StartsWith("#") -or
        $reference.StartsWith("mailto:")
    ) {
        continue
    }

    $reference = $reference.Split("#")[0]
    if ($reference) {
        [void]$references.Add($reference)
    }
}

$missingReferences = @(
    $references | Where-Object {
        -not (Test-Path -LiteralPath (Join-Path $reportRoot $_) -PathType Leaf)
    }
)

if ($missingReferences.Count -gt 0) {
    throw ("Referencias locales inexistentes: " + ($missingReferences -join ", "))
}

Write-Output (
    "Informe valido: {0} secciones obligatorias y {1} referencias locales verificadas." -f
    $requiredSections.Count,
    $references.Count
)
