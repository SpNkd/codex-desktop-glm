#!/usr/bin/env bash
set -euo pipefail

force=0
restore=0
for argument in "$@"; do
    case "$argument" in
        --force) force=1 ;;
        --restore-backup) restore=1 ;;
        -h|--help) printf '%s\n' 'Usage: ./uninstall.sh [--restore-backup] [--force]'; exit 0 ;;
        *) printf 'Unknown option: %s\n' "$argument" >&2; exit 2 ;;
    esac
done

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
user_home="${HOME:?HOME is not set}"
codex_config_home="${CODEX_HOME:-$user_home/.codex}"
integration_home="$codex_config_home/codex-desktop-glm"
config_path="$codex_config_home/config.toml"

if [ "$force" -eq 0 ]; then
    read -r -p 'Remove the Codex Desktop + GLM integration? [y/N] ' answer
    [[ "$answer" =~ ^[Yy]([Ee][Ss])?$ ]] || { printf '%s\n' 'Uninstall cancelled.'; exit 0; }
fi

backup_path=''
if [ -d "$codex_config_home" ]; then
    backup_path="$(find "$codex_config_home" -maxdepth 1 -type f -name 'config.toml.codex-desktop-glm-backup-*.bak' -print 2>/dev/null | sort | tail -n 1 || true)"
fi
if [ -n "$backup_path" ] && [ "$restore" -eq 0 ] && [ "$force" -eq 0 ]; then
    read -r -p "Restore the latest pre-setup config backup? [Y/n] $backup_path " restore_answer
    [[ "$restore_answer" =~ ^[Nn]([Oo])?$ ]] || restore=1
fi

if [ -n "$backup_path" ] && [ "$restore" -eq 1 ]; then
    if [ -f "$config_path" ]; then cp -p "$config_path" "$config_path.before-uninstall-$(date +%Y%m%d-%H%M%S).bak"; fi
    cp -p "$backup_path" "$config_path"
    printf 'Restored: %s\n' "$backup_path"
else
    python_bin='python3'
    command -v "$python_bin" >/dev/null 2>&1 || python_bin='python'
    if [ -f "$config_path" ]; then "$python_bin" "$script_dir/scripts/merge_toml.py" --config "$config_path" --remove; printf '%s\n' 'Managed provider settings removed from config.toml.'; fi
fi

profile_path="$user_home/.profile"
case "$(uname -s)" in Darwin) profile_path="${ZDOTDIR:-$user_home}/.zprofile" ;; esac
python_bin='python3'
command -v "$python_bin" >/dev/null 2>&1 || python_bin='python'
if [ -f "$profile_path" ]; then "$python_bin" "$script_dir/scripts/clean_profile.py" "$profile_path"; fi
if [ -d "$integration_home" ]; then rm -rf "$integration_home"; printf 'Removed generated files: %s\n' "$integration_home"; fi
printf '%s\n' 'Codex Desktop, user projects, chats, history, and SQLite state were not removed.'
