# LLM gateway

Routes on the agentgateway listener at `http://127.0.0.1:4000/v1`. Start and stop from the parent directory:

```bash
bash gateways/agentgateway/start.sh
bash gateways/agentgateway/stop.sh
```

| Client `model` | Upstream |
|----------------|----------|
| `ollama/llama3.2` | Ollama at `http://127.0.0.1:11434`, model `llama3.2` |
| `foundry/gpt-4.1` | Azure AI Foundry deployment `gpt-4.1` |

The `ollama/` and `foundry/` prefixes are stripped before the request is forwarded. Use the name Ollama has pulled, or the Foundry deployment name, after the prefix.

`GET /v1/models` lists Foundry catalog names as `foundry/<id>`. Ollama has no catalog, so call a pulled model directly, for example `ollama/llama3.2`.

## Foundry

1. Set `FOUNDRY_API_KEY` in `LLM/.env` (copied from `.env.example` on first start).
2. In `config.yaml`, set `azureResourceName` and `azureProjectName`.
3. Restart with `bash gateways/agentgateway/start.sh`.

Ollama does not use that key. Requests with an `ollama/` model work while the Foundry fields are still placeholders.

## Call

```bash
curl http://127.0.0.1:4000/v1/chat/completions \
  -H 'content-type: application/json' \
  -d '{"model":"ollama/llama3.2","messages":[{"role":"user","content":"Hello"}]}'
```

Ollama must already be running on `127.0.0.1:11434`. See [`local_models/README.md`](../../../local_models/README.md).
