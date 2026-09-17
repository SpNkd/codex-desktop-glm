# Platform support

This repository keeps one direct provider configuration and supplies native setup/diagnostic wrappers for Windows, macOS, and Linux.

| Platform | Script | Codex GUI status | What is supported |
|---|---|---|---|
| Windows 10/11 | `setup.ps1` | Official Codex/ChatGPT Desktop available; GUI unverified in this environment | Native PowerShell, AppX detection, user `ZAI_API_KEY`, config backup, catalog, diagnostics |
| macOS | `setup.sh` | Official Codex Desktop available; GUI unverified in this environment | POSIX setup, config backup, catalog, optional `.zprofile` environment loading, diagnostics |
| Linux | `setup.sh` | No official Codex Desktop GUI certification in the current OpenAI Windows/macOS documentation | Same direct provider config for Codex CLI/IDE/app-server where installed, shell env, catalog, diagnostics |

## macOS and Linux secret handling

`setup.sh` stores the key in:

```text
${CODEX_HOME:-$HOME/.codex}/codex-desktop-glm/zai-api-key
```

with mode `0600`, creates a small loader file, and optionally adds a managed source block to `.zprofile` on macOS or `.profile` on Linux. The key is never written to `config.toml`, the model catalog, or this repository. If you decline the profile change, source the generated `zai.env` before starting a CLI/IDE process:

```sh
. "$HOME/.codex/codex-desktop-glm/zai.env"
```

Finder-launched macOS GUI processes may not inherit shell profile variables. In that case launch the app from an environment-aware shell or use the platform's approved environment/secret management policy. The repository intentionally does not add an unreviewed login daemon or proxy.

## Linux boundary

The direct Codex provider schema is portable, but the official Desktop shell is not documented for Linux. Linux support in this repository means the provider/configuration layer and compatible Codex CLI/IDE/app-server clients. It does not silently substitute the CLI as the requested Desktop UI.

## Shared behavior

All platforms use:

```text
model = glm-5.3
model_provider = ZAI
wire_api = responses
base_url = https://api.z.ai/api/v1
env_key = ZAI_API_KEY
```

There is no adapter, no fallback provider, no binary patch, and no automatic deletion of Codex projects, chats, or state databases. Computer Use, Browser Use, and custom-provider Desktop persistence still require an interactive test on the target platform.
