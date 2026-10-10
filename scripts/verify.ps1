[CmdletBinding()]
param(
    [switch]$CodexOnly,
    [switch]$ClaudeOnly
)

$ErrorActionPreference = 'Continue'
Set-StrictMode -Version Latest

$StateDir = Join-Path $env:LOCALAPPDATA 'AI-Video-Workstation'
$CodexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
$ClaudeHome = if ($env:CLAUDE_HOME) { $env:CLAUDE_HOME } else { Join-Path $env:USERPROFILE '.claude' }
$managedPython = Join-Path $StateDir 'python-venv\Scripts\python.exe'
$paths = @(
    (Join-Path $StateDir 'node22-current'),
    (Join-Path $StateDir 'bin'),
    (Join-Path $StateDir 'npm'),
    [Environment]::GetEnvironmentVariable('Path', 'Machine'),
    [Environment]::GetEnvironmentVariable('Path', 'User')
) | Where-Object { $_ }
$env:Path = $paths -join ';'
$failures = 0

if ($CodexOnly -and $ClaudeOnly) {
    throw '-CodexOnly and -ClaudeOnly cannot be combined.'
}

function Pass([string]$Message) { Write-Host "PASS  $Message" -ForegroundColor Green }
function Warn([string]$Message) { Write-Host "WARN  $Message" -ForegroundColor Yellow }
function Fail([string]$Message) { Write-Host "FAIL  $Message" -ForegroundColor Red; $script:failures += 1 }

function Resolve-Command([string[]]$Names) {
    foreach ($name in $Names) {
        $command = Get-Command $name -ErrorAction SilentlyContinue
        if ($command) { return $command }
    }
    return $null
}

Write-Host "AI Video Workstation for Windows verification`n"

$node = Resolve-Command @('node.exe')
if ($node) {
    $nodeVersion = & $node.Source --version 2>$null
    if ($nodeVersion -match '^v(\d+)\.' -and [int]$Matches[1] -ge 22) {
        Pass "Node.js $nodeVersion"
    }
    else { Fail "Node.js 22+ is required; found $nodeVersion" }
}
else { Fail 'node.exe is not available' }

$npm = Resolve-Command @('npm.cmd')
if ($npm) { Pass "npm $(& $npm.Source --version 2>$null)" } else { Fail 'npm.cmd is not available' }

$ffmpeg = Resolve-Command @('ffmpeg.exe')
$ffprobe = Resolve-Command @('ffprobe.exe')
if ($ffmpeg) { Pass "FFmpeg: $($ffmpeg.Source)" } else { Fail 'ffmpeg.exe is not available' }
if ($ffprobe) { Pass "FFprobe: $($ffprobe.Source)" } else { Fail 'ffprobe.exe is not available' }

$hyperframes = Resolve-Command @('hyperframes.cmd', 'hyperframes.exe')
if ($hyperframes) {
    Pass "HyperFrames $(& $hyperframes.Source --version 2>$null)"
    $doctorText = (& $hyperframes.Source doctor --json 2>$null) -join "`n"
    if ($doctorText) {
        Write-Host $doctorText
        try {
            $doctor = $doctorText | ConvertFrom-Json
            if ($doctor.ok) { Pass 'HyperFrames doctor' } else { Warn 'HyperFrames doctor reported optional or required items that need attention' }
        }
        catch { Warn 'HyperFrames doctor did not return valid JSON' }
    }
}
else { Fail 'hyperframes is not available' }

$canvasVideo = Resolve-Command @('canvas-video.cmd')
if ($canvasVideo) {
    $canvasDoctorText = (& $canvasVideo.Source doctor --json 2>$null) -join "`n"
    Write-Host $canvasDoctorText
    try {
        $canvasDoctor = $canvasDoctorText | ConvertFrom-Json
        if ($canvasDoctor.ok) { Pass 'canvas-video runtime' } else { Fail 'canvas-video runtime needs attention' }
    }
    catch { Fail 'canvas-video doctor did not return valid JSON' }
}
else { Fail 'canvas-video.cmd is not available' }

function Test-SkillsRoot([string]$AgentName, [string]$SkillsRoot) {
    Write-Host "`n-- $AgentName Skills --"
    $qcScript = Join-Path $SkillsRoot 'video-delivery-qc\scripts\video_qc.py'
    if ((Test-Path -LiteralPath $managedPython) -and (Test-Path -LiteralPath $qcScript)) {
        & $managedPython $qcScript --help *> $null
        if ($LASTEXITCODE -eq 0) { Pass "$AgentName`: video-delivery-qc" }
        else { Fail "$AgentName`: video-delivery-qc could not be loaded" }
    }
    else { Fail "$AgentName`: video-delivery-qc is missing or its Python runtime is unavailable" }

    foreach ($skillName in @('canvas-video-pipeline', 'footage-sifter', 'caption-doctor', 'subtitle-translator')) {
        $skillFile = Join-Path $SkillsRoot "$skillName\SKILL.md"
        if (Test-Path -LiteralPath $skillFile) { Pass "$AgentName`: $skillName" }
        else { Fail "$AgentName`: $skillName is not installed" }
    }

    $tackyEngine = Join-Path $SkillsRoot 'canvas-video-pipeline\assets\tacky-templates\engine'
    if (Test-Path -LiteralPath (Join-Path $tackyEngine 'node_modules\playwright-core\cli.js')) {
        Pass "$AgentName`: Tacky Templates isolated renderer"
    }
    else { Fail "$AgentName`: Tacky Templates renderer dependencies are not installed" }
}

if (-not $ClaudeOnly) { Test-SkillsRoot 'Codex' (Join-Path $CodexHome 'skills') }
if (-not $CodexOnly) { Test-SkillsRoot 'Claude Code' (Join-Path $ClaudeHome 'skills') }

if ($canvasVideo) {
    & $canvasVideo.Source tacky list *> $null
    if ($LASTEXITCODE -eq 0) { Pass 'canvas-video tacky command' }
    else { Fail 'canvas-video tacky command could not resolve an installed Skill' }
}

Write-Host "`n-- Shared subtitle runtime --"
if (Test-Path -LiteralPath $managedPython) {
    & $managedPython -c 'import opencc, jieba' *> $null
    if ($LASTEXITCODE -eq 0) { Pass 'subtitle dependencies (opencc, jieba)' }
    else { Fail 'Managed subtitle dependencies are missing' }
}

Write-Host ''
if ($failures -gt 0) {
    Write-Host "Verification finished with $failures required failure(s)." -ForegroundColor Red
    exit 1
}
Write-Host 'Verification passed.' -ForegroundColor Green
exit 0
