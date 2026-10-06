# MCP servers in Cursor

You turn servers on by listing them in an **`mcp.json`** file. Cursor reads two of those files and merges them.

## `mcp.json`

The file has one top-level key, `mcpServers`. Each key under it is the name Cursor shows in chat and in **Customize → MCP**.

Local server (Cursor runs the process):

```json
{
  "mcpServers": {
    "server-name": {
      "command": "npx",
      "args": ["-y", "some-mcp-server"],
      "env": {
        "API_KEY": "${env:API_KEY}"
      }
    }
  }
}
```

Remote server (already running somewhere):

```json
{
  "mcpServers": {
    "server-name": {
      "url": "https://example.com/mcp",
      "headers": {
        "Authorization": "Bearer ${env:API_TOKEN}"
      }
    }
  }
}
```

Cursor expands these placeholders in `command`, `args`, `env`, `url`, `headers`, and `auth`:

| Placeholder | Meaning |
|-------------|---------|
| `${env:NAME}` | Environment variable |
| `${userHome}` | Home directory |
| `${workspaceFolder}` | Project root (the folder that contains `.cursor/mcp.json`) |
| `${workspaceFolderBasename}` | Name of that project root |

After you edit either file, reload the window so Cursor picks up the change. Toggle a server on or off from **Customize** in the sidebar (scope **User** for the global file, the project folder for the project file). Logs are in the Output panel (`Cmd+Shift+U`) under **MCP Logs**.

## Global vs project

| Scope | File | Applies to |
|-------|------|------------|
| Global (user) | `~/.cursor/mcp.json` | Every project you open in Cursor |
| Project | `<project-root>/.cursor/mcp.json` | That project only |

