# Quick start

## Windows

1. Install the official Windows Codex Desktop app from the Microsoft Store. The documented command is:

   ```powershell
   winget install --id 9PLM9XGG6VKS -s msstore
   ```

2. Open PowerShell in this repository and run:

   ```powershell
   Set-ExecutionPolicy -Scope Process Bypass
   .\setup.ps1
   ```

3. Enter the Z.ai Coding Plan API key. It is stored as the user-scoped `ZAI_API_KEY` environment variable, not in the repository or Codex TOML.

4. Close and reopen Codex Desktop. The app reads `%USERPROFILE%\.codex\config.toml` on startup.

5. Verify the provider outside the GUI:

   ```powershell
   .\test.ps1 -ConnectivityOnly
   .\diagnose.ps1
   ```

6. Create a disposable Codex project and run the calculator agent-loop test from `README.md`.

## macOS

1. Install the official Codex/ChatGPT Desktop app if it is available for your account/region.
2. In Terminal, run `chmod +x setup.sh test.sh diagnose.sh update.sh uninstall.sh` once.
3. Run `./setup.sh`, enter the Z.ai Coding Plan key, and accept the optional `.zprofile` source block if you want future shells to inherit it.
4. Restart the Desktop app or launch it from a shell that has sourced `~/.codex/codex-desktop-glm/zai.env`.

## Linux

1. Install the Codex CLI/IDE/app-server client supported by your distribution/workflow. The official Desktop GUI is not certified for Linux by this bundle.
2. Run `./setup.sh` and source the generated `~/.codex/codex-desktop-glm/zai.env` before starting the client.
3. Use `./test.sh --static-only`, `./test.sh --connectivity-only`, and `./diagnose.sh`.

The setup scripts do not install an adapter. Current Codex accepts only the Responses wire protocol, and Z.ai documents the Responses endpoint needed by Codex. If this direct route is rejected by the target build, capture diagnostics and runtime versions before considering any other architecture.
