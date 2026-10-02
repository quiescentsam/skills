# Authorization

This install (chart **0.2.4**, app `asc0.5.7`) checks two things after login. A **scope** decides whether you may call an API. An **access-control entry** decides whether you may touch that particular agent, MCP server, workflow, skill, or federation.

Sign in at [http://localhost:19080](http://localhost:19080). This local install uses Keycloak. The auth server turns that login into a session cookie holding a JWT.

## Credentials

The dashboard and registry APIs, including `POST /api/v1/agents`, accept only that session cookie. The `Authorization` header is ignored on those routes.

Calls through `/proxy/...` accept only a managed-agent Bearer token. The session cookie is ignored there. A dashboard session cannot be replayed as a proxy token, and a proxy token cannot be used as a dashboard session.

Skill sync-down reads try the session cookie first, then the Bearer token.

## Scopes

The JWT carries groups. If it has no explicit `scope` claim, Jarvis maps those groups to scopes. If the token already lists scopes, that list is used as-is and groups do not add more.

The RBAC middleware matches the HTTP method and path to one required scope. No matching scope returns **403**.

| Group | What it can do |
|-------|----------------|
| `jarvis-registry-admin` | Full access, including share, ACL changes, and system operations |
| `jarvis-registry-power-user` | Create, update, delete, and share agents, servers, and federations |
| `jarvis-registry-user` | Create, update, and delete those resources, but not share them |
| `jarvis-registry-read-only` | Read only |

Registering an agent needs `agents-write`. Listing agents needs `agents-read`. The same split exists for servers, federations, workflows, skills, and models (`*-read`, `*-write`, and `*-share` where sharing is separate).

## Access control

A scope does not make every resource visible. Each resource has its own entries in MongoDB. An entry names a principal and a role.

Principals are a user, a group, or public. A public entry may only be view.

| Role | Bits | Allows |
|------|------|--------|
| Viewer | 1 | View |
| Editor | 3 | View and edit |
| Owner | 15 | View, edit, delete, and share |

The bits are view (1), edit (2), delete (4), and share (8). The creator of an agent is granted **owner** on that agent (`remoteAgent`, `permBits` 15). The same owner grant is used for MCP servers, workflows, skills, and federations. Lists only return resources whose entries include you, one of your groups, or public.

Those roles live in the `accessroles` collection. The chart does not create them. The backend loads the catalog once at startup. `bash registry/jarvis/setup.sh start` runs [seed_access_roles.py](seed_access_roles.py) and restarts the backend when rows were missing. An empty catalog makes registration fail with `No role found for resource_type=remoteAgent, perm_bits=15` before any permission is saved.
