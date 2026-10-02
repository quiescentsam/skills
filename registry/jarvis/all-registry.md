# Call agent 6abc3096c0485fa58919ddf3

`execute_agent` loads this id from MongoDB. You do not need `list` to find it first. The id belongs to `panel-agent`.

## 1. Forward the backend

The client talks to the registry on local port 17860.

```bash
kubectl -n jarvis port-forward --address 127.0.0.1 svc/registry-backend 17860:7860
```

## 2. Export a managed-agent token

In the UI at [http://localhost:19080](http://localhost:19080), open the user menu and select **Generate Token**. Generate a token that includes `mcp-proxy-ops`, then export it:

```bash
export JARVIS_TOKEN='<access token>'
```

## 3. Call the agent

```bash
uv --system-certs run registry/jarvis/call_registry.py \
  execute 6abc3096c0485fa58919ddf3 \
  'Hello, what can you do?'
```

The agent must be enabled, and the token's user must be allowed to view it. The admin user that registered `panel-agent` owns it. If the command reports that the agent is not found or not enabled, turn the agent back on in the UI and run the command again.
