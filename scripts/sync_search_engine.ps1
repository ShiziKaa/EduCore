$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
$Dist = Join-Path $Root "PythonBack\dist\search_engine"
$DbRoot = Join-Path $Root "EduCoreApp\assets\EduCore_DB"
$FlutterApp = Join-Path $Root "EduCoreApp"

if (-not (Test-Path (Join-Path $Dist "search_engine.exe"))) {
    throw "Run scripts/build_search_engine.ps1 first."
}

New-Item -ItemType Directory -Path $DbRoot -Force | Out-Null
foreach ($folder in @("data", "images", "videos", "chroma_db", "models")) {
    New-Item -ItemType Directory -Path (Join-Path $DbRoot $folder) -Force | Out-Null
}

function Sync-BundleTo {
    param(
        [string]$TargetDb
    )

    if (-not (Test-Path $TargetDb)) {
        return $false
    }

    New-Item -ItemType Directory -Path $TargetDb -Force | Out-Null
    foreach ($folder in @("data", "images", "videos", "chroma_db", "models")) {
        New-Item -ItemType Directory -Path (Join-Path $TargetDb $folder) -Force | Out-Null
    }

    Copy-Item (Join-Path $Dist "search_engine.exe") (Join-Path $TargetDb "search_engine.exe") -Force
    if (Test-Path (Join-Path $TargetDb "_internal")) {
        Remove-Item (Join-Path $TargetDb "_internal") -Recurse -Force
    }
    Copy-Item (Join-Path $Dist "_internal") (Join-Path $TargetDb "_internal") -Recurse
    return $true
}

Write-Host "Syncing search_engine.exe + _internal into assets..." -ForegroundColor Cyan
Sync-BundleTo -TargetDb $DbRoot | Out-Null

$imagesSource = Join-Path $Root "PythonBack\images"
if (Test-Path $imagesSource) {
    Copy-Item "$imagesSource\*" (Join-Path $DbRoot "images") -Recurse -Force
}

Write-Host "Done: $DbRoot" -ForegroundColor Green

$runtimeTargets = @(
    (Join-Path $FlutterApp "build\windows\x64\runner\Debug\EduCore_DB"),
    (Join-Path $FlutterApp "build\windows\x64\runner\Release\EduCore_DB")
)

foreach ($target in $runtimeTargets) {
    if (-not (Test-Path (Split-Path $target -Parent))) {
        continue
    }

    Write-Host "Updating runtime bundle: $target" -ForegroundColor Cyan
    try {
        if (Sync-BundleTo -TargetDb $target) {
            Write-Host "Runtime bundle updated." -ForegroundColor Green
        }
    } catch {
        Write-Warning "Could not update $target (app may be running). Stop flutter run and rerun sync."
    }
}

Write-Host ""
Write-Host "If flutter run is active, restart it to load the new search_engine.exe." -ForegroundColor Yellow
