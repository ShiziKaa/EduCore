$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$FlutterApp = Join-Path $Root "EduCore"
$ModelsPath = Join-Path $FlutterApp "assets\EduCore_DB\models"

Write-Host "==> Checking model in assets..." -ForegroundColor Cyan
$size = (Get-ChildItem $ModelsPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
if ($size -lt 500MB) {
    Write-Host "Model missing or incomplete. Running download_model.ps1..." -ForegroundColor Yellow
    powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "download_model.ps1")
} else {
    Write-Host "Model OK: $([math]::Round($size/1GB, 2)) GB in assets/EduCore_DB/models" -ForegroundColor Green
}

Write-Host "==> Building Windows release..." -ForegroundColor Cyan
Push-Location $FlutterApp
flutter pub get
flutter build windows --release
Pop-Location

$release = Join-Path $FlutterApp "build\windows\x64\runner\Release"
$bundled = Join-Path $release "data\flutter_assets\assets\EduCore_DB\models"
$bundleSize = (Get-ChildItem $bundled -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum

Write-Host ""
Write-Host "Release: $release" -ForegroundColor Green
Write-Host "Bundled model: $([math]::Round($bundleSize/1GB, 2)) GB" -ForegroundColor Green
