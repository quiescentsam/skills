# Call the registry from a client agent

[`call_registry.py`](call_registry.py) connects to Jarvis as an MCP client. It uses the gateway's `discover_agents` tool to list or search agents and `execute_agent` to call the selected agent.

## Prepare

Start Jarvis:

```bash
bash registry/jarvis/setup.sh start
```

In the UI at [http://localhost:19080](http://localhost:19080), open the user menu and select **Generate Token**. Generate a managed-agent token containing `mcp-proxy-ops`, then export it:

```bash
export JARVIS_TOKEN='<access token>'
```

The token is read from the environment and is not stored in the repository. The default MCP gateway is `http://127.0.0.1:17860/proxy/mcpgw/mcp`. Override it with `JARVIS_MCP_URL`.

The script declares MCP Python SDK `1.28.1`, matching this Jarvis release, and `httpx` as inline dependencies. `--system-certs` lets `uv` use the machine trust store when installing them.

## List or search agents

List up to 20 enabled agents that the token's user can view:

```bash
uv --system-certs run registry/jarvis/call_registry.py list
```

Search by capability:

```bash
uv --system-certs run registry/jarvis/call_registry.py \
  list --query 'code review' --top-n 3
```

Each result includes an `agent_id`. Use that value for execution; it is not the agent path.

`{"result": []}` means Weaviate has no `A2a_agents` collection. With Azure embeddings, creating that collection requires the `text2vec-openai` module. Run `bash registry/jarvis/set-embedding.sh`, then refresh the agent in the UI. The agent can still appear in the UI before that collection exists.

## Execute an agent

```bash
uv --system-certs run registry/jarvis/call_registry.py \
  execute '<agent_id>' \
  'Review this change and identify correctness problems.'
```

The target agent must be enabled, and the token's user must have view access to it. If the ID is stale or the agent was disabled, run `list` again.
