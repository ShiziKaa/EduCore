. "$PSScriptRoot\common.ps1"

if (-not (Test-Path $DbAssetsDir)) {
    throw "$DbFolderName not found at $DbAssetsDir. Run scripts\setup_educore_db.ps1 first."
}

$modelsPath = Join-Path $DbAssetsDir "models"
New-Item -ItemType Directory -Path $modelsPath -Force | Out-Null

Write-Host "==> [$AppDisplayName] Downloading intfloat/multilingual-e5-base into:" -ForegroundColor Cyan
Write-Host $modelsPath -ForegroundColor Yellow
Write-Host "Expected size: ~1.1 GB. Please wait..." -ForegroundColor Cyan

$env:EDUCORE_DB_DIR = $DbAssetsDir
$env:SENTENCE_TRANSFORMERS_HOME = $modelsPath
$env:HF_HOME = $modelsPath

Push-Location $PythonBackDir
try {
    python download_model.py --target $DbAssetsDir
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

    Write-Host "Building ChromaDB index..." -ForegroundColor Cyan
    python -c "from database_builder import build_database; print(build_database(r'$DbAssetsDir'))"
} finally {
    Pop-Location
}

$sizeGb = (Get-ChildItem $modelsPath -Recurse -File | Measure-Object Length -Sum).Sum / 1GB
Write-Host ""
Write-Host "Model ready in assets/$DbFolderName/models ($([math]::Round($sizeGb, 2)) GB)" -ForegroundColor Green
Write-Host "Next: scripts\build_windows.ps1  OR  cd EduCoreApp && flutter run -d windows" -ForegroundColor Green
