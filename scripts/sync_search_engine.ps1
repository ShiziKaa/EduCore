. "$PSScriptRoot\common.ps1"

if (-not (Test-Path $SearchEngineDistExe)) {
    throw "Run scripts\build_search_engine.ps1 first. Missing: $SearchEngineDistExe"
}

Stop-LockedAiProcesses
Ensure-DbWorkspaceFolders -TargetDb $DbAssetsDir

function Sync-BundleTo {
    param([Parameter(Mandatory = $true)][string]$TargetDb)

    if (-not (Test-Path (Split-Path $TargetDb -Parent))) {
        return $false
    }

    Ensure-DbWorkspaceFolders -TargetDb $TargetDb

    Copy-Item $SearchEngineDistExe (Join-Path $TargetDb $SearchEngineExeName) -Force

    $internalTarget = Join-Path $TargetDb "_internal"
    if (Test-Path $internalTarget) {
        Remove-Item $internalTarget -Recurse -Force
    }
    Copy-Item (Join-Path $SearchEngineDistDir "_internal") $internalTarget -Recurse
    return $true
}

Write-Host "==> [$AppDisplayName] Syncing search_engine.exe + _internal into assets..." -ForegroundColor Cyan
Sync-BundleTo -TargetDb $DbAssetsDir | Out-Null

$imagesSource = Join-Path $PythonBackDir "images"
if (Test-Path $imagesSource) {
    Copy-Item "$imagesSource\*" (Join-Path $DbAssetsDir "images") -Recurse -Force
}

$videosSource = Join-Path $PythonBackDir "videos"
if (Test-Path $videosSource) {
    Copy-Item "$videosSource\*" (Join-Path $DbAssetsDir "videos") -Recurse -Force
}

$audiosSource = Join-Path $PythonBackDir "audios"
if (Test-Path $audiosSource) {
    Copy-Item "$audiosSource\*" (Join-Path $DbAssetsDir "audios") -Recurse -Force
}

Write-Host "Done: $DbAssetsDir" -ForegroundColor Green

foreach ($target in @($DebugDbDir, $ReleaseDbDir)) {
    if (-not (Test-Path (Split-Path $target -Parent))) {
        continue
    }

    Write-Host "Updating runtime bundle: $target" -ForegroundColor Cyan
    try {
        if (Sync-BundleTo -TargetDb $target) {
            Write-Host "Runtime bundle updated." -ForegroundColor Green
        }
    } catch {
        Write-Warning "Could not update $target (files may still be locked). Stop flutter run / search_engine.exe and rerun sync."
    }
}

Write-Host ""
Write-Host "If flutter run is active, restart it to load the new search_engine.exe." -ForegroundColor Yellow
