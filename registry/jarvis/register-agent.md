# Register an A2A agent

Jarvis catalogs an agent that is already running. It does not start the agent. On save, the backend fetches the agent card and stores it with the catalog entry.

Sign in at [http://localhost:19080](http://localhost:19080) while `bash registry/jarvis/setup.sh start` is running. The steps below match chart **0.2.4** (app `asc0.5.7`). Upstream design: [A2A Agent API](https://jarvisregistry.com/design/a2a-agent-api-design/).

The agent must publish a card at one of these paths, tried in order:

1. `{url}/.well-known/agent-card.json`
2. `{url}/.well-known/agent.json`
3. `{url}` itself

The fetch runs inside the registry backend pod. `localhost` on your Mac is the pod, not your machine, so that URL fails. Use a URL the pod can reach, such as `http://host.docker.internal:<port>` or a Service URL in the cluster.

## In the UI

1. Open **A2A Agents** in the left sidebar.
2. Click **Register Agent**.
3. Under **Network Configuration**, enter the **Agent URL** and click the bolt button (**Test URL**). A successful test shows the card and fills title, description, and transport when those fields are still empty.
4. Fill **Basic Information** and check **I trust this agent**.
5. Click **Register Agent**.

| Field | Required | What to enter |
|-------|----------|----------------|
| Agent URL | Yes | Base URL, `http://` or `https://`. Not the card URL. |
| Transport Type | Yes | `jsonrpc`, `grpc`, or `http_json`. Most HTTP A2A agents use `jsonrpc`. Test URL sets this from `preferredTransport` when it can. |
| Title | Yes | Display name. |
| Description | No | Catalog text. Leave it blank to keep the description from the card. |
| Path | Yes | Unique slug: lowercase letters, numbers, and single dashes, no leading or trailing dash. Example: `code-reviewer`. |
| I trust this agent | Yes | Confirmation in the form. Custom agents are not verified by Jarvis. It is not sent to the API. |

The card supplies name, version, protocol version, skills, and input and output modes. You do not type those in.

A new agent is saved with **enabled** off. Open the agent and turn it on before the registry will proxy calls to it.

## With the API

`POST /api/v1/agents` on the backend port-forward, with the bearer token from your signed-in session:

```bash
curl -sS -X POST http://127.0.0.1:17860/api/v1/agents \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "path": "code-reviewer",
    "title": "Code Review Agent",
    "description": "AI-powered code review assistant",
    "url": "http://host.docker.internal:5555",
    "type": "jsonrpc"
  }'
```

`description` is the only optional field. A successful create returns **201** and `enabled: false`.

| Status | Meaning |
|--------|---------|
| 400 | Invalid path or transport, or the card could not be fetched or parsed. `No role found for resource_type=remoteAgent, perm_bits=15` means the ACL catalog is empty. `bash registry/jarvis/setup.sh start` seeds it and restarts the backend when rows were missing. |
| 409 | That path is already registered, or another path normalizes to the same slug |
