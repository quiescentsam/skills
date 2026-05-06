#!/usr/bin/env node
/**
 * Emit a Cursor-style .cursor/mcp.json body from canonical fragments in mcps/servers/.
 *
 * Usage:
 *   node mcps/scripts/emit-mcp-json.cjs --list
 *   node mcps/scripts/emit-mcp-json.cjs chrome-devtools
 *   node mcps/scripts/emit-mcp-json.cjs chrome-devtools other-server
 *   node mcps/scripts/emit-mcp-json.cjs --merge /path/to/.cursor/mcp.json chrome-devtools
 *
 * Run from the skills repo root (or any cwd; paths are relative to this script).
 * --merge: if the file exists, existing mcpServers are kept; listed servers overwrite/add keys.
 */

const fs = require("fs");
const path = require("path");

const scriptDir = __dirname;
const serversDir = path.join(scriptDir, "..", "servers");
const mcpsEnvPath = path.join(serversDir, "..", ".env");

/**
 * Load mcps/.env into process.env (KEY=VALUE). Does not override existing env vars.
 * Minimal parser: # comments, optional " or ' wrapping on value.
 */
function loadMcpsDotEnv() {
  if (!fs.existsSync(mcpsEnvPath)) return;
  const text = fs.readFileSync(mcpsEnvPath, "utf8");
  for (const line of text.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const eq = trimmed.indexOf("=");
    if (eq <= 0) continue;
    const key = trimmed.slice(0, eq).trim();
    let val = trimmed.slice(eq + 1).trim();
    if (
      (val.startsWith('"') && val.endsWith('"')) ||
      (val.startsWith("'") && val.endsWith("'"))
    ) {
      val = val.slice(1, -1);
    }
    if (key && process.env[key] === undefined) process.env[key] = val;
  }
}

const ENV_REF = /\$\{([A-Za-z_][A-Za-z0-9_]*)\}/g;

function substituteEnvInStrings(value, serverIdForErrors) {
  if (typeof value === "string") {
    return value.replace(ENV_REF, (_, name) => {
      const v = process.env[name];
      if (v === undefined || v === "") {
        throw new Error(
          `Missing env "${name}" for MCP server "${serverIdForErrors}" (set it in the shell or in ${mcpsEnvPath})`
        );
      }
      return v;
    });
  }
  if (Array.isArray(value)) {
    return value.map((x) => substituteEnvInStrings(x, serverIdForErrors));
  }
  if (value && typeof value === "object") {
    const out = {};
    for (const [k, v] of Object.entries(value)) {
      out[k] = substituteEnvInStrings(v, serverIdForErrors);
    }
    return out;
  }
  return value;
}

function listServerIds() {
  return fs
    .readdirSync(serversDir)
    .filter((f) => f.endsWith(".json"))
    .map((f) => path.basename(f, ".json"));
}

function loadServer(serverId) {
  const base = serverId.endsWith(".json")
    ? path.basename(serverId, ".json")
    : serverId;
  const fp = path.join(serversDir, `${base}.json`);
  if (!fs.existsSync(fp)) {
    throw new Error(
      `Unknown server id "${serverId}". Known: ${listServerIds().join(", ")}`
    );
  }
  const raw = JSON.parse(fs.readFileSync(fp, "utf8"));
  const key = raw._serverKey ?? base;
  const { _serverKey, ...config } = raw;
  const expanded = substituteEnvInStrings(config, base);
  return { key, config: expanded };
}

function parseArgv(argv) {
  let mergePath = null;
  const ids = [];
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--merge" || a === "-m") {
      mergePath = argv[++i];
      if (!mergePath) {
        throw new Error("--merge requires a path argument");
      }
      mergePath = path.resolve(mergePath);
      continue;
    }
    ids.push(a);
  }
  return { mergePath, ids };
}

const argv = process.argv.slice(2);

if (argv.includes("--list") || argv.includes("-l")) {
  for (const id of listServerIds()) console.log(id);
  process.exit(0);
}

if (argv.length === 0 || argv.includes("-h") || argv.includes("--help")) {
  console.error(`Usage: node emit-mcp-json.cjs <server-id> [server-id ...]
       node emit-mcp-json.cjs --merge <path/to/.cursor/mcp.json> <server-id> [...]
       node emit-mcp-json.cjs --list

Emits {"mcpServers":{...}} for Cursor project file .cursor/mcp.json
Server definitions: ${serversDir}
Loads optional ${mcpsEnvPath} for \${VAR} substitution in server JSON strings.`);
  process.exit(argv.length === 0 ? 1 : 0);
}

let mergePath;
let serverIds;
try {
  ({ mergePath, ids: serverIds } = parseArgv(argv));
} catch (e) {
  console.error(e.message || String(e));
  process.exit(1);
}

if (serverIds.length === 0) {
  console.error("Provide at least one <server-id> (see --list).");
  process.exit(1);
}

loadMcpsDotEnv();

let incoming;
try {
  incoming = {};
  for (const id of serverIds) {
    const { key, config } = loadServer(id);
    if (incoming[key]) {
      throw new Error(`Duplicate MCP server key "${key}" in selection.`);
    }
    incoming[key] = config;
  }
} catch (e) {
  console.error(e.message || String(e));
  process.exit(1);
}

let baseServers = {};
if (mergePath) {
  if (fs.existsSync(mergePath)) {
    let doc;
    try {
      doc = JSON.parse(fs.readFileSync(mergePath, "utf8"));
    } catch (e) {
      console.error(`Invalid JSON in merge target: ${mergePath}`);
      process.exit(1);
    }
    if (!doc || typeof doc !== "object" || !doc.mcpServers || typeof doc.mcpServers !== "object") {
      console.error(
        `Merge target must be an object with an mcpServers object: ${mergePath}`
      );
      process.exit(1);
    }
    baseServers = { ...doc.mcpServers };
  }
}

const mcpServers = { ...baseServers, ...incoming };
process.stdout.write(JSON.stringify({ mcpServers }, null, 2) + "\n");
