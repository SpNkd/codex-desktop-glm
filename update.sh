#!/usr/bin/env bash
set -euo pipefail

script_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
printf '%s\n' 'Codex Desktop + GLM update check'
if command -v codex >/dev/null 2>&1; then printf 'Codex runtime: %s\n' "$(codex --version 2>/dev/null || true)"; else printf '%s\n' 'Codex runtime: not found on PATH'; fi
printf '%s\n' 'The official Desktop app is updated by its platform distribution channel; this script does not replace or patch it.'
printf '%s\n' 'Checking the existing direct-provider configuration:'
"$script_dir/test.sh" --static-only
printf '%s\n' 'Run ./diagnose.sh after any Codex update and restart the app/IDE.'
