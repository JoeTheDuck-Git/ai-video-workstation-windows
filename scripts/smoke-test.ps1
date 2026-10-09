[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$StateDir = Join-Path $env:LOCALAPPDATA 'AI-Video-Workstation'
$paths = @(
    (Join-Path $StateDir 'node22-current'),
    (Join-Path $StateDir 'bin'),
    (Join-Path $StateDir 'npm'),
    [Environment]::GetEnvironmentVariable('Path', 'Machine'),
    [Environment]::GetEnvironmentVariable('Path', 'User')
) | Where-Object { $_ }
$env:Path = $paths -join ';'

function Invoke-Checked([string]$FilePath, [string[]]$Arguments) {
    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "$FilePath failed with exit code $LASTEXITCODE."
    }
}

$canvasVideo = (Get-Command canvas-video.cmd -ErrorAction Stop).Source
$ffprobe = (Get-Command ffprobe.exe -ErrorAction Stop).Source
$smokeRoot = Join-Path ([IO.Path]::GetTempPath()) ("canvas-video-smoke-" + [guid]::NewGuid().ToString('N'))
$project = Join-Path $smokeRoot 'portrait'
$video = Join-Path $project 'out\smoke.mp4'

try {
    Invoke-Checked $canvasVideo @('init', $project, '--aspect', 'portrait')
    Invoke-Checked $canvasVideo @('render', $project, '--still', '2.5')
    Invoke-Checked $canvasVideo @('render', $project, '--to', '0.2', '--output', $video)
    $probeText = (& $ffprobe -v error -select_streams 'v:0' -show_entries 'stream=codec_name,width,height,pix_fmt,r_frame_rate' -show_entries 'format=duration' -of json $video) -join "`n"
    if ($LASTEXITCODE -ne 0) { throw 'ffprobe failed during the render smoke test.' }
    $probe = $probeText | ConvertFrom-Json
    $stream = $probe.streams | Select-Object -First 1
    if (-not $stream -or $stream.codec_name -ne 'h264' -or $stream.width -ne 1080 -or $stream.height -ne 1920) {
        throw "Unexpected smoke-test output: $probeText"
    }
    Write-Host 'PASS  Native portrait render: H.264 1080x1920' -ForegroundColor Green
}
finally {
    if (Test-Path $smokeRoot) {
        Remove-Item -LiteralPath $smokeRoot -Recurse -Force
    }
}
