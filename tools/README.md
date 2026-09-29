# Local tools

Standalone developer tools kept in this repo for inspect / debug workflows. Each tool lives in its own subdirectory as a [git submodule](https://git-scm.com/book/en/v2/Git-Tools-Submodules) of the upstream project, pinned to a specific commit.

## Tools

| Tool | Directory | Upstream | Local URL |
|------|-----------|----------|-----------|
| A2A Inspector | [`a2a-inspector/`](a2a-inspector/) | [a2aproject/a2a-inspector](https://github.com/a2aproject/a2a-inspector) | http://127.0.0.1:5001 |
| MCP Inspector | [`mcp-inspector/`](mcp-inspector/) | [modelcontextprotocol/inspector](https://github.com/modelcontextprotocol/inspector) | http://127.0.0.1:6274 |

## A2A Inspector

Web UI to inspect, debug, and validate servers that implement the [A2A (Agent2Agent) protocol](https://github.com/a2aproject/a2a-inspector). FastAPI backend + TypeScript frontend.

### Prerequisites

- Python 3.10+ and [uv](https://docs.astral.sh/uv/)
- Node.js and npm
- Optional: Docker (for the containerized run path)

### First-time setup

From the **skills repo root**.

If this clone does not have the submodule contents yet (empty `tools/a2a-inspector`, or a fresh clone without `--recurse-submodules`):

```bash
git submodule update --init tools/a2a-inspector
```

New clones of this repo can fetch it in one step:

```bash
git clone --recurse-submodules <skills-repo-url>
```

Then install dependencies:

```bash
cd tools/a2a-inspector
UV_NATIVE_TLS=1 uv sync          # use if PyPI cert verification fails on your network
cd frontend && npm install && cd ..
```

### Start (each time)

**Option A — local (recommended for development):**

```bash
cd tools/a2a-inspector
bash scripts/run.sh
```

Open **http://127.0.0.1:5001**. Press `Ctrl+C` to stop both frontend and backend.

**Option B — Docker:**

```bash
cd tools/a2a-inspector
docker build -t a2a-inspector .
docker run -d -p 8080:8080 a2a-inspector
```

Open **http://127.0.0.1:8080**.

### Verify / use

1. Open the inspector in the browser.
2. Enter an A2A agent base URL (for example `http://localhost:5555`, or a sample such as `https://sample-a2a-agent-908687846511.us-central1.run.app`).
3. Use **Agent Card**, **Live Chat**, and the **Debug Console** (raw JSON-RPC) as needed.

### Update the inspector

The parent repo records one upstream commit. Updating means moving that pin, then refreshing local dependencies.

From the **skills repo root**:

```bash
# Check out the latest commit on the upstream default branch
git submodule update --remote tools/a2a-inspector

cd tools/a2a-inspector
UV_NATIVE_TLS=1 uv sync
cd frontend && npm install && cd ..
```

To pin a specific tag or commit instead of the branch tip:

```bash
cd tools/a2a-inspector
git fetch origin
git checkout <tag-or-commit>
cd ../..
```

Stage the new pin in this repo and commit it when you want the skills repo to track that version:

```bash
git add .gitmodules tools/a2a-inspector
git status   # tools/a2a-inspector should show a new commit hash
```

After someone else moves the pin, bring your checkout in line with:

```bash
git pull
git submodule update --init tools/a2a-inspector
cd tools/a2a-inspector
UV_NATIVE_TLS=1 uv sync
cd frontend && npm install
```

### Notes

- `scripts/run.sh` starts the frontend watch build and backend on port **5001**. Run it in an **interactive terminal** (esbuild `--watch` exits when stdin is closed).
- Manual alternative (no watch): `cd frontend && npm run build`, then from the tool root: `cd backend && uv run app.py` (or `uv run -- uvicorn app:app --host 127.0.0.1 --port 5001`).
- If `uv sync` fails with TLS / certificate errors, prefer `UV_NATIVE_TLS=1` (or newer `UV_SYSTEM_CERTS=1`).
- Do not commit feature work inside `tools/a2a-inspector` as part of the skills repo. That directory is the upstream project; this repo only stores the submodule URL and the pinned commit.

## MCP Inspector

Web, CLI, and TUI client for inspecting [Model Context Protocol](https://modelcontextprotocol.io) servers. The web UI is Vite + React with a Node backend. This repo pins upstream [modelcontextprotocol/inspector](https://github.com/modelcontextprotocol/inspector) (`main`, the released v2 line).

### Prerequisites

- Node.js `>= 22.19.0` and npm
- Optional: Docker (for the containerized run path)

### First-time setup

From the **skills repo root**.

If this clone does not have the submodule contents yet (empty `tools/mcp-inspector`, or a fresh clone without `--recurse-submodules`):

```bash
git submodule update --init tools/mcp-inspector
```

Then install dependencies. The root `postinstall` installs each client under `clients/`:

```bash
cd tools/mcp-inspector
npm install
```

### Start (each time)

**Option A — local web UI (recommended for development):**

```bash
cd tools/mcp-inspector/clients/web
npm run dev
```

Open **http://127.0.0.1:6274**. Press `Ctrl+C` to stop. The dev server is Vite with the Hono `/api` backend and hot reload. No launcher build is required for this path.

**Option B — built launcher (web, CLI, or TUI):**

```bash
cd tools/mcp-inspector
npm run build
npm run web          # production web UI on http://127.0.0.1:6274
```

After that build, the same launcher binary runs the other clients:

```bash
node clients/launcher/build/index.js --cli
node clients/launcher/build/index.js --tui
```

`npm run web:dev` is the launcher in Vite dev mode. It also needs `npm run build` first, because it runs the built launcher.

**Option C — Docker:**

```bash
cd tools/mcp-inspector
docker build -t mcp-inspector .
docker run --rm -p 127.0.0.1:6274:6274 mcp-inspector
```

Open **http://127.0.0.1:6274**. The process prints an API token in the container logs. Keep the `127.0.0.1:` prefix on `-p` so the UI is not published on every host interface.

### Verify / use

1. Open the inspector in the browser.
2. Add an MCP server (a local stdio command, or a remote HTTP/SSE URL).
3. Use the **Tools**, **Resources**, and **Prompts** tabs to list and call what that server exposes.

### Update the inspector

The parent repo records one upstream commit. Updating means moving that pin, then refreshing local dependencies.

From the **skills repo root**:

```bash
# Check out the latest commit on the upstream default branch
git submodule update --remote tools/mcp-inspector

cd tools/mcp-inspector
npm install
```

To pin a specific tag or commit instead of the branch tip:

```bash
cd tools/mcp-inspector
git fetch origin
git checkout <tag-or-commit>
cd ../..
```

Stage the new pin in this repo and commit it when you want the skills repo to track that version:

```bash
git add .gitmodules tools/mcp-inspector
git status   # tools/mcp-inspector should show a new commit hash
```

After someone else moves the pin, bring your checkout in line with:

```bash
git pull
git submodule update --init tools/mcp-inspector
cd tools/mcp-inspector
npm install
```

### Notes

- The web UI listens on port **6274** (`CLIENT_PORT`). The MCP Apps sandbox uses **6275** (`MCP_SANDBOX_PORT`).
- The page embeds the per-launch API token, so opening http://127.0.0.1:6274 in a browser is enough. The token is also printed in the process output.
- Do not commit feature work inside `tools/mcp-inspector` as part of the skills repo. That directory is the upstream project; this repo only stores the submodule URL and the pinned commit.
