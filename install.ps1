[CmdletBinding()]
param(
    [switch]$AllHyperFramesSkills,
    [switch]$SkipDreamina,
    [string]$IreneSource,
    [string]$IreneStage2Source
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) {
    throw 'This installer is for Windows only.'
}

$RootDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$StateDir = Join-Path $env:LOCALAPPDATA 'AI-Video-Workstation'
$NodeDir = Join-Path $StateDir 'node22-current'
$BinDir = Join-Path $StateDir 'bin'
$NpmPrefix = Join-Path $StateDir 'npm'
$CanvasDir = Join-Path $StateDir 'canvas-video'
$CodexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }

function Write-Step([string]$Message) {
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Invoke-Checked([string]$FilePath, [string[]]$Arguments) {
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$FilePath failed with exit code $LASTEXITCODE."
    }
}

function Refresh-ProcessPath {
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = (@($NodeDir, $BinDir, $NpmPrefix, $machinePath, $userPath) | Where-Object { $_ }) -join ';'
}

function Add-UserPath([string[]]$Entries) {
    $current = [Environment]::GetEnvironmentVariable('Path', 'User')
    $parts = @($current -split ';' | Where-Object { $_ })
    foreach ($entry in $Entries) {
        if (-not ($parts | Where-Object { $_.TrimEnd('\') -ieq $entry.TrimEnd('\') })) {
            $parts = @($entry) + $parts
        }
    }
    [Environment]::SetEnvironmentVariable('Path', ($parts -join ';'), 'User')
    Refresh-ProcessPath
}

function Install-Node22 {
    Write-Step 'Installing the latest Node.js 22 Windows archive'
    $architecture = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
    $nodeArch = switch -Regex ($architecture) {
        'ARM64' { 'arm64'; break }
        'AMD64|x86_64' { 'x64'; break }
        default { throw "Unsupported Windows architecture: $architecture" }
    }

    $tempDir = Join-Path ([IO.Path]::GetTempPath()) ("ai-video-node-" + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    try {
        $checksumsPath = Join-Path $tempDir 'SHASUMS256.txt'
        Invoke-WebRequest -UseBasicParsing -Uri 'https://nodejs.org/dist/latest-v22.x/SHASUMS256.txt' -OutFile $checksumsPath
        $checksums = Get-Content -Raw -LiteralPath $checksumsPath
        $pattern = "(?m)^([a-fA-F0-9]{64})\s+(node-v22[^\s]+-win-$nodeArch\.zip)\s*$"
        $match = [regex]::Match($checksums, $pattern)
        if (-not $match.Success) {
            throw "Could not find a Node.js 22 archive for win-$nodeArch."
        }

        $expectedHash = $match.Groups[1].Value.ToLowerInvariant()
        $archiveName = $match.Groups[2].Value
        $archivePath = Join-Path $tempDir $archiveName
        Invoke-WebRequest -UseBasicParsing -Uri "https://nodejs.org/dist/latest-v22.x/$archiveName" -OutFile $archivePath
        $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $archivePath).Hash.ToLowerInvariant()
        if ($actualHash -ne $expectedHash) {
            throw 'Node.js archive checksum mismatch.'
        }

        $extractDir = Join-Path $tempDir 'extract'
        Expand-Archive -LiteralPath $archivePath -DestinationPath $extractDir -Force
        $extractedRoot = Get-ChildItem -LiteralPath $extractDir -Directory | Select-Object -First 1
        if (-not $extractedRoot -or -not (Test-Path (Join-Path $extractedRoot.FullName 'node.exe'))) {
            throw 'The downloaded Node.js archive has an unexpected layout.'
        }
        if (Test-Path $NodeDir) {
            Remove-Item -LiteralPath $NodeDir -Recurse -Force
        }
        Move-Item -LiteralPath $extractedRoot.FullName -Destination $NodeDir
    }
    finally {
        if (Test-Path $tempDir) {
            Remove-Item -LiteralPath $tempDir -Recurse -Force
        }
    }
}

function Install-WinGetPackage([string]$Id, [string]$DisplayName) {
    $winget = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $winget) {
        throw "$DisplayName is missing and WinGet is unavailable. Install Microsoft App Installer, then rerun."
    }
    Write-Step "Installing $DisplayName with WinGet"
    Invoke-Checked $winget.Source @(
        'install', '--id', $Id, '--exact', '--source', 'winget', '--silent',
        '--accept-source-agreements', '--accept-package-agreements', '--disable-interactivity'
    )
    Refresh-ProcessPath
}

function Ensure-MediaTools {
    if (-not (Get-Command ffmpeg.exe -ErrorAction SilentlyContinue) -or -not (Get-Command ffprobe.exe -ErrorAction SilentlyContinue)) {
        Install-WinGetPackage 'Gyan.FFmpeg' 'FFmpeg and FFprobe'
    }
    if (-not (Get-Command ffmpeg.exe -ErrorAction SilentlyContinue) -or -not (Get-Command ffprobe.exe -ErrorAction SilentlyContinue)) {
        throw 'FFmpeg installation completed but ffmpeg.exe or ffprobe.exe is not visible on PATH. Open a new terminal and rerun install.ps1.'
    }
}

function Ensure-Python {
    $pythonAvailable = (Get-Command py.exe -ErrorAction SilentlyContinue) -or (Get-Command python.exe -ErrorAction SilentlyContinue)
    if (-not $pythonAvailable) {
        Install-WinGetPackage 'Python.Python.3.12' 'Python 3.12 for video QC'
    }
    if (-not (Get-Command py.exe -ErrorAction SilentlyContinue) -and -not (Get-Command python.exe -ErrorAction SilentlyContinue)) {
        throw 'Python installation completed but Python is not visible on PATH. Open a new terminal and rerun install.ps1.'
    }
}

function Install-HyperFrames {
    Write-Step 'Installing HyperFrames CLI'
    $npm = Join-Path $NodeDir 'npm.cmd'
    Invoke-Checked $npm @('install', '-g', '--prefix', $NpmPrefix, 'hyperframes@latest', '--no-audit', '--no-fund')
    $hyperframes = Join-Path $NpmPrefix 'hyperframes.cmd'
    if ($AllHyperFramesSkills) {
        Invoke-Checked $hyperframes @('skills')
    }
    else {
        Invoke-Checked $hyperframes @('skills', 'update')
    }
}

function Install-Dreamina {
    if ($SkipDreamina) {
        Write-Host 'Skipping Dreamina Canvas installation by request.' -ForegroundColor Yellow
        return
    }
    Write-Step 'Running the official Dreamina Canvas Windows installer'
    $tempScript = Join-Path ([IO.Path]::GetTempPath()) ("dreamina-canvas-install-" + [guid]::NewGuid().ToString('N') + '.ps1')
    try {
        Invoke-WebRequest -UseBasicParsing -Uri 'https://jimeng.jianying.com/canvas-cli/install.ps1' -OutFile $tempScript
        Invoke-Checked 'powershell.exe' @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $tempScript)
    }
    finally {
        if (Test-Path $tempScript) {
            Remove-Item -LiteralPath $tempScript -Force
        }
    }
    Refresh-ProcessPath
}

function Install-CanvasVideo {
    Write-Step 'Installing the isolated Canvas Video runtime'
    New-Item -ItemType Directory -Path $CanvasDir -Force | Out-Null
    foreach ($name in @('bin', 'lib', 'templates')) {
        $destination = Join-Path $CanvasDir $name
        if (Test-Path $destination) {
            Remove-Item -LiteralPath $destination -Recurse -Force
        }
        Copy-Item -LiteralPath (Join-Path $RootDir "runtime\canvas-video\$name") -Destination $destination -Recurse -Force
    }
    foreach ($name in @('package.json', 'package-lock.json')) {
        Copy-Item -LiteralPath (Join-Path $RootDir "runtime\canvas-video\$name") -Destination (Join-Path $CanvasDir $name) -Force
    }

    $npm = Join-Path $NodeDir 'npm.cmd'
    Invoke-Checked $npm @('ci', '--prefix', $CanvasDir, '--no-audit', '--no-fund')
    $playwright = Join-Path $CanvasDir 'node_modules\playwright\cli.js'
    Invoke-Checked (Join-Path $NodeDir 'node.exe') @($playwright, 'install', 'chromium')

    $wrapper = Join-Path $BinDir 'canvas-video.cmd'
    $entry = Join-Path $CanvasDir 'bin\canvas-video.mjs'
    $content = "@echo off`r`n`"$NodeDir\node.exe`" `"$entry`" %*`r`n"
    [IO.File]::WriteAllText($wrapper, $content, [Text.UTF8Encoding]::new($false))
}

function Install-BundledSkills {
    Write-Step 'Installing bundled Codex Skills'
    $skillsRoot = Join-Path $CodexHome 'skills'
    New-Item -ItemType Directory -Path $skillsRoot -Force | Out-Null
    foreach ($skillName in @('canvas-video-pipeline', 'video-delivery-qc')) {
        $source = Join-Path $RootDir "skills\$skillName"
        $destination = Join-Path $skillsRoot $skillName
        if (Test-Path $destination) {
            Remove-Item -LiteralPath $destination -Recurse -Force
        }
        Copy-Item -LiteralPath $source -Destination $destination -Recurse -Force
    }
}

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
New-Item -ItemType Directory -Path $StateDir, $BinDir, $NpmPrefix -Force | Out-Null

Install-Node22
Add-UserPath @($NodeDir, $BinDir, $NpmPrefix)
Refresh-ProcessPath
Write-Host "Node.js: $(& (Join-Path $NodeDir 'node.exe') --version)"
Write-Host "npm: $(& (Join-Path $NodeDir 'npm.cmd') --version)"

Ensure-MediaTools
Ensure-Python
Install-HyperFrames
Install-Dreamina
Install-CanvasVideo
Install-BundledSkills
if ($IreneSource) {
    Write-Step 'Importing selected Irene capability Skills'
    & (Join-Path $RootDir 'scripts\import-irene_skills.ps1') -SourceDirectory $IreneSource
    if ($LASTEXITCODE -ne 0) { throw 'Irene Skill import failed.' }
}
if ($IreneStage2Source) {
    Write-Step 'Importing Irene stage-two beat editing Skill'
    & (Join-Path $RootDir 'scripts\import-irene_stage2.ps1') -SourceDirectory $IreneStage2Source
    if ($LASTEXITCODE -ne 0) { throw 'Irene stage-two Skill import failed.' }
}

Write-Step 'Running installation verification'
& (Join-Path $RootDir 'scripts\verify.ps1') -AllowMissingDreamina:$SkipDreamina
if ($LASTEXITCODE -ne 0) {
    throw 'Verification reported one or more required failures.'
}

Write-Step 'Running a native 9:16 render smoke test'
& (Join-Path $RootDir 'scripts\smoke-test.ps1')
if ($LASTEXITCODE -ne 0) {
    throw 'Canvas Video render smoke test failed.'
}

Write-Host "`nInstallation finished." -ForegroundColor Green
Write-Host 'Next: run .\scripts\login.ps1 to authorize Dreamina Canvas.'
Write-Host 'Restart Codex after installation so it discovers the new Skills.'
