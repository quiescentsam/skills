# MCP servers

Canonical **Cursor** definitions live in [`servers/`](servers/) (one JSON file per server). Each **application repo** turns servers on or off with its own **`.cursor/mcp.json`** at the project root—only list the servers you want for that codebase.

Cursor merges **project** `.cursor/mcp.json` with the user-level MCP config; project entries win on name clashes.

## Project-level workflow

1. **Keep this `skills` repo** cloned somewhere stable on the machine (for example `~/Desktop/CODE/skills`).
2. **Register servers here** by adding `servers/<id>.json`. Each file is a single server’s config (the object that would appear under `mcpServers` in Cursor), plus an optional `"_serverKey"` if the Cursor name should differ from `<id>`.
3. **In each other project**, create or edit **`.cursor/mcp.json`** and include only the servers that project should use.
4. **Secrets**: optional **`mcps/.env`** (same directory as `servers/`). Server JSON may use **`${ENV_NAME}`** in strings (for example `Bearer ${RENDER_API_KEY}` in [`servers/render.json`](servers/render.json)). `emit-mcp-json.cjs` loads `mcps/.env` without overriding variables already exported in your shell, then expands those placeholders in the emitted output. Avoid committing a generated `.cursor/mcp.json` that contains expanded tokens.

### Option A — generate from this repo (recommended)

From the **skills** repo root, emit a full `mcp.json` body for the servers you want (example: Chrome DevTools only):

```bash
node mcps/scripts/emit-mcp-json.cjs chrome-devtools > /path/to/your-app/.cursor/mcp.json
```

List defined server ids:

```bash
node mcps/scripts/emit-mcp-json.cjs --list
```

Multiple servers in one project:

```bash
node mcps/scripts/emit-mcp-json.cjs chrome-devtools some-other-server > /path/to/your-app/.cursor/mcp.json
```

Re-run the command when you add servers here or change pins/args centrally.

**Merge** into an existing project file (keeps other `mcpServers` keys; selected ids overwrite same key):

```bash
node mcps/scripts/emit-mcp-json.cjs --merge /path/to/your-app/.cursor/mcp.json chrome-devtools > /tmp/mcp.json
mv /tmp/mcp.json /path/to/your-app/.cursor/mcp.json
```

### Option A1 — bash picker from any project root

From another repo’s root (or pass **`-C /path/to/project`**), run the script in this repo. It lists available servers interactively, or you can pass the server id as the first argument. If **`.cursor/mcp.json` already exists**, new entries are **merged** in.

```bash
~/Desktop/CODE/skills/mcps/scripts/project-pick-mcp.sh
~/Desktop/CODE/skills/mcps/scripts/project-pick-mcp.sh chrome-devtools
~/Desktop/CODE/skills/mcps/scripts/project-pick-mcp.sh -C ~/code/my-app chrome-devtools
```

If you copied only the script elsewhere, set **`SKILLS_ROOT`** to the path of this skills clone so it can find `emit-mcp-json.cjs` and `servers/`.

For a short command, add an alias or symlink the script onto your **`PATH`**.

Prefer **`./mcps/scripts/project-pick-mcp.sh`** or **`bash mcps/scripts/project-pick-mcp.sh`**. The script avoids bash-only process substitution so **`sh mcps/scripts/project-pick-mcp.sh`** also works on macOS (where `/bin/sh` is bash in POSIX mode).

### Option B — hand-edit each project

Copy the inner object from `servers/<id>.json` into your app’s `mcpServers`, and **omit** the `"_serverKey"` field (that field is only for the emitter). Keep `command` / `args` / `env` aligned with this repo so every project behaves the same.

## Servers inventory

| Server | Canonical config | Upstream |
|--------|------------------|----------|
| Chrome DevTools MCP | [`servers/chrome-devtools.json`](servers/chrome-devtools.json) | [ChromeDevTools/chrome-devtools-mcp](https://github.com/ChromeDevTools/chrome-devtools-mcp) |
| Render (hosted MCP) | [`servers/render.json`](servers/render.json) | [Render MCP server](https://docs.render.com/docs/mcp-server) |

Add a row and a new `servers/<id>.json` when you adopt another MCP.

## Requirements

Servers invoked via `npx` need **Node.js** (and a compatible **Chrome** install for Chrome DevTools MCP). See each upstream README for version bounds and flags (`--slim`, `--headless`, privacy flags, etc.).
