$ErrorActionPreference = "Stop"

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("toc-generator-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testRoot -Force | Out-Null
$generator = Join-Path $PSScriptRoot "generate-toc.ps1"

function Invoke-Generator {
    param([string]$Mode, [string]$Path)
    & powershell -NoProfile -ExecutionPolicy Bypass -File $generator -Mode $Mode -ReportPath $Path | Out-Null
    return $LASTEXITCODE
}

try {
    $readme = Join-Path $testRoot "README.md"
    $accentedTitle = [string]::Concat("Secci", [char]0x00F3, "n acentuada: an", [char]0x00E1, "lisis")
    $lines = @(
        "# Contenido",
        "## Tabla de contenido",
        "<!-- TOC:START -->",
        "- stale",
        "<!-- TOC:END -->",
        "# Capitulo: Introduccion",
        "## $accentedTitle",
        "### Elemento repetido",
        "### Elemento repetido",
        "## Nivel siguiente",
        '```markdown',
        "# No debe aparecer",
        '```'
    )
    Set-Content -LiteralPath $readme -Value ($lines -join [Environment]::NewLine) -Encoding UTF8

    $result = Invoke-Generator -Mode Generate -Path $readme
    if ($result -ne 0) { throw "La generacion valida debio aprobar." }

    $generated = [IO.File]::ReadAllText($readme, [Text.Encoding]::UTF8)
    $expectedAnchor = [string]::Concat("acentuada-an", [char]0x00E1, "lisis")
    if ($generated.IndexOf($expectedAnchor) -lt 0) { throw "No se genero el ancla acentuada esperada." }
    $hasDuplicates = (($generated.IndexOf("(#elemento-repetido)") -ge 0) -and ($generated.IndexOf("(#elemento-repetido-1)") -ge 0))
    if (-not $hasDuplicates) {
        throw "No se generaron anclas unicas para duplicados."
    }
    if ($generated.IndexOf("  - [Elemento repetido]") -lt 0) {
        throw "No se preservo el anidamiento de niveles."
    }

    $result = Invoke-Generator -Mode Verify -Path $readme
    if ($result -ne 0) { throw "La verificacion actualizada debio aprobar." }

    Add-Content -LiteralPath $readme -Value "`n## Encabezado nuevo"
    $result = Invoke-Generator -Mode Verify -Path $readme
    if ($result -eq 0) { throw "La verificacion debio fallar con contenido desactualizado." }

    Write-Output "Pruebas del generador aprobadas: validos, duplicados, acentos, anidamiento y contenido desactualizado."
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
