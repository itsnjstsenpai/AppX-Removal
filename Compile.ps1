$ErrorActionPreference = "Stop"
$OFS = "`r`n"

$root = $PSScriptRoot
$functions = Get-ChildItem -Path (Join-Path $root "functions") -Filter "*.ps1" -File | Sort-Object -Property Name
$script = ($functions | ForEach-Object { Get-Content -Path $_.FullName -Raw }) -join "`r`n"
$xaml = Get-Content -Path (Join-Path $root "xaml\MainWindow.xaml") -Raw
$script += "`r`n`$AppxRemovalXaml = @'`r`n$xaml`r`n'@`r`n"
$script += Get-Content -Path (Join-Path $root "scripts\main.ps1") -Raw

$outputPath = Join-Path $root "AppX-Removal.ps1"
Set-Content -Path $outputPath -Value $script -Encoding UTF8
Write-Host "Built $outputPath"
