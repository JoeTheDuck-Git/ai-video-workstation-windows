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

$hyperframes = Get-Command hyperframes.cmd -ErrorAction SilentlyContinue
if (-not $hyperframes) {
    throw 'hyperframes is not installed. Run install.cmd first.'
}
Write-Host 'Starting optional HyperFrames / HeyGen authorization...' -ForegroundColor Cyan
Invoke-Checked $hyperframes.Source @('auth', 'login')
Invoke-Checked $hyperframes.Source @('auth', 'status', '--json')

Write-Host "`nAuthorization completed. No credentials were copied into this folder." -ForegroundColor Green
