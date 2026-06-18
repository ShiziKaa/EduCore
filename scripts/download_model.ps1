$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$PythonBack = Join-Path $Root "PythonBack"
$DbRoot = Join-Path $Root "EduCore\assets\EduCore_DB"
$ModelsPath = Join-Path $DbRoot "models"

if (-not (Test-Path $DbRoot)) {
    throw "EduCore_DB not found at $DbRoot. Run setup_educore_db.ps1 first."
}

New-Item -ItemType Directory -Path $ModelsPath -Force | Out-Null

Write-Host "Downloading intfloat/multilingual-e5-base into:" -ForegroundColor Cyan
Write-Host $ModelsPath -ForegroundColor Yellow
Write-Host "Expected size: ~1.1 GB. Please wait..." -ForegroundColor Cyan

Push-Location $PythonBack
python download_model.py --target $DbRoot
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Pop-Location

Write-Host "Building ChromaDB index..." -ForegroundColor Cyan
Push-Location $PythonBack
python -c "from database_builder import build_database; print(build_database(r'$DbRoot'))"
Pop-Location

$sizeGb = (Get-ChildItem $ModelsPath -Recurse -File | Measure-Object Length -Sum).Sum / 1GB
Write-Host ""
Write-Host "Model ready in assets/EduCore_DB/models ($([math]::Round($sizeGb, 2)) GB)" -ForegroundColor Green
Write-Host "Now run: cd EduCore && flutter build windows" -ForegroundColor Green
