[CmdletBinding()]
param([switch]$AllowMissingDreamina)

$ErrorActionPreference = 'Continue'
Set-StrictMode -Version Latest

$StateDir = Join-Path $env:LOCALAPPDATA 'AI-Video-Workstation'
$CodexHome = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
$paths = @(
    (Join-Path $StateDir 'node22-current'),
    (Join-Path $StateDir 'bin'),
    (Join-Path $StateDir 'npm'),
    [Environment]::GetEnvironmentVariable('Path', 'Machine'),
    [Environment]::GetEnvironmentVariable('Path', 'User')
) | Where-Object { $_ }
$env:Path = $paths -join ';'
$failures = 0

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

$dreamina = Resolve-Command @('dreamina-canvas.exe', 'dreamina-canvas.cmd')
if ($dreamina) {
    Pass "Dreamina Canvas: $($dreamina.Source)"
    $authText = (& $dreamina.Source auth status --format json 2>$null) -join "`n"
    if ($authText) {
        Write-Host $authText
        try {
            $auth = $authText | ConvertFrom-Json
            $loggedIn = $false
            if ($auth.PSObject.Properties.Name -contains 'data') {
                if ($auth.data -and ($auth.data.PSObject.Properties.Name -contains 'loggedIn')) {
                    $loggedIn = [bool]$auth.data.loggedIn
                }
            }
            elseif ($auth.PSObject.Properties.Name -contains 'loggedIn') {
                $loggedIn = [bool]$auth.loggedIn
            }
            if ($loggedIn) { Pass 'Dreamina authorization is available' }
            else { Warn 'Dreamina is not authorized yet; run .\scripts\login.ps1' }
        }
        catch { Warn 'Dreamina authorization status did not return valid JSON' }
    }
    else { Warn 'Dreamina authorization status is unavailable' }
}
elseif ($AllowMissingDreamina) { Warn 'dreamina-canvas was intentionally skipped' }
else { Fail 'dreamina-canvas is not available' }

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

$python = Resolve-Command @('py.exe', 'python.exe')
$qcScript = Join-Path $CodexHome 'skills\video-delivery-qc\scripts\video_qc.py'
if ($python -and (Test-Path $qcScript)) {
    if ($python.Name -ieq 'py.exe') { & $python.Source -3 $qcScript --help *> $null }
    else { & $python.Source $qcScript --help *> $null }
    if ($LASTEXITCODE -eq 0) { Pass 'video-delivery-qc Skill' } else { Fail 'video-delivery-qc could not be loaded' }
}
elseif (-not $python) { Fail 'Python 3 is not available for video-delivery-qc' }
else { Fail 'video-delivery-qc Skill is not installed' }

$canvasSkill = Join-Path $CodexHome 'skills\canvas-video-pipeline\SKILL.md'
if (Test-Path $canvasSkill) { Pass 'canvas-video-pipeline Skill' } else { Fail 'canvas-video-pipeline Skill is not installed' }

Write-Host "`n-- Optional local editing Skills --"
foreach ($skillName in @('footage-sifter', 'caption-doctor', 'subtitle-translator', 'beat-cut-editor')) {
    $skillFile = Join-Path $CodexHome "skills\$skillName\SKILL.md"
    if (Test-Path $skillFile) { Pass "$skillName Skill" }
    elseif ($skillName -eq 'beat-cut-editor') { Warn 'beat-cut-editor is not installed; run scripts\import-irene_stage2.ps1 with your local package path' }
    else { Warn "$skillName is not installed; run scripts\import-irene_skills.ps1 with your local package path" }
}
$irenePython = Join-Path $env:USERPROFILE '.irene\venv\Scripts\python.exe'
if (Test-Path $irenePython) {
    & $irenePython -c 'import opencc, jieba' *> $null
    if ($LASTEXITCODE -eq 0) { Pass 'Irene subtitle dependencies (opencc, jieba)' }
    else { Warn 'Irene Python environment exists but opencc or jieba is missing' }
}
$beatSkill = Join-Path $CodexHome 'skills\beat-cut-editor\SKILL.md'
if ((Test-Path $beatSkill) -and (Test-Path $irenePython)) {
    & $irenePython -c 'import static_ffmpeg, scenedetect, cv2, PIL, numpy' *> $null
    if ($LASTEXITCODE -eq 0) { Pass 'beat-cut core dependencies' }
    else { Warn 'beat-cut-editor is installed but one or more core Python dependencies are missing' }
}

Write-Host ''
if ($failures -gt 0) {
    Write-Host "Verification finished with $failures required failure(s)." -ForegroundColor Red
    exit 1
}
Write-Host 'Verification passed. Authorization warnings can be resolved with scripts\login.ps1.' -ForegroundColor Green
exit 0
