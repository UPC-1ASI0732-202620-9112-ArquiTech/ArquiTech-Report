$ErrorActionPreference = "Stop"

$testRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("report-validator-" + [guid]::NewGuid().ToString("N"))
$assetsRoot = Join-Path $testRoot "assets"
New-Item -ItemType Directory -Path $assetsRoot -Force | Out-Null

try {
    Set-Content -LiteralPath (Join-Path $assetsRoot "sample.txt") -Value "fixture" -Encoding UTF8
    $validReadme = @"
# Report
## Requirements Elicitation & Analysis
## Product Implementation
## Product Verification & Validation
## DevOps Practices
## Experiment-Driven Development
![fixture](assets/sample.txt)
"@
    $readmePath = Join-Path $testRoot "README.md"
    Set-Content -LiteralPath $readmePath -Value $validReadme -Encoding UTF8

    $validator = Join-Path $PSScriptRoot "validate-report.ps1"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $validator -ReportPath $readmePath
    if ($LASTEXITCODE -ne 0) {
        throw "La validacion del informe minimo debio aprobar."
    }

    Add-Content -LiteralPath $readmePath -Value "`n![missing](assets/missing.txt)"
    & powershell -NoProfile -ExecutionPolicy Bypass -File $validator -ReportPath $readmePath
    if ($LASTEXITCODE -eq 0) {
        throw "La validacion debio fallar ante una referencia inexistente."
    }

    Write-Output "Pruebas del validador aprobadas: caso valido y referencia inexistente."
}
finally {
    if (Test-Path -LiteralPath $testRoot) {
        Remove-Item -LiteralPath $testRoot -Recurse -Force
    }
}
