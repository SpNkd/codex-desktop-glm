[CmdletBinding()]
param(
    [switch]$ConnectivityOnly
)

$ErrorActionPreference = 'Stop'

function Get-ConfigValue {
    param([string]$Text, [string]$Key)
    $match = [regex]::Match($Text, '(?m)^\s*' + [regex]::Escape($Key) + '\s*=\s*["'']([^"'']+)["'']')
    if ($match.Success) { return $match.Groups[1].Value }
    return $null
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$codexHome = Join-Path $env:USERPROFILE '.codex'
$configPath = Join-Path $codexHome 'config.toml'
$catalogPath = Join-Path (Join-Path $codexHome 'codex-desktop-glm') 'models.json'

if ($ConnectivityOnly) {
    & (Join-Path $scriptRoot 'test.ps1') -ConnectivityOnly
    exit $LASTEXITCODE
}

Write-Host 'Codex Desktop + GLM configuration update check'
Write-Host ('Checked: ' + (Get-Date).ToString('s'))

try {
    $packages = @(Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Codex|ChatGPT' } | Sort-Object Version -Descending)
    if ($packages.Count -gt 0) {
        Write-Host ('Desktop package: ' + $packages[0].Name + ' ' + $packages[0].Version)
    }
    else {
        Write-Warning 'Desktop package was not detected for the current user.'
    }
}
catch {
    Write-Warning 'Could not inspect AppX package versions.'
}

$codex = Get-Command codex -ErrorAction SilentlyContinue
if ($codex) {
    try {
        Write-Host ('Codex runtime: ' + ((& $codex.Source --version 2>&1) -join ' '))
    }
    catch {
        Write-Warning 'Codex command was found but its version could not be read.'
    }
}
else {
    Write-Host 'Codex command: not on PATH (Desktop may still contain a bundled runtime).'
}

if (-not (Test-Path -LiteralPath $configPath)) {
    Write-Warning ('Config is missing: ' + $configPath)
}
else {
    $text = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
    Write-Host ('Provider: ' + (Get-ConfigValue -Text $text -Key 'model_provider'))
    Write-Host ('Model: ' + (Get-ConfigValue -Text $text -Key 'model'))
    Write-Host ('Wire API: ' + (Get-ConfigValue -Text $text -Key 'wire_api'))
    Write-Host ('Catalog setting: ' + (Get-ConfigValue -Text $text -Key 'model_catalog_json'))
}

if (Test-Path -LiteralPath $catalogPath) {
    try {
        $catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Write-Host ('Catalog: valid (' + $catalog.models.Count + ' model(s))')
    }
    catch {
        Write-Warning 'Catalog exists but is not valid JSON.'
    }
}
else {
    Write-Warning ('Catalog is missing: ' + $catalogPath)
}

Write-Host ''
Write-Host 'No automatic Desktop package upgrade is performed. Use the Microsoft Store/winget to update the app.'
Write-Host 'The current public Desktop bundle version is intentionally read from the target machine, because Store rollout versions are not reliably exposed by the open-source repository.'
Write-Host 'Run .\test.ps1 and .\diagnose.ps1 after any app update.'
& (Join-Path $scriptRoot 'test.ps1') -StaticOnly
exit $LASTEXITCODE
