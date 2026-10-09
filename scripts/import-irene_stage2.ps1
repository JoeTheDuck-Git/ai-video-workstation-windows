[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$SourceDirectory)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$sourceRoot = (Resolve-Path -LiteralPath $SourceDirectory).Path
$sourceSkill = Join-Path $sourceRoot 'skills\beat-cut-editor'
$skillFile = Join-Path $sourceSkill 'SKILL.md'
if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
    throw "Missing source Skill: $skillFile"
}

$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
$skillsRoot = Join-Path $codexHome 'skills'
$ireneRoot = Join-Path $env:USERPROFILE '.irene'
$venv = Join-Path $ireneRoot 'venv'
$venvPython = Join-Path $venv 'Scripts\python.exe'
$destination = Join-Path $skillsRoot 'beat-cut-editor'

$python = Get-Command py.exe -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python.exe -ErrorAction SilentlyContinue }
if (-not $python) { throw 'Python 3 is required to import beat-cut-editor.' }
$npm = Get-Command npm.cmd -ErrorAction SilentlyContinue
if (-not $npm) { throw 'Node.js/npm is required to prepare beat-cut-editor overlays.' }

New-Item -ItemType Directory -Path $skillsRoot, $ireneRoot -Force | Out-Null
if (-not (Test-Path -LiteralPath $venvPython)) {
    Write-Host "Creating isolated Irene Python environment: $venv"
    if ($python.Name -ieq 'py.exe') { & $python.Source -3 -m venv $venv }
    else { & $python.Source -m venv $venv }
    if ($LASTEXITCODE -ne 0) { throw 'Unable to create Irene Python environment.' }
}

Write-Host 'Installing beat-cut core dependencies in the isolated Irene environment.'
& $venvPython -m pip install --disable-pip-version-check `
    'static-ffmpeg>=2.7' 'scenedetect[opencv-headless]>=0.6,<0.7' 'pillow>=10' `
    'numpy>=1.26' 'jieba>=0.42' 'opencc-python-reimplemented>=0.1.7'
if ($LASTEXITCODE -ne 0) { throw 'Unable to install beat-cut core dependencies.' }

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$staging = Join-Path ([IO.Path]::GetTempPath()) ('irene-skill-beat-cut-editor-' + [guid]::NewGuid().ToString('N'))
try {
    Copy-Item -LiteralPath $sourceSkill -Destination $staging -Recurse -Force
    Get-ChildItem -LiteralPath $staging -Recurse -Directory -Filter 'node_modules' -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force
    Get-ChildItem -LiteralPath $staging -Recurse -Directory -Filter '__pycache__' -ErrorAction SilentlyContinue |
        Remove-Item -Recurse -Force
    Get-ChildItem -LiteralPath $staging -Recurse -File -Filter '.DS_Store' -ErrorAction SilentlyContinue |
        Remove-Item -Force
    if (Test-Path -LiteralPath $destination) {
        $backup = "$destination.backup-$timestamp"
        Move-Item -LiteralPath $destination -Destination $backup
        Write-Host "Backed up existing Skill: $backup"
    }
    Move-Item -LiteralPath $staging -Destination $destination
}
finally {
    if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
}

$overlay = Join-Path $destination 'scripts\overlay'
if (Test-Path -LiteralPath (Join-Path $overlay 'package-lock.json')) {
    Push-Location $overlay
    try {
        & $npm.Source ci --no-audit --no-fund
        if ($LASTEXITCODE -ne 0) { throw 'Unable to install beat-cut overlay dependencies.' }
    }
    finally { Pop-Location }
}

Write-Host "`nImported beat-cut-editor -> $destination" -ForegroundColor Green
Write-Host 'Optional transcription: .irene\venv\Scripts\python.exe -m pip install faster-whisper'
Write-Host 'Optional custom-song analysis: .irene\venv\Scripts\python.exe -m pip install librosa'
Write-Host 'Restart Codex or open a new chat to refresh Skill discovery.'
