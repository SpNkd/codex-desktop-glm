# Computer Use, Browser Use, Skills, and MCP

## What is different from shell access

Codex's Windows app has a native PowerShell/cmd/Git Bash/WSL terminal. That is an agent tool for commands and file operations; it is not Computer Use. Computer Use is the desktop-control path that can inspect screenshots and interact with foreground windows through click, keyboard, clipboard, and app-launch actions.

OpenAI documents Computer Use in the ChatGPT desktop app for Windows and macOS through the Computer Use plugin/server/skill. On Windows the target app must remain visible and active; it is not a background automation service. OpenAI also documents an allow-list in `%USERPROFILE%\.codex\config.toml` under `[computer_use.windows]`, separate from administrator permissions.

Source: [OpenAI Computer Use](https://learn.chatgpt.com/docs/computer-use).

## Provider and model prerequisites

Computer Use is not enabled merely by adding a tool definition to a model catalog. The Desktop shell has to register the feature, the local helper/plugin must be available, the app-server must expose the tool to the turn, and the model/provider request must accept the required input and tool events. OpenAI's Computer Use documentation specifically recommends a first-party capable model for difficult visual tasks; that is evidence of a model/provider dependency, not proof that arbitrary custom providers receive the same tool set.

The default Z.ai model here, `glm-5.3`, is documented as text-only. It cannot natively interpret screenshots, so visual Computer Use cannot be certified for that model. Z.ai documents `glm-5.3-Flash` as multimodal, but it is not the default Codex catalog entry and does not remove the separate Desktop custom-provider/tool-registration question.

## Current custom-provider evidence

Current upstream reports show several independent caveats:

- API-key-only custom-provider sessions can lack first-party `codex_app` tools even while ordinary model turns work: [issue #37075](https://github.com/openai/codex/issues/37075).
- Browser/Chrome integration has rejected API-key authentication in current reports: [issue #45317](https://github.com/openai/codex/issues/45317), with an earlier related report at [#21710](https://github.com/openai/codex/issues/21710).
- Windows Computer Use/browser helpers have had package/path regressions: [#25571](https://github.com/openai/codex/issues/25571), [#20354](https://github.com/openai/codex/issues/20354).

These reports do not prove that every current Windows build fails every Computer Use path. They do prove that a config-only catalog entry is insufficient evidence for a PASS. The compatibility result is therefore `UNVERIFIED / likely limited` for Computer Use and `LIMITED/FAIL` for Browser Use in API-key-only custom-provider mode until a target build demonstrates otherwise.

## Tests to run on Windows

Use a disposable folder and do not replace these tests with shell commands:

1. Ask Codex Desktop to open Notepad, type `Hello from GLM Codex Desktop`, save it on the Desktop, reopen it, and confirm the contents.
2. Ask it to open a browser, navigate to `https://example.com`, and read the page title.
3. Record whether the request visibly exposes a Computer/Browser tool, whether a screenshot reaches the model, and whether the agent continues after the tool result.
4. If a tool is absent, save the Desktop/app-server version from `diagnose.ps1` and the relevant provider/model settings; do not patch the MSIX or SQLite state.

## Skills

Skills are local instruction packages that can be discovered by Codex Desktop/CLI/IDE. OpenAI documents a `skills/list` app-server method and local Skills support. The small `tests/skills/glm-smoke/SKILL.md` fixture tests local discovery and does not require an OpenAI inference provider by definition. Actual invocation still needs a live Desktop turn and is marked unverified here.

Sources: [build skills](https://learn.chatgpt.com/docs/build-skills), [app-server skills methods](https://learn.chatgpt.com/docs/app-server).

## MCP

MCP is a local tool/context extension, not an inference backend. OpenAI documents local Codex clients connecting directly to MCP servers via stdio or streamable HTTP, with shared config in `%USERPROFILE%\.codex\config.toml`. The repository includes a stdlib-only JSON-RPC stdio echo server. It is not installed or enabled automatically. Add the documented snippet in `README.md`, restart Desktop, and record a real tool call as the MCP result.

Source: [OpenAI MCP](https://learn.chatgpt.com/docs/extend/mcp).
