# Local models with Ollama

Notes for running local LLMs on macOS (Apple Silicon, tested on M4 / Metal) with [Ollama](https://ollama.com). Ollama exposes an HTTP API on **`http://127.0.0.1:11434`** that Cursor, scripts, and other tools can call without sending prompts to a hosted provider.

## 1. Install

```bash
brew install ollama
```

This drops the binary at **`/opt/homebrew/opt/ollama/bin/ollama`**. The Homebrew caveat also prints two recommended env flags worth keeping in mind:

| Variable | Value | Why |
|----------|-------|-----|
| `OLLAMA_FLASH_ATTENTION` | `1` | Faster attention kernels on Apple Silicon. |
| `OLLAMA_KV_CACHE_TYPE` | `q8_0` | Quantized KV cache — uses less memory for long contexts. |

> If `ollama` is already present, `brew install` is a no-op and prints `already installed and up-to-date`. Use `brew reinstall ollama` to force a fresh install, or `brew upgrade ollama` for new versions.

## 2. Start the server

You have two options.

**Option A — foreground (one-off, easy to stop with `Ctrl+C`):**

```bash
ollama serve
```

The first run generates a key at **`~/.ollama/id_ed25519`** and starts listening:

```
Listening on 127.0.0.1:11434 (version 0.23.2)
discovering available GPUs...
inference compute ... library=Metal description="Apple M4" total="11.8 GiB"
vram-based default context total_vram="11.8 GiB" default_num_ctx=4096
```

On Apple Silicon, Ollama auto-detects Metal and the available unified-memory VRAM. The `default_num_ctx` value (e.g. `4096`) is sized to fit that VRAM; raise it per-model only if you have headroom.

**Option B — background service (auto-start at login):**

```bash
brew services start ollama
# stop: brew services stop ollama
# logs: tail -f /opt/homebrew/var/log/ollama.log
```

**Option C — foreground with the caveat-recommended flags:**

```bash
OLLAMA_FLASH_ATTENTION="1" OLLAMA_KV_CACHE_TYPE="q8_0" /opt/homebrew/opt/ollama/bin/ollama serve
```

> If you skip this step you’ll see `Error: could not connect to ollama server, run 'ollama serve' to start it` when you try to run a model.

## 3. Pull and run a model

In a **second** terminal (the first is running `ollama serve`):

```bash
ollama run llama3
```

The first run pulls the model (the default `llama3` tag is about **4.7 GB**) into `~/.ollama/models`, then drops you into an interactive prompt. Subsequent runs reuse the cached blobs and start in seconds. Exit the chat with `/bye` or `Ctrl+D`.

Some useful management commands:

```bash
ollama list                 # show installed models and sizes
ollama pull llama3:8b       # pull a specific tag without running
ollama show llama3          # show modelfile, parameters, license
ollama rm llama3            # delete a model
ollama ps                   # show models currently loaded in memory
```

### Picking a model

VRAM (or unified memory on Apple Silicon) is the practical limit. As a rough rule of thumb for 4-bit quantized models:

| Size | Approx. footprint | Examples |
|------|-------------------|----------|
| 3B   | ~2 GB             | `phi3:mini`, `llama3.2:3b` |
| 7–8B | ~5 GB             | `llama3`, `mistral`, `qwen2.5:7b` |
| 13B  | ~8 GB             | `llama3:13b`, `codellama:13b` |
| 30B+ | 18 GB+            | `mixtral`, `llama3:70b` (needs lots of RAM) |

Browse the catalog at <https://ollama.com/library>.

## 4. Call the local API

Once `ollama serve` is up, anything on the box can hit the local HTTP API.

```bash
curl http://127.0.0.1:11434/api/generate -d '{
  "model": "llama3",
  "prompt": "Say hi in one short sentence.",
  "stream": false
}'
```

Or the OpenAI-compatible endpoint:

```bash
curl http://127.0.0.1:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

Set `OPENAI_BASE_URL=http://127.0.0.1:11434/v1` (and any non-empty `OPENAI_API_KEY`) to point most OpenAI SDKs at your local Ollama.

## 5. Use a local model from Cursor

Cursor → **Settings** → **Models** → **Add custom model** → set the **Base URL** to **`http://127.0.0.1:11434/v1`** and the **Model name** to whatever you pulled (e.g. `llama3`). Leave the API key as any non-empty placeholder. The Ollama server must be running for Cursor to reach it.

## 6. Troubleshooting

- **`Error: could not connect to ollama server`** — `ollama serve` is not running (or is listening on a different host/port). Start it in another terminal, or use `brew services start ollama`.
- **Port `11434` already in use** — another Ollama instance (often the brew service) is up. `lsof -i :11434` to find it, or `brew services stop ollama` before running `ollama serve` in the foreground.
- **Model load OOM / very slow** — VRAM is too small for the model+context. Pick a smaller tag (`llama3:8b` → `llama3.2:3b`), keep `OLLAMA_KV_CACHE_TYPE=q8_0`, or lower the context: `OLLAMA_CONTEXT_LENGTH=2048 ollama serve`.
- **Custom model location** — set `OLLAMA_MODELS=/path/to/dir` before starting the server (default is `~/.ollama/models`).
- **Reset everything** — `brew services stop ollama; rm -rf ~/.ollama` then reinstall and re-pull.

## References

- Ollama docs: <https://github.com/ollama/ollama/tree/main/docs>
- Model library: <https://ollama.com/library>
- OpenAI-compatible API notes: <https://github.com/ollama/ollama/blob/main/docs/openai.md>
