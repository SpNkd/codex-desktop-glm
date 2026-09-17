# Codex Desktop + GLM Coding Plan

Run OpenAI Codex Desktop on Windows using Z.ai GLM Coding Plan as the model backend.

## Quick Start

1. Install Codex Desktop.
2. Run `.\setup.ps1` in PowerShell.
3. Enter your Z.ai Coding Plan API key when prompted.
4. Restart or open Codex Desktop.

This repository configures the normal Codex Desktop application. It does not replace the GUI with the CLI, patch a signed MSIX package, or install a proxy. The selected model request route is:

```text
Codex Desktop / local Codex runtime
        -> https://api.z.ai/api/v1 (Responses)
        -> Z.ai GLM Coding Plan
```

The current Z.ai Codex integration documentation explicitly uses the Responses base URL `https://api.z.ai/api/v1`. The setup script uses Codex's supported `env_key` configuration instead of placing the key in `config.toml`.

## Scope and important limitation

This is a ready-to-run configuration and diagnostic bundle, not a claim that every Desktop-only feature works with every custom provider. The repository was assembled in a non-Windows environment, so the GUI, Windows package, and live Z.ai calls are deliberately marked unexecuted until `test.ps1` and the interactive checklist are run on the target PC.

“Inference exclusively through Z.ai” means the configured model provider is Z.ai and Codex has no configured OpenAI provider fallback. It does not prove that the surrounding ChatGPT desktop shell never contacts ChatGPT/OpenAI for account metadata, browser integration, telemetry, or other auxiliary features. Current Codex reports document such custom-provider shell dependencies. If the requirement is literally zero OpenAI/ChatGPT network traffic, the official Desktop shell cannot be certified for that requirement by this repository.

The default catalog contains `glm-5.3`, the current Z.ai Coding Plan flagship coding model. Z.ai documents `glm-5.3` as text-only; its Coding Plan also documents `glm-5.3-Flash` with visual input, but the official Codex catalog example and this safe default use `glm-5.3`. Computer Use therefore remains unverified and is likely limited in API-key-only custom-provider sessions. Browser control is documented as unavailable/limited in this mode by current upstream reports.

## Capability status

No `PASS` below is asserted without a real target-machine test. `SUPPORTED` means the documented product/config path exists; `UNVERIFIED` means this repository cannot run the GUI or live account from its build environment.

| Feature | Status | Evidence / test |
|---|---|---|
| Codex Desktop GUI | SUPPORTED / UNVERIFIED HERE | Windows app docs; run interactive tests |
| GLM inference | SUPPORTED / NOT RUN HERE | Z.ai Responses route; `test.ps1` |
| Files | SUPPORTED / UNVERIFIED HERE | Desktop interactive test |
| Shell | SUPPORTED / UNVERIFIED HERE | Native Windows PowerShell/cmd |
| Git | SUPPORTED / UNVERIFIED HERE | Requires native Git |
| Multi-step agent loop | UNVERIFIED HERE | Calculator test |
| Projects persistence | UNVERIFIED HERE | Restart test |
| Chats/threads persistence | UNVERIFIED HERE | Restart test; custom-provider issues exist |
| `AGENTS.md` | SUPPORTED / UNVERIFIED HERE | Local instruction test |
| Skills | SUPPORTED / UNVERIFIED HERE | Local skill test |
| MCP | SUPPORTED / UNVERIFIED HERE | Local echo server test |
| Computer Use | UNVERIFIED / LIKELY LIMITED | API-key-only custom-provider caveats; see research |
| Browser Use | FAIL/LIMITED for API-key-only mode | Current upstream API-key auth issue |
| Vision | NOT AVAILABLE in default model | `glm-5.3` is text-only; Flash is not default |
| Automations | UNVERIFIED / CAVEAT | Custom model persistence/rewrite issues |

## What `setup.ps1` changes

The setup is user-scoped:

- checks for a Windows Codex/ChatGPT Desktop package and reports the official Microsoft Store install command if absent;
- stores `ZAI_API_KEY` as a user environment variable, never in this repository or `config.toml`;
- copies the model catalog to `%USERPROFILE%\.codex\codex-desktop-glm\models.json`;
- makes a timestamped backup of `%USERPROFILE%\.codex\config.toml`;
- safely replaces only the provider/model/catalog settings needed for this integration;
- runs a redacted connectivity test when a key is available.

The API key is held in memory only long enough to set the user environment variable and test the endpoint. The default environment-variable route is the least surprising path for Codex's documented custom-provider schema. If stronger at-rest protection is required, use a Windows Credential Manager wrapper or an enterprise secret-management policy; the trade-off is that the Desktop process still needs a way to read the secret and such wrappers are not part of the direct, officially documented Z.ai path.

