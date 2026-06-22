$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$PythonBack = Join-Path $Root "PythonBack"
$FlutterApp = Join-Path $Root "EduCoreApp"
$DbRoot = Join-Path $FlutterApp "assets\EduCore_DB"
$SearchDist = Join-Path $PythonBack "dist\search_engine"
$BuilderDist = Join-Path $PythonBack "dist\database_builder"
$DataSource = Join-Path $PythonBack "data"

Write-Host "==> Preparing assets/EduCore_DB at $DbRoot" -ForegroundColor Cyan

if (Test-Path $DbRoot) {
    Remove-Item $DbRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $DbRoot | Out-Null
foreach ($folder in @("data", "images", "videos", "chroma_db", "models")) {
    $path = Join-Path $DbRoot $folder
    New-Item -ItemType Directory -Path $path | Out-Null
    New-Item -ItemType File -Path (Join-Path $path ".gitkeep") -Force | Out-Null
}

Write-Host "==> Syncing search_engine bundle into assets..." -ForegroundColor Cyan
$DistExe = Join-Path $PythonBack "dist\search_engine\search_engine.exe"
if (-not (Test-Path $DistExe)) {
    Write-Host "search_engine.exe not found. Building with PyInstaller..." -ForegroundColor Yellow
    powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "build_search_engine.ps1")
} else {
    powershell -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot "sync_search_engine.ps1")
}

if (Test-Path $DataSource) {
    Write-Host "==> Copying starter data..." -ForegroundColor Cyan
    Copy-Item "$DataSource\*" (Join-Path $DbRoot "data") -Recurse -Force
}

Write-Host "==> Downloading model into assets/EduCore_DB/models (~1.1 GB)..." -ForegroundColor Cyan
$modelsPath = Join-Path $DbRoot "models"
$env:EDUCORE_DB_DIR = $DbRoot
$env:SENTENCE_TRANSFORMERS_HOME = $modelsPath
$env:HF_HOME = $modelsPath

$existingSize = 0
if (Test-Path $modelsPath) {
    $existingSize = (Get-ChildItem $modelsPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
}

if ($existingSize -gt 500MB) {
    Write-Host "Model already present ($([math]::Round($existingSize/1GB, 2)) GB), skipping download." -ForegroundColor Green
} else {
    Push-Location $PythonBack
    python download_model.py --target $DbRoot
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Model download failed. Run scripts/download_model.ps1 when online."
    }
    Pop-Location
}

Write-Host "==> Building initial ChromaDB index..." -ForegroundColor Cyan
Push-Location $PythonBack
python -c "from database_builder import build_database; print(build_database(r'$DbRoot'))"
Pop-Location

Write-Host ""
Write-Host "Done. EduCore_DB assets are ready at:" -ForegroundColor Green
Write-Host $DbRoot -ForegroundColor Green
Write-Host "Next: cd EduCoreApp && flutter build windows" -ForegroundColor Green
