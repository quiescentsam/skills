# MCP servers and Cursor skills

This repository is the single place where MCP server references, tool descriptors, and Cursor Agent Skills are kept. Use it to version personal automation setup and to align agents with the same MCP and skill sources across machines.

## Layout

| Path | Purpose |
|------|---------|
| [`mcps/`](mcps/) | MCP servers: canonical Cursor configs in [`mcps/servers/`](mcps/servers/), emitter script, and docs for **project-level** `.cursor/mcp.json`. |
| [`skills/`](skills/) | Cursor skills (markdown with optional YAML front matter). Add or edit files here, then attach or register them in Cursor as your workflow requires. |

## Using this repo

**MCP (project-level):** Put **only the servers each app needs** in that app’s **`.cursor/mcp.json`**. Canonical commands, pins, and args live in **`mcps/servers/*.json`**; use **`mcps/scripts/emit-mcp-json.cjs`** or run **`mcps/scripts/project-pick-mcp.sh`** from the other project’s root (see [`mcps/README.md`](mcps/README.md)) so configs stay in sync. This repo’s own [`.cursor/mcp.json`](.cursor/mcp.json) is an example. When a skill tells an agent to read tool JSON under `mcps/` before `call_mcp_tool`, keep any checked-in descriptors in sync with the server version you run.

**Skills:** Skills in `skills/` are plain markdown instructions for the agent. Cursor loads available skills from your configured skill paths; keeping them in git makes changes reviewable and portable.

## Contributing to yourself

- Add a new MCP: add `mcps/servers/<id>.json` (and a row in `mcps/README.md`), optionally upstream links and tool JSON under `mcps/` for agents.
- Add a new skill: add a `.md` file under `skills/` with a `name` and `description` in front matter when you want Cursor to surface it reliably in the skill picker.
