# MCP servers and Cursor skills

This repository is the single place where MCP server references, tool descriptors, Cursor Agent Skills, and local-model setup notes are kept. [`skills/`](skills/) is a local library of those skills. When you start a project, pick the ones that project should follow and install them into that repo so Cursor can use them.

## Layout

| Path | Purpose |
|------|---------|
| [`mcps/`](mcps/) | MCP servers: canonical Cursor configs in [`mcps/servers/`](mcps/servers/), emitter script, and docs for **project-level** `.cursor/mcp.json`. |
| [`skills/`](skills/) | Local library of Cursor Agent Skills. Pick the ones a new project needs and install them into that repo’s `.cursor/skills/`. |
| [`local_models/`](local_models/) | Local model runtimes: **Ollama** (chat LLMs on `:11434`) and **Ollaya** (Jev-style decision models on `:11435`). |
| [`tools/`](tools/) | Standalone local tools ([A2A Inspector](tools/a2a-inspector/), [MCP Inspector](tools/mcp-inspector/)); see [`tools/README.md`](tools/README.md). |
| [`containers/`](containers/) | Docker Compose stacks for backing services (Redis, etc.). |
| [`observability/langfuse/`](observability/langfuse/) | Local Langfuse (traces, prompts, evals) at http://localhost:3100. |
| [`registry/`](registry/) | Local Kubernetes installs for artifact registries. Open-source agentregistry lives in [`registry/solo_agent_registry/`](registry/solo_agent_registry/). Jarvis Registry lives in [`registry/jarvis/`](registry/jarvis/). |
| [`security/keycloak/`](security/keycloak/) | Local Keycloak in namespace `security-keycloak`, forwarded to port 18080. |
| [`security/secrets/`](security/secrets/) | Local OpenBao in namespace `security-secrets`, forwarded to port 18200. External Secrets copies values into Kubernetes Secrets for workloads. |

## Using this repo

**MCP (project-level):** Put **only the servers each app needs** in that app’s **`.cursor/mcp.json`**. Canonical commands, pins, and args live in **`mcps/servers/*.json`**; use **`mcps/scripts/emit-mcp-json.cjs`** or run **`mcps/scripts/project-pick-mcp.sh`** from the other project’s root (see [`mcps/README.md`](mcps/README.md)) so configs stay in sync. This repo’s own [`.cursor/mcp.json`](.cursor/mcp.json) is an example. When a skill tells an agent to read tool JSON under `mcps/` before `call_mcp_tool`, keep any checked-in descriptors in sync with the server version you run.

**Skills:** [`skills/`](skills/) is a local library, not something Cursor loads by itself. When you start a project, pick the skills that project should follow and install only those into the project’s `.cursor/skills/`. Cursor reads each one from `.cursor/skills/<name>/SKILL.md`.

From the new repo’s root (or pass **`-C`**):

```bash
/path/to/skills/skills/setup.sh
/path/to/skills/skills/setup.sh -C ~/code/my-app
/path/to/skills/skills/setup.sh default
/path/to/skills/skills/setup.sh -l
```

The script lists every skill in the library. Enter numbers (`1,3` or `1-3`), skill ids, or `a` for all. Pass ids on the command line to skip the prompt. **`-m copy`** (the default) copies the skill into the project so the repo does not depend on this clone. **`-m symlink`** links back to the library so edits here show up in the project. **`-y`** replaces a skill that is already installed. **`-a`** installs every skill. If you moved only the script, set **`SKILLS_ROOT`** to this repo’s root.

Prefer **`bash …/skills/setup.sh`** on macOS. Reload the Cursor window if the new skills do not show up right away. See [`skills/README.md`](skills/README.md) for how to add a skill to the library.

## Contributing to yourself

- Add a new MCP: add `mcps/servers/<id>.json` (and a row in `mcps/README.md`), optionally upstream links and tool JSON under `mcps/` for agents.
- Add a new skill: add `skills/<name>/SKILL.md` (or a markdown file under `skills/`) with a `name` and `description` in front matter, then install it into a project with [`skills/setup.sh`](skills/setup.sh).
