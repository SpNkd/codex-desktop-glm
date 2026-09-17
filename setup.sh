#!/usr/bin/env bash
set -euo pipefail

force=0
skip_connectivity=0
for argument in "$@"; do
    case "$argument" in
        --force) force=1 ;;
        --skip-connectivity) skip_connectivity=1 ;;
        -h|--help) printf '%s\n' 'Usage: ./setup.sh [--force] [--skip-connectivity]'; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$argument" >&2; exit 2 ;;
    esac
done

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
user_home="${HOME:?HOME is not set}"
codex_config_home="${CODEX_HOME:-$user_home/.codex}"
integration_home="$codex_config_home/codex-desktop-glm"
config_path="$codex_config_home/config.toml"
catalog_path="$integration_home/models.json"
key_path="$integration_home/zai-api-key"
env_path="$integration_home/zai.env"

case "$(uname -s)" in
    Darwin) platform='macOS' ;;
    Linux) platform='Linux' ;;
    *) printf '%s\n' 'This script supports macOS and Linux. Use setup.ps1 on Windows.' >&2; exit 1 ;;
esac

python_bin=''
for candidate in python3 python; do
    if command -v "$candidate" >/dev/null 2>&1; then python_bin="$candidate"; break; fi
done
if [ -z "$python_bin" ]; then
    printf '%s\n' 'Python 3 is required for the portable TOML updater.' >&2
    exit 1
fi

printf 'Platform: %s\n' "$platform"
if command -v codex >/dev/null 2>&1; then
    printf 'Codex runtime: %s\n' "$(codex --version 2>/dev/null || true)"
else
    printf '%s\n' 'Codex command: not found; install Codex CLI/IDE or the official Desktop app where available.'
fi

mkdir -p "$integration_home"
chmod 700 "$integration_home"
api_key="${ZAI_API_KEY:-}"
if [ -z "$api_key" ] && [ -s "$key_path" ] && [ "$force" -eq 0 ]; then
    read -r -p 'Reuse the saved ZAI_API_KEY? [Y/n] ' reuse
    if [[ ! "$reuse" =~ ^[Nn]([Oo])?$ ]]; then api_key="$(tr -d '\r\n' < "$key_path")"; fi
fi
if [ -z "$api_key" ]; then
    read -r -s -p 'Enter Z.ai Coding Plan API key (input is hidden): ' api_key
    printf '\n'
fi
if [ -z "$api_key" ]; then printf '%s\n' 'An API key is required.' >&2; exit 1; fi

umask 077
printf '%s' "$api_key" > "$key_path"
chmod 600 "$key_path"
cat > "$env_path" <<EOF
#!/usr/bin/env sh
if [ -s "$key_path" ]; then
    ZAI_API_KEY="\$(tr -d '\\r\\n' < "$key_path")"
    export ZAI_API_KEY
fi
EOF
chmod 700 "$env_path"

mkdir -p "$(dirname -- "$config_path")"
if [ -f "$config_path" ]; then
    backup_path="$config_path.codex-desktop-glm-backup-$(date +%Y%m%d-%H%M%S).bak"
    cp -p "$config_path" "$backup_path"
    printf 'Backup: %s\n' "$backup_path"
fi
catalog_source="$script_dir/config/models.json.example"
if [ ! -f "$catalog_source" ]; then printf 'Missing catalog template: %s\n' "$catalog_source" >&2; exit 1; fi
cp "$catalog_source" "$catalog_path"
chmod 600 "$catalog_path"
catalog_toml_path="${catalog_path//\\//}"
"$python_bin" "$script_dir/scripts/merge_toml.py" --config "$config_path" --catalog "$catalog_toml_path"

profile_path="$user_home/.profile"
if [ "$platform" = 'macOS' ]; then profile_path="${ZDOTDIR:-$user_home}/.zprofile"; fi
read -r -p "Add a managed source line to $profile_path for future shells? [Y/n] " add_profile
if [[ ! "$add_profile" =~ ^[Nn]([Oo])?$ ]]; then
    touch "$profile_path"
    if ! grep -Fq '# BEGIN codex-desktop-glm environment' "$profile_path"; then
        cp -p "$profile_path" "$profile_path.codex-desktop-glm-backup"
        {
            printf '\n%s\n' '# BEGIN codex-desktop-glm environment'
            printf '%s\n' "[ -f $(printf '%q' "$env_path") ] && . $(printf '%q' "$env_path")"
            printf '%s\n' '# END codex-desktop-glm environment'
        } >> "$profile_path"
        printf 'Profile updated: %s\n' "$profile_path"
    fi
fi

export ZAI_API_KEY="$api_key"
if [ "$skip_connectivity" -eq 0 ]; then
    "$script_dir/test.sh" --connectivity-only || printf '%s\n' 'Warning: live Z.ai connectivity was not verified.' >&2
else
    printf '%s\n' 'Connectivity check skipped.'
fi

printf '\n%s\n' 'Setup completed.'
printf 'Config:  %s\nCatalog: %s\n' "$config_path" "$catalog_path"
printf '%s\n' 'Restart the Codex app/IDE or start a new shell before testing.'
printf '%s\n' 'No adapter, proxy, startup daemon, project deletion, or app-bundle patch was added.'
