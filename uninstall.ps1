[CmdletBinding()]
param(
    [switch]$RestoreBackup,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

function Write-AtomicUtf8 {
    param([string]$Path, [string]$Content)
    $directory = Split-Path -Parent $Path
    $temporary = Join-Path $directory ('.codex-desktop-glm-uninstall-' + [guid]::NewGuid().ToString('N') + '.tmp')
    $utf8 = New-Object System.Text.UTF8Encoding -ArgumentList $false
    try {
        [System.IO.File]::WriteAllText($temporary, $Content, $utf8)
        Move-Item -LiteralPath $temporary -Destination $Path -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue }
    }
}

function Remove-ManagedBlocks {
    param([string[]]$Lines)
    $result = New-Object System.Collections.Generic.List[string]
    $skip = $false
    foreach ($line in $Lines) {
        if ($line -match '^\s*#\s*BEGIN codex-desktop-glm managed') { $skip = $true; continue }
        if ($skip -and $line -match '^\s*#\s*END codex-desktop-glm managed') { $skip = $false; continue }
        if (-not $skip) { $result.Add($line) }
    }
    return ,$result.ToArray()
}

function Remove-TomlSection {
    param([string[]]$Lines, [string]$SectionName)
    $result = New-Object System.Collections.Generic.List[string]
    $skip = $false
    foreach ($line in $Lines) {
        if ($line -match '^\s*\[([^\]]+)\]\s*$') {
            $skip = ($Matches[1] -eq $SectionName -or $Matches[1].StartsWith($SectionName + '.'))
            if (-not $skip) { $result.Add($line) }
            continue
        }
        if (-not $skip) { $result.Add($line) }
    }
    return ,$result.ToArray()
}

function Remove-RootKeys {
    param([string[]]$Lines)
    $result = New-Object System.Collections.Generic.List[string]
    $inTable = $false
    foreach ($line in $Lines) {
        if ($line -match '^\s*\[[^\]]+\]\s*$') { $inTable = $true }
        $remove = (-not $inTable -and $line -match '^\s*(model|model_provider|model_reasoning_effort|model_catalog_json)\s*=')
        if (-not $remove) { $result.Add($line) }
    }
    return ,$result.ToArray()
}

$codexHome = Join-Path $env:USERPROFILE '.codex'
$integrationHome = Join-Path $codexHome 'codex-desktop-glm'
$configPath = Join-Path $codexHome 'config.toml'
$statePath = Join-Path $integrationHome 'setup-state.json'

$running = @(Get-Process -Name ChatGPT, Codex -ErrorAction SilentlyContinue)
if ($running.Count -gt 0 -and -not $Force) {
    $closeApp = Read-Host 'Codex appears to be running. Close it before uninstall, or type Y to continue'
    if ($closeApp -notmatch '(?i)^y(es)?$') { throw 'Uninstall cancelled so the running Desktop app can be closed safely.' }
    Write-Warning 'Continuing while Codex is running; restart it after uninstall if it remains open.'
}

if (-not (Test-Path -LiteralPath $statePath) -and -not $Force) {
    $answer = Read-Host 'No setup state was found. Remove only clearly managed config blocks anyway? [y/N]'
    if ($answer -notmatch '(?i)^y(es)?$') { throw 'Uninstall cancelled.' }
}

$state = $null
if (Test-Path -LiteralPath $statePath) {
    try { $state = Get-Content -LiteralPath $statePath -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Write-Warning 'Setup state is invalid; continuing conservatively.' }
}

$backupPath = $null
if ($state -and $state.backup_path -and (Test-Path -LiteralPath ([string]$state.backup_path))) {
    $backupPath = [string]$state.backup_path
}

$restoreRequested = $RestoreBackup
if (-not $RestoreBackup -and $backupPath -and -not $Force) {
    $restoreChoice = Read-Host ('Restore the setup backup over current config.toml? [Y/n] ' + $backupPath)
    $restoreRequested = ($restoreChoice -notmatch '(?i)^n(o)?$')
}

$restored = $false
if ($restoreRequested -and $backupPath) {
    $confirm = 'Y'
    if (-not $Force) { $confirm = Read-Host ('Restore backup over current config? This replaces current config.toml. Backup: ' + $backupPath + ' [y/N]') }
    if ($Force -or $confirm -match '(?i)^y(es)?$') {
        if (Test-Path -LiteralPath $configPath) {
            $currentCopy = $configPath + '.before-uninstall-' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.bak'
            Copy-Item -LiteralPath $configPath -Destination $currentCopy
            Write-Host ('Current config preserved at ' + $currentCopy)
        }
        Copy-Item -LiteralPath $backupPath -Destination $configPath -Force
        Write-Host 'Original config backup restored.' -ForegroundColor Green
        $restored = $true
    }
    else {
        Write-Warning 'Backup restore skipped; managed settings will be removed from the current file.'
    }
}

if (-not $restored -and (Test-Path -LiteralPath $configPath)) {
    $current = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
    $lines = $current -split "`r?`n"
    $lines = Remove-ManagedBlocks -Lines $lines
    $lines = Remove-TomlSection -Lines $lines -SectionName 'model_providers.ZAI'
    Write-AtomicUtf8 -Path $configPath -Content (($lines -join "`r`n").TrimEnd() + "`r`n")
    Write-Host 'Managed Z.ai settings removed from config.toml.' -ForegroundColor Green
}

if ($state -and $state.managed_environment -eq $true) {
    $currentUserKey = [Environment]::GetEnvironmentVariable('ZAI_API_KEY', 'User')
    $sameKey = $false
    if ($currentUserKey -and $state.key_sha256) {
        $sha = [System.Security.Cryptography.SHA256]::Create()
        try {
            $actualHash = ([System.BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($currentUserKey)))).Replace('-', '').ToLowerInvariant()
            $sameKey = ($actualHash -eq [string]$state.key_sha256)
        }
        finally { $sha.Dispose() }
    }
    if ($sameKey -or $Force) {
        [Environment]::SetEnvironmentVariable('ZAI_API_KEY', $null, 'User')
        if ($env:ZAI_API_KEY) { Remove-Item Env:\ZAI_API_KEY -ErrorAction SilentlyContinue }
        Write-Host 'The user-level ZAI_API_KEY created by setup was removed.'
    }
    else {
        Write-Warning 'ZAI_API_KEY was changed after setup; it was preserved.'
    }
}

if (Test-Path -LiteralPath $integrationHome) {
    Remove-Item -LiteralPath $integrationHome -Recurse -Force
    Write-Host ('Removed generated integration files: ' + $integrationHome)
}

Write-Host ''
Write-Host 'Uninstall completed. Codex Desktop, user projects, chats, history, and SQLite state were not removed.' -ForegroundColor Green
if ($backupPath) { Write-Host ('Original config backup remains at: ' + $backupPath) }
