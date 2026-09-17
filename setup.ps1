[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$SkipConnectivity
)

$ErrorActionPreference = 'Stop'

function Write-AtomicUtf8 {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $directory = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    $temporary = Join-Path $directory ('.codex-desktop-glm-' + [guid]::NewGuid().ToString('N') + '.tmp')
    $utf8 = New-Object System.Text.UTF8Encoding -ArgumentList $false
    try {
        [System.IO.File]::WriteAllText($temporary, $Content, $utf8)
        Move-Item -LiteralPath $temporary -Destination $Path -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporary) {
            Remove-Item -LiteralPath $temporary -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-KeyHash {
    param([Parameter(Mandatory = $true)][string]$Value)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Value)
        return ([System.BitConverter]::ToString($sha.ComputeHash($bytes))).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Read-SecretText {
    $secure = Read-Host 'Enter Z.ai Coding Plan API key (input is hidden)' -AsSecureString
    $pointer = [IntPtr]::Zero
    try {
        $pointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    }
    finally {
        if ($pointer -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer)
        }
    }
}

function Remove-ManagedBlocks {
    param([string[]]$Lines)
    $result = New-Object System.Collections.Generic.List[string]
    $skip = $false
    foreach ($line in $Lines) {
        if ($line -match '^\s*#\s*BEGIN codex-desktop-glm managed') {
            $skip = $true
            continue
        }
        if ($skip -and $line -match '^\s*#\s*END codex-desktop-glm managed') {
            $skip = $false
            continue
        }
        if (-not $skip) {
            $result.Add($line)
        }
    }
    return ,$result.ToArray()
}

function Remove-TomlSection {
    param(
        [string[]]$Lines,
        [string]$SectionName
    )
    $result = New-Object System.Collections.Generic.List[string]
    $skip = $false
    foreach ($line in $Lines) {
        if ($line -match '^\s*\[([^\]]+)\]\s*$') {
            $current = $Matches[1]
            $skip = ($current -eq $SectionName -or $current.StartsWith($SectionName + '.'))
            if (-not $skip) {
                $result.Add($line)
            }
            continue
        }
        if (-not $skip) {
            $result.Add($line)
        }
    }
    return ,$result.ToArray()
}

function Remove-RootKeys {
    param(
        [string[]]$Lines,
        [string[]]$Keys
    )
    $result = New-Object System.Collections.Generic.List[string]
    $inTable = $false
    foreach ($line in $Lines) {
        if ($line -match '^\s*\[[^\]]+\]\s*$') {
            $inTable = $true
        }
        $remove = $false
        if (-not $inTable -and $line -notmatch '^\s*#') {
            foreach ($key in $Keys) {
                if ($line -match ('^\s*' + [regex]::Escape($key) + '\s*=')) {
                    $remove = $true
                    break
                }
            }
        }
        if (-not $remove) {
            $result.Add($line)
        }
    }
    return ,$result.ToArray()
}

function Add-ManagedConfig {
    param([string]$ExistingText)

    $lines = $ExistingText -split "`r?`n"
    $lines = Remove-ManagedBlocks -Lines $lines
    $lines = Remove-TomlSection -Lines $lines -SectionName 'model_providers.ZAI'
    $lines = Remove-RootKeys -Lines $lines -Keys @('model', 'model_provider', 'model_reasoning_effort', 'model_catalog_json')

    $rootBlock = @(
        '# BEGIN codex-desktop-glm managed settings',
        'model = "glm-5.3"',
        'model_provider = "ZAI"',
        'model_reasoning_effort = "max"',
        'model_catalog_json = "__CATALOG_PATH__"',
        '# END codex-desktop-glm managed settings'
    )
    $providerBlock = @(
        '',
        '# BEGIN codex-desktop-glm managed provider',
        '[model_providers.ZAI]',
        'name = "Z.ai GLM Coding Plan"',
        'base_url = "https://api.z.ai/api/v1"',
        'env_key = "ZAI_API_KEY"',
        'wire_api = "responses"',
        'supports_websockets = false',
        '# END codex-desktop-glm managed provider'
    )

    $result = New-Object System.Collections.Generic.List[string]
    $firstTable = $lines.Count
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($lines[$index] -match '^\s*\[[^\]]+\]\s*$') {
            $firstTable = $index
            break
        }
    }
    for ($index = 0; $index -lt $lines.Count; $index++) {
        if ($index -eq $firstTable) {
            foreach ($blockLine in $rootBlock) { $result.Add($blockLine) }
            $result.Add('')
        }
        $result.Add($lines[$index])
    }
    if ($firstTable -eq $lines.Count) {
        foreach ($blockLine in $rootBlock) { $result.Add($blockLine) }
    }
    foreach ($blockLine in $providerBlock) { $result.Add($blockLine) }
    return ($result.ToArray() -join "`r`n").TrimEnd() + "`r`n"
}

