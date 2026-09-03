# Shared paths for Bilim Çeşmesi build scripts.
# Dot-source: . "$PSScriptRoot\common.ps1"

$ErrorActionPreference = "Stop"

$script:RepoRoot = Split-Path -Parent $PSScriptRoot
$script:FlutterAppDir = Join-Path $RepoRoot "EduCoreApp"
$script:PythonBackDir = Join-Path $RepoRoot "PythonBack"
$script:DbFolderName = "EduCore_DB"
$script:DbAssetsDir = Join-Path $FlutterAppDir "assets\$DbFolderName"
$script:SearchEngineDistDir = Join-Path $PythonBackDir "dist\search_engine"
$script:SearchEngineExeName = "search_engine.exe"
$script:SearchEngineDistExe = Join-Path $SearchEngineDistDir $SearchEngineExeName
$script:SearchEngineSpec = Join-Path $PythonBackDir "search_engine.spec"
$script:AppDisplayName = "Bilim Çeşmesi"
$script:WindowsBinaryName = "educore.exe"
$script:DbWorkspaceFolders = @("data", "images", "videos", "audios", "chroma_db", "models")

$script:DebugDbDir = Join-Path $FlutterAppDir "build\windows\x64\runner\Debug\$DbFolderName"
$script:ReleaseDbDir = Join-Path $FlutterAppDir "build\windows\x64\runner\Release\$DbFolderName"
$script:ReleaseDir = Join-Path $FlutterAppDir "build\windows\x64\runner\Release"

function Ensure-DbWorkspaceFolders {
    param([Parameter(Mandatory = $true)][string]$TargetDb)

    New-Item -ItemType Directory -Path $TargetDb -Force | Out-Null
    foreach ($folder in $DbWorkspaceFolders) {
        New-Item -ItemType Directory -Path (Join-Path $TargetDb $folder) -Force | Out-Null
    }
}

function Stop-LockedAiProcesses {
    $names = @("search_engine", "educore", "database_builder")
    foreach ($name in $names) {
        Get-Process -Name $name -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Host "Stopping locked process: $($_.ProcessName) (PID $($_.Id))" -ForegroundColor Yellow
            Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
        }
    }
    Start-Sleep -Seconds 1
}

function Invoke-Script {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [string[]]$ArgumentList = @()
    )

    $path = Join-Path $PSScriptRoot $Name
    if (-not (Test-Path $path)) {
        throw "Script not found: $path"
    }

    & powershell -ExecutionPolicy Bypass -File $path @ArgumentList
    if ($LASTEXITCODE -ne 0) {
        throw "Script failed: $Name (exit $LASTEXITCODE)"
    }
}
