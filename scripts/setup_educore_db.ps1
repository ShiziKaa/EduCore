. "$PSScriptRoot\common.ps1"

Write-Host "==> [$AppDisplayName] Preparing assets/$DbFolderName at $DbAssetsDir" -ForegroundColor Cyan

Stop-LockedAiProcesses

if (Test-Path $DbAssetsDir) {
    Remove-Item $DbAssetsDir -Recurse -Force
}

Ensure-DbWorkspaceFolders -TargetDb $DbAssetsDir
foreach ($folder in $DbWorkspaceFolders) {
    New-Item -ItemType File -Path (Join-Path $DbAssetsDir "$folder\.gitkeep") -Force | Out-Null
}

Write-Host "==> Syncing search_engine bundle into assets..." -ForegroundColor Cyan
if (-not (Test-Path $SearchEngineDistExe)) {
    Write-Host "search_engine.exe not found. Building with PyInstaller..." -ForegroundColor Yellow
    Invoke-Script -Name "build_search_engine.ps1"
} else {
    Invoke-Script -Name "sync_search_engine.ps1"
}

$dataSource = Join-Path $PythonBackDir "data"
if (Test-Path $dataSource) {
    Write-Host "==> Copying starter data..." -ForegroundColor Cyan
    Copy-Item "$dataSource\*" (Join-Path $DbAssetsDir "data") -Recurse -Force
}

Write-Host "==> Downloading model into assets/$DbFolderName/models (~1.1 GB)..." -ForegroundColor Cyan
$modelsPath = Join-Path $DbAssetsDir "models"
$env:EDUCORE_DB_DIR = $DbAssetsDir
$env:SENTENCE_TRANSFORMERS_HOME = $modelsPath
$env:HF_HOME = $modelsPath

$existingSize = 0
if (Test-Path $modelsPath) {
    $existingSize = (Get-ChildItem $modelsPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
}

if ($existingSize -gt 500MB) {
    Write-Host "Model already present ($([math]::Round($existingSize / 1GB, 2)) GB), skipping download." -ForegroundColor Green
} else {
    Push-Location $PythonBackDir
    try {
        python download_model.py --target $DbAssetsDir
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Model download failed. Run scripts\download_model.ps1 when online."
        }
    } finally {
        Pop-Location
    }
}

Write-Host "==> Building initial ChromaDB index..." -ForegroundColor Cyan
Push-Location $PythonBackDir
try {
    python -c "from database_builder import build_database; print(build_database(r'$DbAssetsDir'))"
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "Done. $DbFolderName assets are ready at:" -ForegroundColor Green
Write-Host $DbAssetsDir -ForegroundColor Green
Write-Host "Next: scripts\build_windows.ps1  OR  cd EduCoreApp && flutter run -d windows" -ForegroundColor Green
