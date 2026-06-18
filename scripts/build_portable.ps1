$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$FlutterApp = Join-Path $Root "EduCore"

Write-Host "==> Step 1: Prepare EduCore_DB assets" -ForegroundColor Cyan
powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "setup_educore_db.ps1")

Write-Host "==> Step 2: Build Flutter Windows release" -ForegroundColor Cyan
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
