$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Dist = Join-Path $Root "PythonBack\dist\search_engine"
$DbRoot = Join-Path $Root "EduCore\assets\EduCore_DB"

if (-not (Test-Path (Join-Path $Dist "search_engine.exe"))) {
    throw "Run PyInstaller first: python -m PyInstaller search_engine.spec --noconfirm"
}

New-Item -ItemType Directory -Path $DbRoot -Force | Out-Null
foreach ($folder in @("data", "images", "videos", "chroma_db", "models")) {
    New-Item -ItemType Directory -Path (Join-Path $DbRoot $folder) -Force | Out-Null
}

Write-Host "Syncing search_engine.exe + _internal..." -ForegroundColor Cyan
Copy-Item (Join-Path $Dist "search_engine.exe") (Join-Path $DbRoot "search_engine.exe") -Force
if (Test-Path (Join-Path $DbRoot "_internal")) {
    Remove-Item (Join-Path $DbRoot "_internal") -Recurse -Force
}
Copy-Item (Join-Path $Dist "_internal") (Join-Path $DbRoot "_internal") -Recurse

$imagesSource = Join-Path $Root "PythonBack\images"
if (Test-Path $imagesSource) {
    Copy-Item "$imagesSource\*" (Join-Path $DbRoot "images") -Recurse -Force
}

Write-Host "Done: $DbRoot" -ForegroundColor Green
