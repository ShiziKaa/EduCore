param(
    [switch]$SyncOnly
)

. "$PSScriptRoot\common.ps1"

if ($SyncOnly) {
    if (-not (Test-Path $SearchEngineDistExe)) {
        throw "search_engine.exe not found. Run without -SyncOnly first."
    }
    Invoke-Script -Name "sync_search_engine.ps1"
    exit 0
}

Write-Host "==> [$AppDisplayName] Building search_engine.exe with PyInstaller..." -ForegroundColor Cyan

Push-Location $PythonBackDir
try {
    Write-Host "Installing Python dependencies..." -ForegroundColor DarkCyan
    python -m pip install -r requirements.txt --quiet
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    python -m PyInstaller $SearchEngineSpec --noconfirm --clean
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
finally {
    Pop-Location
}

if (-not (Test-Path $SearchEngineDistExe)) {
    throw "PyInstaller finished but $SearchEngineDistExe was not created."
}

Write-Host "PyInstaller OK: $SearchEngineDistExe" -ForegroundColor Green

Write-Host "==> Syncing bundle into Flutter assets..." -ForegroundColor Cyan
Invoke-Script -Name "sync_search_engine.ps1"

Write-Host ""
Write-Host "search_engine bundle is ready in:" -ForegroundColor Green
Write-Host $DbAssetsDir -ForegroundColor Green
Write-Host "Next: stop flutter run if active, then scripts\build_windows.ps1 or flutter run -d windows" -ForegroundColor Yellow
