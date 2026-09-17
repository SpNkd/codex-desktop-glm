[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

function Get-QuotedConfigValue {
    param([string]$Text, [string]$Key)
    $match = [regex]::Match($Text, '(?m)^\s*' + [regex]::Escape($Key) + '\s*=\s*["'']([^"'']+)["'']')
    if ($match.Success) { return $match.Groups[1].Value }
    return '<not set>'
}

function Print-Item {
    param([string]$Name, [string]$Value)
    Write-Host ($Name.PadRight(31) + $Value)
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$codexHome = Join-Path $env:USERPROFILE '.codex'
$configPath = Join-Path $codexHome 'config.toml'
$catalogPath = Join-Path (Join-Path $codexHome 'codex-desktop-glm') 'models.json'

Write-Host 'Codex Desktop + GLM diagnostic report' -ForegroundColor Cyan
Write-Host ('Generated: ' + (Get-Date).ToString('s'))
Write-Host ''

try {
    $os = Get-CimInstance Win32_OperatingSystem
    Print-Item 'Windows' ($os.Caption + ' ' + $os.Version + ' (' + $os.OSArchitecture + ')')
}
catch {
    Print-Item 'Windows' 'could not read OS information'
}

try {
    $packages = @(Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Codex|ChatGPT' } | Sort-Object Version -Descending)
    if ($packages.Count -gt 0) {
        Print-Item 'Codex Desktop package' ($packages[0].Name + ' ' + $packages[0].Version)
        Print-Item 'Package location' $packages[0].InstallLocation
    }
    else {
        Print-Item 'Codex Desktop package' 'not detected for current user'
    }
}
catch {
    Print-Item 'Codex Desktop package' 'Get-AppxPackage unavailable/failed'
}

$codex = Get-Command codex -ErrorAction SilentlyContinue
if ($codex) {
    try { $version = ((& $codex.Source --version 2>&1) -join ' ') } catch { $version = 'version command failed' }
    Print-Item 'Codex runtime on PATH' ($version + ' [' + $codex.Source + ']')
}
else {
    Print-Item 'Codex runtime on PATH' 'not found; Desktop may use a bundled runtime'
}

$candidateRuntimes = New-Object System.Collections.Generic.List[string]
$packageRoot = Join-Path $env:LOCALAPPDATA 'Packages'
if (Test-Path -LiteralPath $packageRoot) {
    Get-ChildItem -LiteralPath $packageRoot -Directory -Filter 'OpenAI.Codex_*' -ErrorAction SilentlyContinue | ForEach-Object {
        foreach ($relative in @('LocalCache\Local\OpenAI\Codex\bin\codex.exe', 'LocalCache\Local\OpenAI\Codex\bin\app-server.exe', 'LocalCache\Local\OpenAI\Codex\current\codex.exe')) {
            $candidate = Join-Path $_.FullName $relative
            if (Test-Path -LiteralPath $candidate) { $candidateRuntimes.Add($candidate) }
        }
    }
}
if ($candidateRuntimes.Count -gt 0) {
    Print-Item 'Bundled runtime candidates' ($candidateRuntimes -join '; ')
}
else {
    Print-Item 'Bundled runtime candidates' 'not found by safe path scan'
}

Print-Item 'Config path' $configPath
if (Test-Path -LiteralPath $configPath) {
    $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
    Print-Item 'Provider' (Get-QuotedConfigValue -Text $config -Key 'model_provider')
    Print-Item 'Model' (Get-QuotedConfigValue -Text $config -Key 'model')
    Print-Item 'Wire API' (Get-QuotedConfigValue -Text $config -Key 'wire_api')
    Print-Item 'Catalog setting' (Get-QuotedConfigValue -Text $config -Key 'model_catalog_json')
    Print-Item 'Z.ai base URL' (Get-QuotedConfigValue -Text $config -Key 'base_url')
    Print-Item 'Secret source' (Get-QuotedConfigValue -Text $config -Key 'env_key')
}
else {
    Print-Item 'Config status' 'missing'
}
Print-Item 'Catalog path' $catalogPath
if (Test-Path -LiteralPath $catalogPath) {
    try {
        $catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
        Print-Item 'Catalog status' ('valid; ' + $catalog.models.Count + ' model(s)')
    }
    catch { Print-Item 'Catalog status' 'invalid JSON' }
}
else {
    Print-Item 'Catalog status' 'missing'
}

$userKey = [Environment]::GetEnvironmentVariable('ZAI_API_KEY', 'User')
$processKey = [Environment]::GetEnvironmentVariable('ZAI_API_KEY', 'Process')
if ($userKey -or $processKey) {
    Print-Item 'ZAI_API_KEY' 'present (value redacted)'
}
else {
    Print-Item 'ZAI_API_KEY' 'absent'
}

Write-Host ''
Write-Host 'Runtime feature status' -ForegroundColor Cyan
Print-Item 'Selected inference route' 'Z.ai Responses; no configured OpenAI fallback'
Print-Item 'OpenAI/ChatGPT auxiliary traffic' 'not audited by this script'
Print-Item 'Adapter' 'not installed (direct mode)'
Print-Item 'Adapter port/health' 'not applicable'
Print-Item 'Computer Use' 'UNVERIFIED; likely limited for API-key-only custom provider'
Print-Item 'Browser Use' 'LIMITED/FAIL in API-key-only mode; see research'

$mcpConfigured = $false
if (Test-Path -LiteralPath $configPath) {
    $mcpConfigured = $config -match '(?m)^\s*\[mcp_servers\.'
}
Print-Item 'MCP' ($(if ($mcpConfigured) { 'configured in config; GUI call unverified' } else { 'not configured; feature supported by local runtime' }))

$skillDirs = @()
foreach ($skillRoot in @((Join-Path $codexHome 'skills'), (Join-Path $scriptRoot 'tests\skills'))) {
    if (Test-Path -LiteralPath $skillRoot) {
        $skillDirs += @(Get-ChildItem -LiteralPath $skillRoot -Directory -ErrorAction SilentlyContinue)
    }
}
Print-Item 'Skills' ($(if ($skillDirs.Count -gt 0) { 'local skill directories found; GUI invocation unverified' } else { 'none found in checked paths' }))

Write-Host ''
Write-Host 'Persistence locations (read-only)' -ForegroundColor Cyan
$stateFiles = @()
foreach ($stateRoot in @($codexHome, (Join-Path $codexHome 'sqlite'))) {
    if (Test-Path -LiteralPath $stateRoot) {
        $stateFiles += @(Get-ChildItem -LiteralPath $stateRoot -File -Filter 'state_*.sqlite' -ErrorAction SilentlyContinue)
    }
}
if ($stateFiles.Count -gt 0) {
    foreach ($file in $stateFiles) { Print-Item 'SQLite state' ($file.FullName + ' (' + $file.Length + ' bytes)') }
}
else {
    Print-Item 'SQLite state' 'not found in common locations'
}
Print-Item 'Uninstall safety' 'does not delete Desktop, projects, chats, or SQLite state'

Write-Host ''
Write-Host 'For a live provider check, run .\test.ps1 -ConnectivityOnly. The command reports only presence/absence of the key and never prints it.' -ForegroundColor Yellow
