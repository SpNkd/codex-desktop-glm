#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
user_home="${HOME:?HOME is not set}"
codex_config_home="${CODEX_HOME:-$user_home/.codex}"
integration_home="$codex_config_home/codex-desktop-glm"
config_path="$codex_config_home/config.toml"
catalog_path="$integration_home/models.json"
key_path="$integration_home/zai-api-key"

printf '%s\n' 'Codex Desktop + GLM diagnostic report'
printf 'Generated: %s\n' "$(date -Iseconds 2>/dev/null || date)"
printf 'Platform: %s\n' "$(uname -a)"
printf 'Config path: %s\n' "$config_path"
printf 'Catalog path: %s\n' "$catalog_path"

if command -v codex >/dev/null 2>&1; then
    printf 'Codex runtime: %s [%s]\n' "$(codex --version 2>/dev/null || printf 'version failed')" "$(command -v codex)"
else
    printf '%s\n' 'Codex runtime: not found on PATH'
fi

if [ -f "$config_path" ]; then
    printf 'Provider: '; grep -E '^[[:space:]]*model_provider[[:space:]]*=' "$config_path" | head -1 || printf '<not set>\n'
    printf 'Model: '; grep -E '^[[:space:]]*model[[:space:]]*=' "$config_path" | head -1 || printf '<not set>\n'
    printf 'Wire API: '; grep -E '^[[:space:]]*wire_api[[:space:]]*=' "$config_path" | tail -1 || printf '<not set>\n'
    printf 'Catalog setting: '; grep -E '^[[:space:]]*model_catalog_json[[:space:]]*=' "$config_path" | head -1 || printf '<not set>\n'
    printf 'Z.ai base URL: '; grep -E '^[[:space:]]*base_url[[:space:]]*=' "$config_path" | tail -1 || printf '<not set>\n'
    printf 'Secret source: '; grep -E '^[[:space:]]*env_key[[:space:]]*=' "$config_path" | tail -1 || printf '<not set>\n'
else
    printf '%s\n' 'Config status: missing'
fi

python_bin='python3'
command -v "$python_bin" >/dev/null 2>&1 || python_bin='python'
if [ -f "$catalog_path" ] && "$python_bin" -m json.tool "$catalog_path" >/dev/null 2>&1; then
    printf '%s\n' 'Catalog status: valid JSON'
else
    printf '%s\n' 'Catalog status: missing or invalid'
fi

if [ -n "${ZAI_API_KEY:-}" ] || [ -s "$key_path" ]; then printf '%s\n' 'ZAI_API_KEY: present (value redacted)'; else printf '%s\n' 'ZAI_API_KEY: absent'; fi
printf '%s\n' ''
printf '%s\n' 'Feature status'
printf '%s\n' 'Selected inference: Z.ai Responses; no configured OpenAI fallback'
printf '%s\n' 'OpenAI/ChatGPT auxiliary traffic: not audited by this script'
printf '%s\n' 'Adapter: not installed (direct mode)'
printf '%s\n' 'Computer Use: UNVERIFIED / likely limited for API-key-only custom provider'
printf '%s\n' 'Browser Use: LIMITED/FAIL in API-key-only mode; see research'
if [ -f "$config_path" ] && grep -Eq '^[[:space:]]*\[mcp_servers\.' "$config_path"; then printf '%s\n' 'MCP: configured; GUI invocation unverified'; else printf '%s\n' 'MCP: not configured; local runtime feature'; fi
if [ -d "$codex_config_home/skills" ] || [ -d "$script_dir/tests/skills" ]; then printf '%s\n' 'Skills: local skill directory found; GUI invocation unverified'; else printf '%s\n' 'Skills: no checked skill directory'; fi
printf '%s\n' 'Projects/chats/SQLite: read-only and not modified by this bundle'
printf '%s\n' 'Run ./test.sh --connectivity-only for a live provider check.'
