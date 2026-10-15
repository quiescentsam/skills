# Agentgateway

Local [agentgateway](https://agentgateway.dev/docs/standalone/latest/quickstart/llm/) process. One OpenAI-compatible URL serves models from Ollama and from Azure AI Foundry.

```bash
bash gateways/agentgateway/start.sh
bash gateways/agentgateway/stop.sh
```

| | |
|--|--|
| LLM URL | http://127.0.0.1:4000/v1 |
| UI | http://127.0.0.1:4000/ui |
| Binary | agentgateway v1.6.0, downloaded into `bin/` on first start |

`start` writes `LLM/.env` from `LLM/.env.example` the first time, downloads the binary when `bin/` does not already have this version, starts the process, and waits until `http://127.0.0.1:4000/v1/models` returns 200. The listener is on `127.0.0.1`.

`stop` stops that process. `LLM/config.yaml`, `LLM/.env`, and the SQLite file in `data/` stay.

LLM routes, the Foundry key, and the resource names live under [`LLM/`](LLM/).
