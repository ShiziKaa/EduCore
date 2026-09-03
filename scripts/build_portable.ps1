. "$PSScriptRoot\common.ps1"

Write-Host "==> [$AppDisplayName] Step 1: Rebuild search_engine.exe and sync assets" -ForegroundColor Cyan
Stop-LockedAiProcesses
Invoke-Script -Name "build_search_engine.ps1"

Write-Host "==> Step 2: Checking model in assets..." -ForegroundColor Cyan
$modelsPath = Join-Path $DbAssetsDir "models"
$size = (Get-ChildItem $modelsPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
if ($size -lt 500MB) {
    Write-Host "Model missing or incomplete. Running download_model.ps1..." -ForegroundColor Yellow
    Invoke-Script -Name "download_model.ps1"
} else {
    Write-Host "Model OK: $([math]::Round($size / 1GB, 2)) GB in assets/$DbFolderName/models" -ForegroundColor Green
}

Write-Host "==> Step 3: Build Flutter Windows release" -ForegroundColor Cyan
Stop-LockedAiProcesses
Push-Location $FlutterAppDir
try {
    flutter pub get
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    flutter build windows --release
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "Portable/release build ready:" -ForegroundColor Green
Write-Host $ReleaseDir -ForegroundColor Green
Write-Host "Run: $WindowsBinaryName" -ForegroundColor Green
Write-Host "AI bundle next to exe: $DbFolderName" -ForegroundColor Green
Write-Host "App: $AppDisplayName" -ForegroundColor Green
