[CmdletBinding()]
param(
    [switch]$ConnectivityOnly,
    [switch]$StaticOnly,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$failures = 0

function Say {
    param([string]$Message, [ConsoleColor]$Color = [ConsoleColor]::Gray)
    if (-not $Quiet) { Write-Host $Message -ForegroundColor $Color }
}

function Check {
    param([bool]$Condition, [string]$Name, [string]$Detail)
    if ($Condition) {
        Say ('[OK]   ' + $Name + ' - ' + $Detail) Green
    }
    else {
        $script:failures++
        Say ('[FAIL] ' + $Name + ' - ' + $Detail) Red
    }
}

function Get-QuotedConfigValue {
    param([string]$Text, [string]$Key)
    $match = [regex]::Match($Text, '(?m)^\s*' + [regex]::Escape($Key) + '\s*=\s*["'']([^"'']+)["'']')
    if ($match.Success) { return $match.Groups[1].Value }
    return $null
}

function Invoke-ZaiSmoke {
    param([string]$ApiKey)
    $payload = @{
        model = 'glm-5.3'
        input = 'Reply with exactly: ZAI_CODEX_OK'
        stream = $false
    } | ConvertTo-Json -Compress
    try {
        $response = Invoke-RestMethod -Method Post -Uri 'https://api.z.ai/api/v1/responses' -Headers @{ Authorization = 'Bearer ' + $ApiKey } -ContentType 'application/json' -Body $payload -TimeoutSec 60
        return ($null -ne $response)
    }
    catch {
        if (-not $Quiet) {
            $status = ''
            if ($_.Exception.Response -and $_.Exception.Response.StatusCode) { $status = ' HTTP ' + [int]$_.Exception.Response.StatusCode }
            Say ('Z.ai request failed' + $status + ': ' + $_.Exception.Message) Red
        }
        return $false
    }
}

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$codexHome = Join-Path $env:USERPROFILE '.codex'
$configPath = Join-Path $codexHome 'config.toml'
$catalogPath = Join-Path (Join-Path $codexHome 'codex-desktop-glm') 'models.json'

if (-not $ConnectivityOnly) {
    Say 'Codex Desktop + GLM static checks' Cyan
    Check ($env:OS -eq 'Windows_NT') 'Windows' 'target is Windows'
    Check (Test-Path -LiteralPath $configPath) 'Codex config' $configPath
    Check (Test-Path -LiteralPath $catalogPath) 'Model catalog' $catalogPath

    if (Test-Path -LiteralPath $configPath) {
        $config = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8
        $provider = Get-QuotedConfigValue -Text $config -Key 'model_provider'
        $model = Get-QuotedConfigValue -Text $config -Key 'model'
        $wire = Get-QuotedConfigValue -Text $config -Key 'wire_api'
        $baseUrl = Get-QuotedConfigValue -Text $config -Key 'base_url'
        $envKey = Get-QuotedConfigValue -Text $config -Key 'env_key'
        Check ($provider -eq 'ZAI') 'Selected provider' ('model_provider=' + [string]$provider)
        Check ($model -eq 'glm-5.3') 'Selected model' ('model=' + [string]$model)
        Check ($wire -eq 'responses') 'Wire protocol' ('wire_api=' + [string]$wire)
        Check ($baseUrl -eq 'https://api.z.ai/api/v1') 'Z.ai base URL' ([string]$baseUrl)
        Check ($envKey -eq 'ZAI_API_KEY') 'Secret source' 'env_key=ZAI_API_KEY; key is not read from the file'
        Check ($config -notmatch '(?i)(sk-[A-Za-z0-9]|api[_-]?key\s*=\s*["''])') 'No obvious secret in config' 'no key literal detected'
        Check ($config -notmatch '(?m)^\s*wire_api\s*=\s*["'']chat["'']') 'No removed Chat wire mode' 'chat wire mode is not configured'
    }

    if (Test-Path -LiteralPath $catalogPath) {
        try {
            $catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding UTF8 | ConvertFrom-Json
            $modelEntry = @($catalog.models | Where-Object { $_.slug -eq 'glm-5.3' })
            Check ($modelEntry.Count -eq 1) 'Catalog model' 'exactly one glm-5.3 entry'
            if ($modelEntry.Count -eq 1) {
                Check ($modelEntry[0].context_window -eq 1048576) 'Catalog context' '1,048,576 tokens'
                Check ($modelEntry[0].input_modalities -contains 'text') 'Catalog modality' 'text input declared'
            }
        }
        catch {
            Check $false 'Catalog JSON' $_.Exception.Message
        }
    }

    $adapterPath = Join-Path $scriptRoot 'adapter'
    Check (-not (Test-Path -LiteralPath $adapterPath)) 'Adapter decision' 'adapter directory absent; direct mode is selected'
}

if (-not $StaticOnly) {
    $apiKey = [Environment]::GetEnvironmentVariable('ZAI_API_KEY', 'Process')
    if (-not $apiKey) { $apiKey = [Environment]::GetEnvironmentVariable('ZAI_API_KEY', 'User') }
    Check (-not [string]::IsNullOrWhiteSpace($apiKey)) 'Z.ai API key' 'present without displaying it'
    if ($apiKey) {
        Check (Invoke-ZaiSmoke -ApiKey $apiKey) 'Z.ai Responses connectivity' 'HTTP request completed'
    }
}

if ($ConnectivityOnly) {
    Say 'Connectivity-only test complete.' Cyan
}
elseif ($StaticOnly) {
    Say 'Static-only test complete; live inference and GUI behavior were not tested.' Cyan
}
else {
    Say ''
    Say 'Interactive Desktop tests are not automatable from this script.' Yellow
    Say 'Run the file, calculator agent-loop, AGENTS.md, skill, MCP, persistence, Computer Use, and Browser checks in README.md.' Yellow
}

if ($failures -gt 0) {
    Say ($failures.ToString() + ' check(s) failed.') Red
    exit 1
}
Say 'All executed checks passed. This does not certify unexecuted Desktop GUI features.' Green
exit 0
