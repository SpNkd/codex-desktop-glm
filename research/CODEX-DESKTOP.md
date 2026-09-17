# Codex Desktop research (as of 2026-09-16)

## Product boundaries

The current Windows product is the Codex view inside the new ChatGPT desktop shell. OpenAI's Windows documentation describes a native Windows desktop app with projects, parallel chats, worktrees, terminal, Git, browser, plugins, and skills. The app can use a native Windows sandbox or WSL2; its integrated shell can be PowerShell, cmd, Git Bash, or WSL. The old standalone Codex app is being updated into the new ChatGPT desktop application, while Codex history remains a distinct view.

Sources: [Windows app](https://learn.chatgpt.com/docs/windows/windows-app), [desktop app transition](https://help.openai.com/en/articles/20001276/), [built-in browser](https://help.openai.com/en/articles/20001277-using-the-built-in-browser-in-the-chatgpt-desktop-app).

## Runtime architecture

The practical path is:

```text
Codex Desktop GUI
        -> local app-server daemon / bundled Codex runtime
        -> codex-core provider resolution
        -> configured model provider
```

The app-server is the machine-readable interface for rich clients. It uses JSON-RPC 2.0 over stdio (with WebSocket support documented as experimental), owns thread/turn lifecycle, approvals, streamed events, and model discovery. The open-source repository describes the app-server daemon as the backend used by remote clients such as Desktop and mobile. This is why the repository configures the normal user Codex home rather than launching a replacement CLI UI.

Sources: [app-server documentation](https://learn.chatgpt.com/docs/app-server), [app-server daemon README](https://github.com/openai/codex/blob/main/codex-rs/app-server-daemon/README.md), [Codex repository](https://github.com/openai/codex).

## Configuration resolution

OpenAI documents the user config as:

```text
%USERPROFILE%\.codex\config.toml
```

Project-level `.codex/config.toml` can override user settings only in a trusted project. The Windows app and local CLI/IDE share the Codex home concept, although WSL has a separate Linux home unless `CODEX_HOME` is explicitly redirected. The setup script therefore writes only the user config and a generated catalog under `%USERPROFILE%\.codex\codex-desktop-glm`.

The relevant current schema fields are:

```toml
model = "glm-5.3"
model_provider = "ZAI"
model_catalog_json = "C:/Users/you/.codex/codex-desktop-glm/models.json"

[model_providers.ZAI]
name = "Z.ai GLM Coding Plan"
base_url = "https://api.z.ai/api/v1"
env_key = "ZAI_API_KEY"
wire_api = "responses"
supports_websockets = false
```

The config reference defines custom providers using `model_provider` and `[model_providers.<id>]`; `base_url` selects the API base, `env_key` names the environment variable supplying the bearer key, `requires_openai_auth` defaults to false, and `model_catalog_json` loads a catalog at startup. The current schema's `wire_api` has only the Responses value. The old Chat value is rejected by current source with a specific “chat wire API removed” error. `setup.ps1` deliberately omits `requires_openai_auth` because the false default is the desired API-key-only provider behavior.

Sources: [basic config](https://learn.chatgpt.com/docs/config-file/config-basic), [advanced config](https://learn.chatgpt.com/docs/config-file/config-advanced), [config reference](https://learn.chatgpt.com/docs/config-file/config-reference), [current `WireApi` source](https://github.com/openai/codex/blob/main/codex-rs/model-provider-info/src/lib.rs).

## Model discovery and app-server protocol

The app-server exposes `model/list`, including model IDs, provider IDs, input modalities, reasoning support, and default-model information. The Desktop picker can therefore depend on both provider resolution and catalog metadata. `model_catalog_json` is a startup-loaded path; after changing it, restart Desktop.

The same app-server protocol exposes `thread/start`, `thread/resume`, `turn/start`, streamed turn events, and `thread/list` with provider filters. That protocol is not an inference adapter: it is the local GUI/runtime control plane. This repository does not impersonate it.

Sources: [app-server methods](https://learn.chatgpt.com/docs/app-server), [model/list reference](https://learn.chatgpt.com/docs/app-server), [config source](https://github.com/openai/codex/blob/main/codex-rs/config/src/config_toml.rs).

## Auth and “no OpenAI inference” boundary

Current custom-provider resolution can skip OpenAI login when `requires_openai_auth` is false and an `env_key` is configured. That establishes the provider runtime path, not a guarantee that every feature of the ChatGPT desktop shell is independent of ChatGPT services. Current upstream reports describe missing first-party app tools and auxiliary `chatgpt.com` metadata requests in API-key-only/custom-provider sessions.

The honest guarantee of this repository is narrower and enforceable: the selected Codex model route is `ZAI` with no configured OpenAI fallback, and a failed Z.ai request is surfaced as a provider failure. It cannot guarantee zero auxiliary OpenAI/ChatGPT network requests without a target-machine packet audit, and it does not attempt to bypass or patch those services.

Relevant reports: [custom provider app tools](https://github.com/openai/codex/issues/37075), [auxiliary metadata dependency](https://github.com/openai/codex/issues/33029), [custom-provider picker behavior](https://github.com/openai/codex/issues/37379).

## Windows package and observable versions

The authoritative version for a user's Store rollout must be read locally. `diagnose.ps1` reports the current AppX package and any safe bundled-runtime candidates; it does not guess from an issue or patch the package.

The latest public Windows package evidence found during this research was upstream issue [#42276](https://github.com/openai/codex/issues/42276), dated 2026-09-02, reporting:

```text
Windows package: OpenAI.Codex 26.831.2377.0
embedded app:    26.831.21537
bundled runtime: 0.152.1
```

These are an observed report, not an official Store release manifest and not necessarily the version on the target PC. The public open-source repository release page showed `0.155.0-alpha.10` on 2026-09-16; a public repository release is not evidence of the bundled Desktop runtime.

Sources: [GitHub releases](https://github.com/openai/codex/releases), [Windows package report](https://github.com/openai/codex/issues/42276), [Windows app install/version docs](https://learn.chatgpt.com/docs/windows/windows-app).

## State, projects, chats, and persistence

The app-server protocol has thread/project-facing operations, but the Desktop sidebar and local state database are separate persistence concerns. Current reports refer to `state_5.sqlite`, session indexes, rollout files, and in some versions a `%USERPROFILE%\.codex\sqlite` location. Custom providers have open reports where threads/projects remain on disk but disappear from the Desktop picker/sidebar after restart or provider filtering. Other reports describe config writes that can truncate or change the visible sidebar.

The scripts intentionally do not edit SQLite, session indexes, rollouts, or the app package. They back up `config.toml`, and `uninstall.ps1` restores that backup only after an explicit confirmation (or `-Force`).

Relevant reports: [custom-provider thread visibility](https://github.com/openai/codex/issues/20184), [custom-provider picker](https://github.com/openai/codex/issues/19694), [Windows config truncation](https://github.com/openai/codex/issues/37768), [state locations](https://github.com/openai/codex/issues/29953).

## Windows and WSL note

Native Windows is the intended setup target. OpenAI documents PowerShell plus a Windows sandbox as the native path and WSL2 as a separate Linux environment. WSL does not automatically share Codex auth, config, or history with native Windows; sharing `CODEX_HOME` is possible but introduces path and Git constraints. The solution does not use WSL as a workaround for the Desktop GUI.

## Decision

Direct provider mode is the correct first implementation. Z.ai documents a Codex integration using the Responses base URL and current Codex accepts Responses only. A local adapter would add an untested protocol translation layer and would not solve Desktop-specific custom-provider feature gaps. There is therefore no `adapter/`, no background task, and no signed-binary modification in this repository.
