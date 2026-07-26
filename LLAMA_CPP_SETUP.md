# llama.cpp `llama-server` Provider

This patch adds a first-class `llama.cpp (llama-server)` provider to Godot AI Assistant Hub.

## Supported AI Hub features

- Chat and saved conversations
- Quick Prompts, including code-editor insertion
- Godot tools and approval workflow
- Structured tool-call round trips using OpenAI-compatible `tool_call_id` messages
- Reasoning display and reasoning controls
- Temperature override
- Context usage indicator
- Custom server URL and optional Bearer API key
- Single-model `llama-server` and multi-model router model listing

## Recommended server command

```bash
llama-server \
  --model /path/to/model.gguf \
  --alias my-model \
  --ctx-size 32768 \
  --jinja \
  --reasoning auto \
  --reasoning-format deepseek \
  --host 127.0.0.1 \
  --port 8080
```

Tool calling requires a tool-aware chat template. Recent llama.cpp builds use Jinja by default, but keeping `--jinja` explicit makes the requirement clear. When a model's embedded template is unsuitable, use a compatible `--chat-template` or `--chat-template-file`.

For a server protected with `--api-key`, enter the key in AI Hub. For an unprotected local server, leave the key blank.

## AI Hub setup

1. Start `llama-server`.
2. Enable the AI Assistant Hub plugin in Godot.
3. Select **llama.cpp (llama-server)** as the provider.
4. Use `http://127.0.0.1:8080` for the default local server, or enter the remote server URL.
5. Leave the API-key field blank unless the server requires one.
6. Refresh models, select the model alias, and create an assistant type.

## Reasoning controls

AI Hub maps its reasoning menu to llama-server request controls. The provider sends both the current `reasoning_budget_tokens` name and the older `thinking_budget_tokens` alias for compatibility:

| AI Hub option | Request behavior |
| --- | --- |
| Default | Uses model/server defaults |
| Disabled | `reasoning_effort: none`, thinking disabled, zero thinking budget |
| Enabled | Thinking enabled; uses the server budget when configured, otherwise unrestricted |
| Low | 512-token thinking budget |
| Medium | 2048-token thinking budget |
| High | 8192-token thinking budget |

Per-request thinking budgets require a recent llama.cpp build and a template with recognized thinking end tags. The Low, Medium, and High choices explicitly override the request budget; Enabled falls back to the server's configured budget when one exists.

## Context length behavior

Unlike Ollama, stock `llama-server` cannot resize its physical context window per request. Set the real context with `--ctx-size` when starting the server. AI Hub reads the running value from `/props`.

The assistant's context-length field remains available as a lower client-side warning threshold. It cannot raise the server above its startup context. For exact behavior, use the same value in the assistant and in `--ctx-size`.

## Tool-call compatibility

AI Assistant Hub historically stores tool feedback as an Ollama-style `{role: "tool", content: ...}` message. OpenAI-compatible servers require the tool result to identify the preceding call. The provider normalizes conversation history before each request by:

1. Preserving or generating a unique tool-call ID.
2. Converting tool arguments to the OpenAI-compatible JSON-string form.
3. Pairing each tool feedback message with `tool_call_id` and the function name.
4. Converting arguments back to a dictionary before executing the Godot tool.

This keeps existing saved chats and the current tool approval/execution pipeline compatible without changing the shared conversation classes.

## Smoke tests

```bash
curl http://127.0.0.1:8080/v1/models
curl http://127.0.0.1:8080/props
```

Then verify in Godot:

1. Models load in the provider tab.
2. A basic chat returns text.
3. Context usage appears after a response.
4. A Quick Prompt can read and place code.
5. A tools-capable assistant can call a read-only tool.
6. A write tool requests approval, executes, sends its result back, and the model continues the conversation.
7. Reasoning content follows the configured AI Hub display preference.
