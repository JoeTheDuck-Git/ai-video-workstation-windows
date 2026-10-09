[CmdletBinding()]
param([switch]$WithHyperFrames)

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

$dreamina = Get-Command dreamina-canvas.exe -ErrorAction SilentlyContinue
if (-not $dreamina) {
    $dreamina = Get-Command dreamina-canvas.cmd -ErrorAction SilentlyContinue
}
if (-not $dreamina) {
    throw 'dreamina-canvas is not installed. Run install.cmd first.'
}

Write-Host 'Starting Dreamina Canvas browser authorization...' -ForegroundColor Cyan
Invoke-Checked $dreamina.Source @('auth', 'login')
Invoke-Checked $dreamina.Source @('auth', 'status', '--format', 'json')
Invoke-Checked $dreamina.Source @('auth', 'account', '--format', 'json')

if ($WithHyperFrames) {
    $hyperframes = Get-Command hyperframes.cmd -ErrorAction SilentlyContinue
    if (-not $hyperframes) {
        throw 'hyperframes is not installed. Run install.cmd first.'
    }
    Write-Host "`nStarting HyperFrames / HeyGen authorization..." -ForegroundColor Cyan
    Invoke-Checked $hyperframes.Source @('auth', 'login')
    Invoke-Checked $hyperframes.Source @('auth', 'status', '--json')
}

Write-Host "`nAuthorization completed. No credentials were copied into this folder." -ForegroundColor Green
