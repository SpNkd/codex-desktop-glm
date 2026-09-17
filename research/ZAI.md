# Z.ai GLM Coding Plan research (as of 2026-09-16)

## Direct endpoint and protocol

Z.ai's official Codex integration page explicitly says that Codex connects through an OpenAI Responses-compatible endpoint at:

```text
https://api.z.ai/api/v1
```

For a Responses request, the resource URL is `https://api.z.ai/api/v1/responses`. The API key is obtained from the Individual or Team Coding Plan. The page title says “Codex CLI” even though its introduction also describes Codex as terminal and desktop; this wording inconsistency is recorded rather than silently treating the page as a formal Desktop compatibility certification.

The same page gives a manual config using `experimental_bearer_token`. This repository uses the current Codex schema's `env_key = "ZAI_API_KEY"` instead, so the key is not written to TOML. Both approaches target the same Z.ai Responses endpoint; the environment-variable form is easier to rotate and safer to publish as a template.

Sources: [Z.ai Codex integration](https://docs.z.ai/devpack/tool/codex), [Z.ai quick start endpoint table](https://docs.z.ai/devpack/quick-start), [Z.ai API introduction](https://docs.z.ai/api-reference/introduction).

## Chat and Responses endpoints

Z.ai documents these separate endpoint families:

| Protocol | Coding Plan endpoint | Role in this project |
|---|---|---|
| OpenAI Chat Completions | `https://api.z.ai/api/coding/paas/v4` | Documented for compatible tools, not a current Codex wire mode |
| OpenAI Responses | `https://api.z.ai/api/v1` | Direct Codex route |
| Anthropic-compatible | `https://api.z.ai/api/anthropic` | Not used |

Current Codex source rejects `wire_api = "chat"`; consequently Direct Mode B is not a valid current implementation even though Z.ai supports Chat Completions for other clients. No adapter is required for Direct Mode A.

## Current Coding Plan models

Z.ai's current DevPack overview lists `GLM-5.3` and `GLM-5.3-Flash` as the Coding Plan models. Requests for older names can be routed by Z.ai according to its current plan rules. The default catalog deliberately exposes only `glm-5.3`, matching the official Codex catalog example and avoiding a model-picker claim that has not been tested in Desktop.

`glm-5.3` is the default flagship coding model used here. Z.ai describes it as text-only, with a 1M-token context window and up to 128K output. Its documented reasoning levels are low, high, and max; the catalog selects max. Z.ai documents coding capabilities including streaming, function calling, caching, and structured output.

`glm-5.3-Flash` is documented as a Coding Plan model with visual understanding and image/video/file input, a 1M context window, and up to 128K output. It has different quota multipliers and is not the default catalog entry. Vision does not automatically make it a supported Codex Computer Use model; the Desktop tool-registration and custom-provider path still require a real GUI test.

Sources: [Coding Plan overview](https://docs.z.ai/devpack/overview), [GLM-5.3 guide](https://docs.z.ai/guides/llm/glm-5.3), [GLM-5.3-Flash guide](https://docs.z.ai/guides/vlm/glm-5.3-flash).

## Tools, streaming, and request capabilities

The current Z.ai Chat Completions documentation describes streaming SSE, tool/function definitions, tool calls, parallel tool calls, system/developer/user/assistant/tool roles, JSON-object structured output, reasoning, and `reasoning_effort`. It documents up to 128 functions in a request and a maximum output/token parameter up to 131,072 for the relevant API. These are useful corroborating capabilities, but they are not a substitute for the Responses event schema consumed by current Codex.

The official Codex page is the reason this repository uses Responses directly. It does not publish a full Z.ai Responses event catalog in the page captured for this research, so this repository does not invent a translation layer or assert that every Chat-only field has an equivalent Responses behavior.

Source: [Z.ai Chat Completions reference](https://docs.z.ai/api-reference/llm/chat-completion).

## Context and Coding Plan consumption

Z.ai's overview documents a five-hour credit window plus a weekly quota, with plan-dependent example quotas: Lite 2K/10K, Pro 12K/60K, and Max 28K/140K. It documents dynamic reset behavior and token multipliers. For GLM-5.3, the listed multipliers are input 6.9, cached input 1.7, and output 24; for Flash they are input 2.3, cached input 0.56, and output 8. MCP calls have an additional documented multiplier, and off-peak usage may be discounted. These values can change; check the live Z.ai plan page before budgeting.

Concurrency is tier-dependent and plan benefits are tied to supported tools. The setup script does not attempt to estimate credits or alter quota behavior.

Source: [Z.ai DevPack overview](https://docs.z.ai/devpack/overview).

## Terms and usage policy

Z.ai explicitly lists Codex among supported Coding Plan tools and says Coding Plan quota is for officially supported tools. The policy/terms also state that account sharing is prohibited, the plan is for personal use, unsupported SDK/third-party integrations can cause benefit restrictions, and the subscription is not general-purpose API access. The terms prohibit public proxying, resale, repackaging, or providing the plan as a service.

The narrow conclusion for this repository is:

- direct personal use through the documented Codex integration is within the stated supported-tool scope;
- the repository must not become a public gateway, shared account proxy, resale service, or repackaged API;
- a local private configuration helper is not represented as a general authorization for arbitrary third-party harnesses;
- if Z.ai changes or clarifies its terms, the current terms take precedence over this research note.

Sources: [supported tools](https://docs.z.ai/devpack/tool/others), [usage policy](https://docs.z.ai/devpack/usage-policy), [subscription terms](https://docs.z.ai/legal-agreement/subscription-terms).

## Key handling decision

`setup.ps1` stores the key as a user-level `ZAI_API_KEY` and writes only the variable name into Codex config. The key is not printed, logged, committed, or copied into the model catalog. `diagnose.ps1` reports only present/absent. This is supported by current Codex's `env_key` field. Windows environment variables are not a full secret vault; use Credential Manager or enterprise secret management if local at-rest protection is a hard requirement, while retaining a process-readable bridge for Codex.
