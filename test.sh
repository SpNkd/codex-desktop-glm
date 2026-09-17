#!/usr/bin/env bash
set -euo pipefail

connectivity_only=0
static_only=0
for argument in "$@"; do
    case "$argument" in
        --connectivity-only) connectivity_only=1 ;;
        --static-only) static_only=1 ;;
        -h|--help) printf '%s\n' 'Usage: ./test.sh [--connectivity-only|--static-only]'; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$argument" >&2; exit 2 ;;
    esac
done

user_home="${HOME:?HOME is not set}"
codex_config_home="${CODEX_HOME:-$user_home/.codex}"
integration_home="$codex_config_home/codex-desktop-glm"
config_path="$codex_config_home/config.toml"
catalog_path="$integration_home/models.json"
key_path="$integration_home/zai-api-key"
failures=0

if [ "$connectivity_only" -eq 0 ]; then
    if [ -f "$config_path" ]; then printf '[OK]   Codex config exists\n'; else printf '[FAIL] Codex config missing\n'; failures=$((failures + 1)); fi
    if [ -f "$catalog_path" ]; then printf '[OK]   Model catalog exists\n'; else printf '[FAIL] Model catalog missing\n'; failures=$((failures + 1)); fi
    if [ -f "$config_path" ]; then
        if grep -Eq "^[[:space:]]*model_provider[[:space:]]*=[[:space:]]*\"ZAI\"" "$config_path"; then printf '[OK]   Selected provider is ZAI\n'; else printf '[FAIL] Selected provider is not ZAI\n'; failures=$((failures + 1)); fi
        if grep -Eq "^[[:space:]]*model[[:space:]]*=[[:space:]]*\"glm-5\.3\"" "$config_path"; then printf '[OK]   Selected model is glm-5.3\n'; else printf '[FAIL] Selected model is not glm-5.3\n'; failures=$((failures + 1)); fi
        if grep -Eq "^[[:space:]]*wire_api[[:space:]]*=[[:space:]]*\"responses\"" "$config_path"; then printf '[OK]   Responses wire mode configured\n'; else printf '[FAIL] Responses wire mode not configured\n'; failures=$((failures + 1)); fi
        if grep -Eq "^[[:space:]]*base_url[[:space:]]*=[[:space:]]*\"https://api\.z\.ai/api/v1\"" "$config_path"; then printf '[OK]   Z.ai base URL configured\n'; else printf '[FAIL] Z.ai base URL not configured\n'; failures=$((failures + 1)); fi
        if grep -Eq "^[[:space:]]*env_key[[:space:]]*=[[:space:]]*\"ZAI_API_KEY\"" "$config_path"; then printf '[OK]   Secret comes from ZAI_API_KEY\n'; else printf '[FAIL] Secret source is not ZAI_API_KEY\n'; failures=$((failures + 1)); fi
        if grep -Eiq 'sk-[A-Za-z0-9]|api[_-]?key[[:space:]]*=[[:space:]]*[" ]' "$config_path"; then printf '[FAIL] Possible secret literal in config\n'; failures=$((failures + 1)); else printf '[OK]   No obvious secret literal in config\n'; fi
    fi
    if [ -f "$catalog_path" ]; then
        python_bin='python3'
        command -v "$python_bin" >/dev/null 2>&1 || python_bin='python'
        if "$python_bin" -m json.tool "$catalog_path" >/dev/null 2>&1; then printf '[OK]   Catalog JSON is valid\n'; else printf '[FAIL] Catalog JSON is invalid\n'; failures=$((failures + 1)); fi
        if grep -q '"slug": "glm-5.3"' "$catalog_path"; then printf '[OK]   Catalog contains glm-5.3\n'; else printf '[FAIL] Catalog lacks glm-5.3\n'; failures=$((failures + 1)); fi
    fi
fi

if [ "$static_only" -eq 0 ]; then
    if [ -z "${ZAI_API_KEY:-}" ] && [ -s "$key_path" ]; then export ZAI_API_KEY="$(tr -d '\r\n' < "$key_path")"; fi
    if [ -z "${ZAI_API_KEY:-}" ]; then
        printf '[FAIL] ZAI_API_KEY is absent\n'
        failures=$((failures + 1))
    else
        temporary_response="$(mktemp)"
        trap 'rm -f "$temporary_response"' EXIT
        payload='{"model":"glm-5.3","input":"Reply with exactly: ZAI_CODEX_OK","stream":false}'
        status="$(curl -sS -o "$temporary_response" -w '%{http_code}' --max-time 60 -H "Authorization: Bearer $ZAI_API_KEY" -H 'Content-Type: application/json' --data "$payload" 'https://api.z.ai/api/v1/responses' || true)"
        case "$status" in
            2??) printf '[OK]   Z.ai Responses connectivity (HTTP %s)\n' "$status" ;;
            *) printf '[FAIL] Z.ai Responses connectivity (HTTP/status %s)\n' "${status:-unavailable}"; failures=$((failures + 1)) ;;
        esac
    fi
fi

if [ "$connectivity_only" -eq 1 ]; then printf '%s\n' 'Connectivity-only test complete.'; fi
if [ "$static_only" -eq 1 ]; then printf '%s\n' 'Static-only test complete; GUI behavior was not tested.'; fi
if [ "$connectivity_only" -eq 0 ] && [ "$static_only" -eq 0 ]; then printf '%s\n' 'Desktop GUI tests remain interactive; see README.md and PLATFORMS.md.'; fi
if [ "$failures" -gt 0 ]; then printf '%s\n' "$failures check(s) failed." >&2; exit 1; fi
printf '%s\n' 'All executed checks passed; this does not certify unexecuted GUI features.'
