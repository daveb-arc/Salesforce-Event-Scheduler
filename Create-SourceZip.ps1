$ErrorActionPreference = 'Stop'

$repoRoot = $PSScriptRoot
$srcPath = Join-Path $repoRoot 'src'

if (-not (Test-Path -LiteralPath $srcPath -PathType Container)) {
    throw "src directory not found: $srcPath"
}

$repoName = Split-Path -Leaf $repoRoot
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

# Delete previous ZIPs created for this repository.
Get-ChildItem -LiteralPath $repoRoot -File -Filter "$repoName*.zip" |
    Remove-Item -Force

$outputZip = Join-Path $repoRoot "$repoName-$timestamp.zip"

Compress-Archive `
    -Path $srcPath `
    -DestinationPath $outputZip `
    -CompressionLevel Optimal

Write-Host "Created $outputZip"