function Test-ZaiConnectivity {
    param([Parameter(Mandatory = $true)][string]$ApiKey)
    $uri = 'https://api.z.ai/api/v1/responses'
    $payload = @{
        model = 'glm-5.3'
        input = 'Reply with exactly: ZAI_CODEX_OK'
        stream = $false
    } | ConvertTo-Json -Compress
    try {
        $response = Invoke-RestMethod -Method Post -Uri $uri -Headers @{ Authorization = 'Bearer ' + $ApiKey } -ContentType 'application/json' -Body $payload -TimeoutSec 60
        if ($null -eq $response) {
            Write-Warning 'Z.ai returned an empty response.'
            return $false
        }
        Write-Host 'Z.ai connectivity: OK (HTTP request completed; response content was not logged).' -ForegroundColor Green
        return $true
    }
    catch {
        $status = ''
        if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
            $status = ' HTTP ' + [int]$_.Exception.Response.StatusCode
        }
        Write-Warning ('Z.ai connectivity: FAILED' + $status + '. Check the key, Coding Plan entitlement, endpoint, and network policy.')
        return $false
    }
}

if ($env:OS -ne 'Windows_NT') {
    throw 'setup.ps1 must run on Windows PowerShell or PowerShell on Windows.'
}

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$codexHome = Join-Path $env:USERPROFILE '.codex'
$integrationHome = Join-Path $codexHome 'codex-desktop-glm'
$configPath = Join-Path $codexHome 'config.toml'
$catalogPath = Join-Path $integrationHome 'models.json'
$statePath = Join-Path $integrationHome 'setup-state.json'

