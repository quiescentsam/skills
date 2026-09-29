# Local models

Two local runtimes that can run **side by side** on macOS (Apple Silicon):

| | [Ollama](https://ollama.com) | [Ollaya](https://ollaya.dev/) |
|--|------------------------------|------------------------------|
| Purpose | Chat / generative LLMs | System One / **Jev-style** decision models |
| Default port | `127.0.0.1:11434` | `127.0.0.1:11435` |
| Output | Text (tokens) | Typed answers + calibrated probabilities |
| Quick setup | `bash local_models/setup-ollama.sh` | `bash local_models/setup-ollaya.sh` |

Use **Ollama** for Cursor custom models, OpenAI-compatible SDKs, and local chat. Use **Ollaya** when you want a local stand-in for TypeSafe **Jev** (`/v1/systemone`).

---

# Part A — Ollama (chat LLMs)

Run generative LLMs locally with Metal on Apple Silicon. HTTP API: **`http://127.0.0.1:11434`**.

## Quick start

```bash
bash local_models/setup-ollama.sh
ollama pull llama3.2:3b
ollama run llama3.2:3b
```

## 1. Install Ollama

**Recommended — official app (Homebrew cask):**

```bash
brew install --cask ollama-app
```

Installs **`/Applications/Ollama.app`** and the `ollama` CLI. The app bundles the full inference stack (including `llama-server`), which the formula-only install may not.

**Alternative — download:** <https://ollama.com/download>

**Not recommended — Homebrew formula only:**

```bash
brew install ollama
```

The formula can miss `llama-server`, so many GGUF / embedding models fail. Prefer `ollama-app`. If you already have the formula:

```bash
brew uninstall ollama
brew install --cask ollama-app
```

> Needs **macOS 14+** for the current app cask and [Homebrew](https://brew.sh) for the brew paths.

## 2. Start the server

**App install (recommended):** `open -a Ollama` (menu bar app → `:11434`).

**Foreground (CLI):**

```bash
ollama serve
```

**Background (formula / brew services):**

```bash
brew services start ollama
# stop: brew services stop ollama
# logs: tail -f /opt/homebrew/var/log/ollama.log
```

Optional Apple Silicon env vars when starting via CLI:

| Variable | Value | Why |
|----------|-------|-----|
| `OLLAMA_FLASH_ATTENTION` | `1` | Faster attention on Apple Silicon |
| `OLLAMA_KV_CACHE_TYPE` | `q8_0` | Quantized KV cache — less memory for long contexts |

```bash
OLLAMA_FLASH_ATTENTION=1 OLLAMA_KV_CACHE_TYPE=q8_0 ollama serve
```

> Without a running server: `Error: could not connect to ollama server, run 'ollama serve' to start it`.

## 3. Pull and run a model

```bash
ollama pull llama3.2:3b
ollama run llama3.2:3b
```

Models live under `~/.ollama/models`. Exit chat with `/bye` or `Ctrl+D`.

```bash
ollama list
ollama show llama3.2:3b
ollama ps
ollama rm llama3.2:3b
```

### Picking a model

| Size | Approx. footprint | Examples |
|------|-------------------|----------|
| 3B   | ~2 GB             | `llama3.2:3b`, `phi3:mini` |
| 7–8B | ~5 GB             | `llama3.1:8b`, `mistral`, `qwen2.5:7b` |
| 13B  | ~8 GB             | `llama3.1:13b`, `codellama:13b` |
| 30B+ | 18 GB+            | `mixtral`, `llama3.1:70b` |

Catalog: <https://ollama.com/library>.

## 4. Call the local API

```bash
curl http://127.0.0.1:11434/api/generate -d '{
  "model": "llama3.2:3b",
  "prompt": "Say hi in one short sentence.",
  "stream": false
}'
```

OpenAI-compatible:

```bash
curl http://127.0.0.1:11434/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2:3b",
    "messages": [{"role": "user", "content": "Hello"}]
  }'
```

Point SDKs with `OPENAI_BASE_URL=http://127.0.0.1:11434/v1` and any non-empty `OPENAI_API_KEY`.

## 5. Use from Cursor

1. Start Ollama (`open -a Ollama` or `ollama serve`).
2. Cursor → **Settings** → **Models** → **Add custom model**.
3. **Base URL:** `http://127.0.0.1:11434/v1`
4. **Model name:** tag you pulled (e.g. `llama3.2:3b`)
5. **API key:** any non-empty placeholder

## 6. Troubleshooting (Ollama)

- **`could not connect to ollama server`** — start the app or `ollama serve` / `brew services start ollama`.
- **Port `11434` in use** — another instance is up; `lsof -i :11434`, quit the menu-bar app, or stop brew services.
- **`llama-server` / GGUF failures after `brew install ollama`** — switch to `brew uninstall ollama && brew install --cask ollama-app`.
- **OOM / very slow** — smaller tag, `OLLAMA_KV_CACHE_TYPE=q8_0`, or `OLLAMA_CONTEXT_LENGTH=2048 ollama serve`.
- **Custom model dir** — `OLLAMA_MODELS=/path/to/dir` (default `~/.ollama/models`).
- **Reset** — quit Ollama / `brew services stop ollama`, then `rm -rf ~/.ollama` and reinstall / re-pull.

### Ollama references

- <https://ollama.com> · [Download](https://ollama.com/download) · [Docs](https://github.com/ollama/ollama/tree/main/docs) · [Library](https://ollama.com/library) · [OpenAI API](https://github.com/ollama/ollama/blob/main/docs/openai.md) · [Homebrew cask](https://formulae.brew.sh/cask/ollama-app)

---

# Part B — Ollaya (Jev-style decision models)

[Ollaya](https://ollaya.dev/) serves **System One / Jev-style** decision models (typed choice / score / yes-no with calibrated probabilities in one forward pass). It is **not** a chat LLM server.

TypeSafe’s hosted **Jev** created this category. Ollaya serves **open** models behind a **TypeSafe-compatible** API so Jev clients can point at localhost.

| | Hosted Jev (TypeSafe) | Local Ollaya |
|--|----------------------|--------------|
| Models | Closed `jev-latest` | Open models (`laya`, `winnow:e4b`, …) |
| API | TypeSafe cloud | `http://127.0.0.1:11435` |
| Wire format | `/v1/systemone` | Same shape (SDK 0.7.1) |

## Quick start

```bash
bash local_models/setup-ollaya.sh
```

Or manually:

```bash
curl -fsSL https://ollaya.dev/install.sh | sh
ollaya serve          # http://127.0.0.1:11435
ollaya pull laya      # small, CPU-friendly
ollaya run laya --preset triage "I was charged twice and want a refund."
```

Closer-to-Jev accuracy (larger download; better with NVIDIA GPU):

```bash
ollaya pull winnow:e4b
ollaya run winnow:e4b
```

## 1. Install Ollaya

**macOS (Apple silicon, macOS 14+) / Linux:**

```bash
curl -fsSL https://ollaya.dev/install.sh | sh
```

**Windows (PowerShell):**

```powershell
irm https://ollaya.dev/install.ps1 | iex
```

**Docker:**

```bash
docker run -d --name ollaya -p 11435:11435 \
  -v ollaya:/home/ollaya/.ollaya \
  ghcr.io/ollaya-dev/ollaya

docker exec -it ollaya ollaya run laya
```

Desktop apps: <https://ollaya.dev/download> (still install the CLI for `ollaya` commands).

```bash
ollaya -v
```

## 2. Serve a model

```bash
ollaya serve
```

Listens on **`127.0.0.1:11435`**. Other commands can auto-start the server (`~/.ollaya/logs/server.log`).

```bash
ollaya pull laya
ollaya run laya
ollaya run laya --preset triage "Can I get an invoice for last month?"

ollaya list
ollaya ps
ollaya show laya
ollaya stop
ollaya rm laya
```

### Model picks

| Model | Notes |
|-------|--------|
| `laya` | Fast on CPU (Apple Silicon) |
| `winnow:e4b` | Closer to Jev accuracy; ~8 GB; best with NVIDIA GPU ≥10 GB |
| Others | See <https://ollaya.dev/> |

Store: `~/.ollaya/models` (`OLLAYA_MODELS` to override).

## 3. Call the Jev / TypeSafe-compatible API

```bash
export TYPESAFE_BASE_URL=http://localhost:11435
export TYPESAFE_API_KEY=local              # any non-empty string
export TYPESAFE_DEFAULT_MODEL=laya         # required — SDK default is jev-latest
export NO_PROXY=localhost,127.0.0.1
```

```bash
curl http://localhost:11435/v1/systemone \
  -H "Authorization: Bearer local" \
  -H "Content-Type: application/json" \
  -d '{
  "model": "laya",
  "state": "Can I get an invoice for last month?",
  "questions": {
    "intent": {
      "type": "choice",
      "instructions": "What does the customer want?",
      "criteria": {
        "invoice": "Needs an invoice or receipt",
        "refund": "Wants money back",
        "other": "Anything else"
      }
    }
  }
}'
```

| Path | Role |
|------|------|
| `POST /v1/systemone` | Decide (TypeSafe / Jev-compatible) |
| `POST /v1/decisions` | Alias of `/v1/systemone` |
| `GET /v1/models` | Models on this machine |
| `POST /api/decide` | Native Ollaya API |

Wire format matches TypeSafe; **weights do not** (open models, not proprietary `jev-latest`). Always set `TYPESAFE_DEFAULT_MODEL` or pass `model`.

## 4. Use from agents (MCP)

```bash
claude mcp add ollaya -- ollaya mcp
```

In Cursor, register an MCP entry that runs `ollaya mcp` after install + pull. See Ollaya Agents docs on <https://ollaya.dev/>.

## 5. Env vars (Ollaya server)

| Variable | Default | Effect |
|----------|---------|--------|
| `OLLAYA_HOST` | `127.0.0.1:11435` | Bind / CLI target |
| `OLLAYA_MODELS` | `~/.ollaya/models` | Model store |
| `OLLAYA_KEEP_ALIVE` | `5m` | Unload idle models after |
| `OLLAYA_DEVICE` | `auto` | `auto`, `cpu`, `cuda`, … |
| `OLLAYA_API_KEY` | unset | If set, require matching Bearer token |

## 6. Troubleshooting (Ollaya)

- **Connection refused on 11435** — `ollaya serve` (or `ollaya run` / `pull` to auto-start).
- **SDK still calls `jev-latest`** — set `TYPESAFE_DEFAULT_MODEL=laya` (or `winnow:e4b`).
- **Slow first request** — cold load; SDK retries usually hit a warm model.
- **Port clash** — `OLLAYA_HOST=127.0.0.1:11436 ollaya serve` and update `TYPESAFE_BASE_URL`.

### Ollaya references

- <https://ollaya.dev/> · [Download](https://ollaya.dev/download) · [CLI](https://ollaya.dev/docs/cli) · [TypeSafe compatibility](https://ollaya.dev/docs/typesafe-compatibility) · [FAQ](https://ollaya.dev/docs/faq)