On this machine the global file is [`~/.cursor/mcp.json`](file:///Users/sameer.ahmad/.cursor/mcp.json) (`/Users/sameer.ahmad/.cursor/mcp.json`).

Cursor loads both files. If the same server name appears in both, the **project** entry wins.

Use the global file for tools you want in every repo. Use the project file for tools that belong to one codebase (and for anything you want to commit and share). A project file is optional: with none, only the global servers load.

### What is set globally

These five servers are in `~/.cursor/mcp.json` today. They are available in every Cursor project, including this one.

| Server | How it runs |
|--------|-------------|
| `databricks` | Local Python process: `~/.ai-dev-kit/.venv/bin/python` running `~/.ai-dev-kit/repo/databricks-mcp-server/run_server.py`, with `DATABRICKS_CONFIG_PROFILE=DEFAULT` |
| `chrome-devtools` | `npx -y chrome-devtools-mcp@latest --isolated` (via `/usr/bin/env -u SSL_CERT_FILE` so a custom CA bundle is not forced onto Node) |
| `postgres-devtools` | `postgres-mcp --access-mode=restricted` (`startup_timeout_sec` 45, `tool_timeout_sec` 120) |
| `kubernetes-mcp-server` | `npx -y kubernetes-mcp-server@latest` |
| `Notion` | Remote HTTP server at `https://mcp.notion.com/mcp` (OAuth; no static token in the file) |

### Where the project file lives

Project config is **`<project-root>/.cursor/mcp.json`**, next to the repo’s other Cursor settings. It is not `mcp.json` at the repo root, and it is not `~/.cursor/mcp.json`.

Examples:

- This repo: `mcps` lives here, so a project file would be [`.cursor/mcp.json`](../.cursor/mcp.json) at the repo root. That file is not present, so this repo uses only the global servers above.
- Another app: `/path/to/that-app/.cursor/mcp.json`.

Nothing under `~/Desktop` currently has a `.cursor/mcp.json`. To add project-only servers, create that file in the app you have open. In **Customize → MCP**, switch the scope from **User** to the project folder to see and toggle those servers.

## Canonical server definitions in this repo

Checked-in fragments live in [`servers/`](servers/) (one JSON file per server). They are the objects you would put under `mcpServers`, plus an optional `"_serverKey"` when the Cursor name should differ from the filename. Copy or generate them into a project’s `.cursor/mcp.json`. Do not commit a generated file that already has secrets expanded.

Secrets for generation: optional [`mcps/.env`](.env) (same directory as `servers/`). Fragments may use **`${ENV_NAME}`** (for example `Bearer ${RENDER_API_KEY}` in [`servers/render.json`](servers/render.json)). `emit-mcp-json.cjs` loads `mcps/.env` without overriding variables already exported in the shell, then expands those placeholders. That `${ENV_NAME}` form is for the emitter. Cursor itself expects **`${env:NAME}`** if you hand-edit a file that Cursor should expand at runtime.

### Generate a project `mcp.json`

From this repo root:

```bash
node mcps/scripts/emit-mcp-json.cjs --list
node mcps/scripts/emit-mcp-json.cjs chrome-devtools > /path/to/your-app/.cursor/mcp.json
node mcps/scripts/emit-mcp-json.cjs chrome-devtools some-other-server > /path/to/your-app/.cursor/mcp.json
```

Merge into an existing project file (keeps other `mcpServers` keys; selected ids overwrite the same key):

```bash
node mcps/scripts/emit-mcp-json.cjs --merge /path/to/your-app/.cursor/mcp.json chrome-devtools > /tmp/mcp.json
mv /tmp/mcp.json /path/to/your-app/.cursor/mcp.json
```

Re-run when you add a server here or change pins and args.

### Picker from a project root

From another repo’s root (or pass **`-C /path/to/project`**). It lists servers, or takes a server id as the first argument. If **`.cursor/mcp.json` already exists**, new entries are merged in.

```bash
/path/to/this-repo/mcps/scripts/project-pick-mcp.sh
/path/to/this-repo/mcps/scripts/project-pick-mcp.sh chrome-devtools
/path/to/this-repo/mcps/scripts/project-pick-mcp.sh -C ~/code/my-app chrome-devtools
```

Prefer **`./mcps/scripts/project-pick-mcp.sh`** or **`bash mcps/scripts/project-pick-mcp.sh`**. The script avoids bash-only process substitution, so **`sh mcps/scripts/project-pick-mcp.sh`** also works on macOS.

### Hand-edit

Copy the inner object from `servers/<id>.json` into the project’s `mcpServers`, and omit `"_serverKey"` (the emitter uses that field only). Keep `command`, `args`, and `env` aligned with the fragment so every project behaves the same.

## Servers inventory

| Server | Canonical config | Upstream |
|--------|------------------|----------|
| Chrome DevTools MCP | [`servers/chrome-devtools.json`](servers/chrome-devtools.json) | [ChromeDevTools/chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp) |
| Render (hosted MCP) | [`servers/render.json`](servers/render.json) | [Render MCP server](https://docs.render.com/docs/mcp-server) |

The global `chrome-devtools` entry is a variant of the fragment above (`--isolated`, and `SSL_CERT_FILE` unset). Add a row and a new `servers/<id>.json` when you adopt another MCP.

## Requirements

Servers invoked via `npx` need **Node.js** (and a compatible **Chrome** install for Chrome DevTools MCP). See each upstream README for version bounds and flags (`--slim`, `--headless`, privacy flags, and so on).

## Running Maverick MCP

Maverick runs as a **separate process** (clone lives at [`maverick-mcp/`](maverick-mcp/)). See also [`containers/README.md`](../containers/README.md) for the shared Redis stack.

### First-time setup

From this repo root:

```bash
cd mcps/maverick-mcp
cp .env.example .env          # set TIINGO_API_KEY; REDIS_PORT=6380 matches Docker Redis below
UV_NATIVE_TLS=1 uv sync         # use native TLS if PyPI cert verification fails on your network
```

### Start (each time)

```bash
# 1. Redis (once per reboot — skip if the container is already up)
docker compose -f containers/redis/docker-compose.yml up -d

# 2. Maverick
cd mcps/maverick-mcp
make dev                        # http://127.0.0.1:8003/mcp/
```

Run those `docker compose` paths from this repo root. If you are already in `mcps/maverick-mcp`, use `../../containers/redis/docker-compose.yml` instead.

To have Cursor use it, add a server entry (global or project `mcp.json`) whose `url` is `http://127.0.0.1:8003/mcp/`.

### Verify

```bash
curl http://127.0.0.1:8003/mcp    # expect 406 — server is listening
curl http://127.0.0.1:8003/health # health check
```

### Notes

- **`make dev`** checks Redis by connectivity on `REDIS_HOST`/`REDIS_PORT` (Docker, Homebrew, or native). It can also start the Docker stack in `containers/redis/` if nothing is listening.
- **No Redis?** Set `REDIS_HOST=none` in `.env` to skip caching and skip the Docker step.
- **PyPI TLS errors** during `uv sync` or `make dev`? Run `UV_NATIVE_TLS=1 uv sync` once; `make dev` sets `UV_NATIVE_TLS=1` automatically.