$packages = @()
try {
    $packages = @(Get-AppxPackage -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'Codex|ChatGPT' } | Sort-Object Version -Descending)
}
catch {
    $packages = @()
}
if ($packages.Count -gt 0) {
    $package = $packages[0]
    Write-Host ('Detected Desktop package: ' + $package.Name + ' ' + $package.Version)
    $runtimeCandidates = New-Object System.Collections.Generic.List[string]
    foreach ($relative in @('codex.exe', 'resources\codex.exe', 'resources\app\codex.exe', 'LocalCache\Local\OpenAI\Codex\bin\codex.exe', 'LocalCache\Local\OpenAI\Codex\bin\app-server.exe')) {
        foreach ($basePath in @($package.InstallLocation, (Join-Path $env:LOCALAPPDATA ('Packages\' + $package.Name)))) {
            $candidate = Join-Path $basePath $relative
            if (Test-Path -LiteralPath $candidate) { $runtimeCandidates.Add($candidate) }
        }
    }
    if ($runtimeCandidates.Count -gt 0) {
        Write-Host ('Bundled runtime candidate(s): ' + ($runtimeCandidates -join '; '))
    }
    else {
        Write-Host 'Bundled runtime: not found by safe package-path scan (Desktop may use a protected/managed path).'
    }
}
else {
    Write-Warning 'Codex Desktop/ChatGPT Desktop package was not detected for the current user.'
    Write-Host 'Official install: winget install --id 9PLM9XGG6VKS -s msstore'
    Write-Host 'Install the app, then rerun this script. Configuration can still be prepared, but GUI testing requires the app.'
}

$codexCommand = Get-Command codex -ErrorAction SilentlyContinue
if ($codexCommand) {
    Write-Host ('Codex command detected: ' + $codexCommand.Source)
}

$running = @(Get-Process -Name ChatGPT, Codex -ErrorAction SilentlyContinue)
if ($running.Count -gt 0 -and -not $Force) {
    $continue = Read-Host 'Codex appears to be running. Close it before setup, or type Y to continue'
    if ($continue -notmatch '(?i)^y(es)?$') {
        throw 'Setup cancelled so the running Desktop app can be closed safely.'
    }
    Write-Warning 'Continuing while Codex is running; restart it after setup.'
}

$existingUserKey = [Environment]::GetEnvironmentVariable('ZAI_API_KEY', 'User')
$apiKey = $null
$managedEnvironment = $false
if ($existingUserKey) {
    $reuse = Read-Host 'A user-level ZAI_API_KEY already exists. Reuse it? [Y/n]'
    if ($reuse -notmatch '(?i)^n(o)?$') {
        $apiKey = $existingUserKey
    }
}
if (-not $apiKey) {
    $apiKey = Read-SecretText
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        throw 'An API key is required.'
    }
    [Environment]::SetEnvironmentVariable('ZAI_API_KEY', $apiKey, 'User')
    $env:ZAI_API_KEY = $apiKey
    $managedEnvironment = $true
}
else {
    $env:ZAI_API_KEY = $apiKey
}

$exampleCatalog = Join-Path $repoRoot 'config\models.json.example'
if (-not (Test-Path -LiteralPath $exampleCatalog)) {
    throw ('Missing catalog template: ' + $exampleCatalog)
}
$catalogJson = Get-Content -LiteralPath $exampleCatalog -Raw -Encoding UTF8 | ConvertFrom-Json
if (-not $catalogJson.models -or $catalogJson.models[0].slug -ne 'glm-5.3') {
    throw 'The bundled model catalog does not contain the expected glm-5.3 entry.'
}
Write-AtomicUtf8 -Path $catalogPath -Content (Get-Content -LiteralPath $exampleCatalog -Raw -Encoding UTF8)

$backupPath = $null
if (Test-Path -LiteralPath $configPath) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $backupPath = Join-Path $codexHome ('config.toml.codex-desktop-glm-backup-' + $stamp + '.bak')
    $suffix = 0
    while (Test-Path -LiteralPath $backupPath) {
        $suffix++
        $backupPath = Join-Path $codexHome ('config.toml.codex-desktop-glm-backup-' + $stamp + '-' + $suffix + '.bak')
    }
    Copy-Item -LiteralPath $configPath -Destination $backupPath
    $existingConfig = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
}
else {
    $existingConfig = ''
}

$catalogTomlPath = $catalogPath.Replace('\', '/')
$newConfig = Add-ManagedConfig -ExistingText $existingConfig
$newConfig = $newConfig.Replace('__CATALOG_PATH__', $catalogTomlPath)
Write-AtomicUtf8 -Path $configPath -Content $newConfig

$state = [ordered]@{
    schema_version = 1
    setup_utc = (Get-Date).ToUniversalTime().ToString('o')
    config_path = $configPath
    catalog_path = $catalogPath
    backup_path = $backupPath
    managed_environment = $managedEnvironment
    environment_variable = 'ZAI_API_KEY'
    key_sha256 = Get-KeyHash -Value $apiKey
    adapter = $false
}
Write-AtomicUtf8 -Path $statePath -Content ($state | ConvertTo-Json -Depth 4)

$connectivityOk = $true
if (-not $SkipConnectivity) {
    $connectivityOk = Test-ZaiConnectivity -ApiKey $apiKey
}
else {
    Write-Host 'Connectivity check skipped by -SkipConnectivity.'
}

Write-Host ''
Write-Host 'Setup completed.' -ForegroundColor Green
Write-Host ('Config:  ' + $configPath)
Write-Host ('Catalog: ' + $catalogPath)
if ($backupPath) { Write-Host ('Backup:  ' + $backupPath) }
Write-Host 'Restart Codex Desktop before creating a new task.'
Write-Host 'No adapter, startup task, app-bundle patch, project deletion, or OpenAI login was added.'
if (-not $connectivityOk) {
    Write-Warning 'Configuration was written, but live Z.ai connectivity was not verified.'
}
