[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$SourceDirectory)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$sourceRoot = (Resolve-Path -LiteralPath $SourceDirectory).Path
$codexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
$skillsRoot = Join-Path $codexHome 'skills'
$ireneRoot = Join-Path $env:USERPROFILE '.irene'
$venv = Join-Path $ireneRoot 'venv'
$skillNames = @('footage-sifter', 'caption-doctor', 'subtitle-translator')

foreach ($skillName in $skillNames) {
    $skillFile = Join-Path $sourceRoot "skills\$skillName\SKILL.md"
    if (-not (Test-Path -LiteralPath $skillFile -PathType Leaf)) {
        throw "Missing source Skill: $skillFile"
    }
}

$python = Get-Command py.exe -ErrorAction SilentlyContinue
if (-not $python) { $python = Get-Command python.exe -ErrorAction SilentlyContinue }
if (-not $python) { throw 'Python 3 is required to import the Irene skills.' }

New-Item -ItemType Directory -Path $skillsRoot, $ireneRoot -Force | Out-Null
$venvPython = Join-Path $venv 'Scripts\python.exe'
if (-not (Test-Path -LiteralPath $venvPython)) {
    Write-Host "Creating isolated Irene Python environment: $venv"
    if ($python.Name -ieq 'py.exe') { & $python.Source -3 -m venv $venv }
    else { & $python.Source -m venv $venv }
    if ($LASTEXITCODE -ne 0) { throw 'Unable to create Irene Python environment.' }
}

& $venvPython -m pip install --disable-pip-version-check 'opencc-python-reimplemented>=0.1.7' 'jieba>=0.42'
if ($LASTEXITCODE -ne 0) { throw 'Unable to install opencc and jieba in the Irene environment.' }

$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
foreach ($skillName in $skillNames) {
    $sourceSkill = Join-Path $sourceRoot "skills\$skillName"
    $destination = Join-Path $skillsRoot $skillName
    $staging = Join-Path ([IO.Path]::GetTempPath()) ("irene-skill-$skillName-" + [guid]::NewGuid().ToString('N'))
    try {
        Copy-Item -LiteralPath $sourceSkill -Destination $staging -Recurse -Force
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
        Write-Host "Imported $skillName -> $destination"
    }
    finally {
        if (Test-Path -LiteralPath $staging) { Remove-Item -LiteralPath $staging -Recurse -Force }
    }
}

Write-Host "`nImported 3 Irene capability Skills. Restart Codex or open a new chat." -ForegroundColor Green