Setup does not kill or restart Codex, delete projects, edit its database, add startup tasks, or install an adapter. Close and reopen the app after changing `config.toml`.

## Manual configuration

The generated configuration is equivalent to this (with an absolute catalog path):

```toml
model = "glm-5.3"
model_provider = "ZAI"
model_reasoning_effort = "max"
model_catalog_json = "C:/Users/you/.codex/codex-desktop-glm/models.json"

[model_providers.ZAI]
name = "Z.ai GLM Coding Plan"
base_url = "https://api.z.ai/api/v1"
env_key = "ZAI_API_KEY"
wire_api = "responses"
supports_websockets = false
```

`requires_openai_auth` is intentionally omitted: current Codex defaults it to false for custom providers. Current Codex source accepts only `wire_api = "responses"`; the old `chat` wire value is removed. Z.ai's Chat Completions endpoint remains useful for other clients, but it is not a valid current Codex wire mode.

## Interactive Desktop tests

Run `.\test.ps1` first. Then create a disposable folder/project in Codex and run these tests manually. Record the result in `research/COMPATIBILITY.md` or in your own test report; do not call an unrun test PASS.

1. Files: create `hello.txt` containing `hello from GLM`, edit it, then delete it.
2. Agent loop: ask Codex to create the deliberately buggy calculator fixture from `tests/smoke`, run tests, fix `add`, and run tests again.
3. Shell/Git: run PowerShell and `cmd`; run `git init`, `git status`, `git diff`, and `git log` in a disposable repository.
4. `AGENTS.md`: copy `tests/AGENTS.md` into the project and verify type hints are used and `README.md` is untouched.
5. Skills: install/copy `tests/skills/glm-smoke/SKILL.md` into the project skill location and ask Codex to use it.
6. MCP: add the snippet below to your user config, restart Codex, and ask it to call `glm_smoke_echo`.
7. Persistence: create a project and multiple chats, quit and reopen the Desktop app, then verify they remain visible.
8. Computer Use: if the tool is exposed, ask it to open Notepad, type `Hello from GLM Codex Desktop`, save it on the Desktop, reopen it, and confirm the content.
9. Browser: if the tool is exposed, ask it to open a browser, navigate to `https://example.com`, and read the title. Do not substitute `curl`.

MCP test configuration, using a forward-slash Windows path:

```toml
[mcp_servers.glm_smoke]
command = "python"
args = ["C:/path/to/Codex+GLM/tests/mcp/echo_server.py"]
```

The server is local, stdlib-only, and does not access the network. Do not enable it globally unless you want this test tool available in all projects.

## Troubleshooting

- Run `.\diagnose.ps1` and attach its redacted output to a bug report.
- Run `.\test.ps1 -ConnectivityOnly` to isolate the provider from Desktop GUI behavior.
- If the model picker shows `Custom` or omits GLM, verify `model_catalog_json`, restart Desktop, and inspect current upstream issues before editing app state.
- Never edit `state_*.sqlite`, `app.asar`, or the signed Windows package as a workaround. Backups from setup are listed by `uninstall.ps1`.
- If a Z.ai request fails, Codex should report the provider error. There is no fallback block in this configuration.

To remove the integration, run `.\uninstall.ps1`. It asks whether to restore the timestamped pre-setup config; use `.\uninstall.ps1 -RestoreBackup` to request that explicitly. It never removes Codex Desktop or user projects/chats.

## Research

- [Codex Desktop and runtime](research/CODEX-DESKTOP.md)
- [Z.ai Coding Plan](research/ZAI.md)
- [Computer Use and Browser Use](research/COMPUTER-USE.md)
- [Compatibility matrix and evidence state](research/COMPATIBILITY.md)
- [Quick start](QUICKSTART.md)

Primary references:

- [OpenAI Windows app documentation](https://learn.chatgpt.com/docs/windows/windows-app)
- [OpenAI Codex config reference](https://learn.chatgpt.com/docs/config-file/config-reference)
- [OpenAI Codex app-server](https://learn.chatgpt.com/docs/app-server)
- [OpenAI Codex repository](https://github.com/openai/codex)
- [Z.ai Codex integration](https://docs.z.ai/devpack/tool/codex)
- [Z.ai Coding Plan overview](https://docs.z.ai/devpack/overview)
- [Z.ai usage policy](https://docs.z.ai/devpack/usage-policy)
- [Z.ai subscription terms](https://docs.z.ai/legal-agreement/subscription-terms)

## License

MIT. See [LICENSE](LICENSE).
