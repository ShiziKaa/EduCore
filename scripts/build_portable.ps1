$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$FlutterApp = Join-Path $Root "EduCoreApp"
$ModelsPath = Join-Path $FlutterApp "assets\EduCore_DB\models"

Write-Host "==> Step 1: Rebuild search_engine.exe and sync assets" -ForegroundColor Cyan
powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "build_search_engine.ps1")

Write-Host "==> Step 2: Checking model in assets..." -ForegroundColor Cyan
$size = (Get-ChildItem $ModelsPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
if ($size -lt 500MB) {
    Write-Host "Model missing or incomplete. Running download_model.ps1..." -ForegroundColor Yellow
    powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "download_model.ps1")
} else {
    Write-Host "Model OK: $([math]::Round($size/1GB, 2)) GB in assets/EduCore_DB/models" -ForegroundColor Green
}

Write-Host "==> Step 3: Build Flutter Windows release" -ForegroundColor Cyan
Push-Location $FlutterApp
flutter pub get
flutter build windows --release
Pop-Location

$ReleaseDir = Join-Path $FlutterApp "build\windows\x64\runner\Release"
Write-Host ""
Write-Host "Release ready:" -ForegroundColor Green
Write-Host $ReleaseDir -ForegroundColor Green
Write-Host "Run: educore.exe" -ForegroundColor Green
Write-Host "AI bundle: data\flutter_assets\assets\EduCore_DB" -ForegroundColor Green
