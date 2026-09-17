# Compatibility matrix and evidence state

Date of research: 2026-09-16. Target: Windows 10/11, native Codex Desktop GUI, Z.ai Coding Plan.

The current workspace is not a Windows Desktop session and has no Z.ai account key. Therefore no GUI or live inference item is marked `PASS`. Run `test.ps1` and the interactive checklist on the target machine before changing these statuses.

## Required result fields

```text
DESKTOP_CUSTOM_PROVIDER = YES (runtime-supported; Desktop UI caveats remain)
DIRECT_ZAI = YES (official Z.ai Codex Responses route)
DIRECT_PROTOCOL = responses
ADAPTER_REQUIRED = NO
OPENAI_LOGIN_REQUIRED = NO for provider runtime / UNVERIFIED for surrounding app shell
OPENAI_INFERENCE_USED = NO for the selected model route; auxiliary shell traffic is not audited
GLM_MODEL = glm-5.3
ZAI_ENDPOINT = https://api.z.ai/api/v1/responses
COMPUTER_USE = UNVERIFIED / likely limited in API-key-only custom-provider mode
BROWSER_USE = NO/LIMITED in API-key-only mode according to current upstream reports
SKILLS = YES as a local runtime feature; GUI invocation unverified
MCP = YES as a local runtime feature; GUI invocation unverified
```

## Evidence matrix

| Area | Result | Why / verification required |
|---|---|---|
| Desktop custom provider | SUPPORTED by current runtime schema | Verify picker and fresh thread on target Desktop |
| Direct Z.ai | DOCUMENTED | Z.ai Codex page specifies Responses base URL; run live test |
| Chat Completions direct mode | NOT SUPPORTED by current Codex | Current source rejects `wire_api = "chat"` |
| Adapter | NOT REQUIRED / NOT PRESENT | Direct Responses route exists; no translation code is shipped |
| OpenAI login | NO for custom provider runtime; shell unverified | `requires_openai_auth` false by default, but auxiliary shell reports exist |
| Config/catalog | STATICALLY TESTABLE | `test.ps1 -StaticOnly` |
| Files | UNVERIFIED HERE | Run file test in Desktop |
| Shell | UNVERIFIED HERE | Run PowerShell/cmd test in Desktop |
| Git | UNVERIFIED HERE | Requires native Git and a disposable repo |
| Multi-step agent loop | UNVERIFIED HERE | Run calculator fixture and inspect tool/result/edit cycle |
| Projects persistence | UNVERIFIED HERE | Restart Desktop and verify sidebar |
| Chat persistence | UNVERIFIED HERE | Restart Desktop; custom-provider issues are open |
| `AGENTS.md` | SUPPORTED / UNVERIFIED HERE | Local instruction fixture |
| Skills | SUPPORTED / UNVERIFIED HERE | Local discovery is documented; invoke fixture |
| MCP | SUPPORTED / UNVERIFIED HERE | Shared local config is documented; call echo tool |
| Computer Use | UNVERIFIED / likely limited | Text-only default model plus custom-provider tool caveats |
| Browser Use | FAIL/LIMITED in API-key-only custom sessions | Current upstream API-key auth rejection reports |
| Vision | NO for default `glm-5.3` | Z.ai documents it as text-only; Flash is a separate untested model |
| Automations | UNVERIFIED / risk | Custom model ID persistence/rewrite behavior requires target test |

## Version evidence

```text
CODEX_DESKTOP_VERSION = 26.831.21537 embedded / 26.831.2377.0 package
                         observed in upstream issue #42276 on 2026-09-02;
                         not an authoritative current Store version
BUNDLED_CODEX_RUNTIME = 0.152.1 in the same report
CODEX_PUBLIC_REPO_RELEASE = 0.155.0-alpha.10 observed 2026-09-16;
                            not necessarily bundled in Desktop
WINDOWS_PACKAGE = MSIX/Microsoft Store; diagnose.ps1 reads the target machine
```

Evidence: [#42276](https://github.com/openai/codex/issues/42276), [public releases](https://github.com/openai/codex/releases), [Windows app docs](https://learn.chatgpt.com/docs/windows/windows-app).

## Known failure modes

- The model picker may display `Custom`, omit custom models, or persist a namespaced model incorrectly: [#37379](https://github.com/openai/codex/issues/37379), [#19694](https://github.com/openai/codex/issues/19694).
- Threads/projects can remain on disk but disappear from the Desktop GUI after provider changes or restart: [#20184](https://github.com/openai/codex/issues/20184).
- API-key-only custom sessions may not receive first-party app tools: [#37075](https://github.com/openai/codex/issues/37075).
- Auxiliary ChatGPT metadata can still affect Desktop behavior: [#33029](https://github.com/openai/codex/issues/33029).
- Browser API-key authentication has current rejection reports: [#45317](https://github.com/openai/codex/issues/45317).

The supported recovery path is to verify the config/catalog, restart Desktop, and collect diagnostics. Do not modify `state_*.sqlite`, `app.asar`, or the signed MSIX.
