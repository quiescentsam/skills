#!/usr/bin/env bash
# Create the mcp-gateway realm Jarvis uses for login.
# Run this after security/keycloak/start.sh.
#   bash security/keycloak/setup-realm.sh
set -euo pipefail

KEYCLOAK_URL="${KEYCLOAK_URL:-http://127.0.0.1:18080}"
JARVIS_NAMESPACE="${JARVIS_NAMESPACE:-jarvis}"
JARVIS_SECRET="${JARVIS_SECRET:-registry-env}"
REALM="mcp-gateway"
REALM_USER="admin"
REALM_PASSWORD="admin"

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl is required." >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required." >&2
  exit 1
fi

echo "==> Waiting for Keycloak at ${KEYCLOAK_URL}"
ready=0
for _ in $(seq 1 60); do
  if curl -sf -o /dev/null "${KEYCLOAK_URL}/realms/master"; then
    ready=1
    break
  fi
  sleep 1
done
if [[ "$ready" != 1 ]]; then
  echo "Keycloak is not reachable. Start it with: bash security/keycloak/start.sh" >&2
  exit 1
fi

web_secret="$(kubectl -n "$JARVIS_NAMESPACE" get secret "$JARVIS_SECRET" -o jsonpath='{.data.KEYCLOAK_CLIENT_SECRET}' | base64 -d)"
m2m_secret="$(kubectl -n "$JARVIS_NAMESPACE" get secret "$JARVIS_SECRET" -o jsonpath='{.data.KEYCLOAK_M2M_CLIENT_SECRET}' | base64 -d)"
if [[ -z "$web_secret" || -z "$m2m_secret" ]]; then
  echo "Secret ${JARVIS_NAMESPACE}/${JARVIS_SECRET} is missing Keycloak client secrets." >&2
  exit 1
fi

KEYCLOAK_URL="$KEYCLOAK_URL" \
REALM="$REALM" \
REALM_USER="$REALM_USER" \
REALM_PASSWORD="$REALM_PASSWORD" \
WEB_SECRET="$web_secret" \
M2M_SECRET="$m2m_secret" \
python3 - <<'PY'
import json
import os
import urllib.error
import urllib.parse
import urllib.request

base = os.environ["KEYCLOAK_URL"].rstrip("/")
realm = os.environ["REALM"]
realm_user = os.environ["REALM_USER"]
realm_password = os.environ["REALM_PASSWORD"]
web_secret = os.environ["WEB_SECRET"]
m2m_secret = os.environ["M2M_SECRET"]

groups = (
    "jarvis-registry-admin",
    "jarvis-registry-power-user",
    "jarvis-registry-user",
    "jarvis-registry-read-only",
)
redirect_uris = [
    "http://127.0.0.1:18888/oauth2/callback/keycloak",
    "http://localhost:18888/oauth2/callback/keycloak",
]


def request(method, path, token=None, body=None, ok=(200, 201, 204)):
    data = None if body is None else json.dumps(body).encode()
    headers = {"Accept": "application/json"}
    if body is not None:
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(base + path, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            raw = resp.read().decode()
            return resp.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors="replace")
        if exc.code not in ok:
            raise SystemExit(f"{method} {path} failed: HTTP {exc.code} {detail[:400]}")
        return exc.code, None


def form(path, fields):
    data = urllib.parse.urlencode(fields).encode()
    req = urllib.request.Request(
        base + path,
        data=data,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode())
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors="replace")
        raise SystemExit(f"POST {path} failed: HTTP {exc.code} {detail[:400]}")


token = form(
    "/realms/master/protocol/openid-connect/token",
    {
        "client_id": "admin-cli",
        "username": "admin",
        "password": "admin",
        "grant_type": "password",
    },
)["access_token"]

_, realms = request("GET", "/admin/realms", token)
if not any(item.get("realm") == realm for item in realms or []):
    request(
        "POST",
        "/admin/realms",
        token,
        {"realm": realm, "enabled": True, "sslRequired": "none", "displayName": "MCP Gateway"},
    )
    print(f"Created realm {realm}")
else:
    print(f"Realm {realm} already exists")

_, scopes = request("GET", f"/admin/realms/{realm}/client-scopes", token)
groups_scope = next((item for item in scopes or [] if item.get("name") == "groups"), None)
if groups_scope is None:
    request(
        "POST",
        f"/admin/realms/{realm}/client-scopes",
        token,
        {
            "name": "groups",
            "protocol": "openid-connect",
            "attributes": {
                "include.in.token.scope": "false",
                "display.on.consent.screen": "false",
            },
        },
    )
    _, scopes = request("GET", f"/admin/realms/{realm}/client-scopes", token)
    groups_scope = next(item for item in scopes if item.get("name") == "groups")
scope_id = groups_scope["id"]
_, mappers = request("GET", f"/admin/realms/{realm}/client-scopes/{scope_id}/protocol-mappers/models", token)
if not any(item.get("name") == "groups" for item in mappers or []):
    request(
        "POST",
        f"/admin/realms/{realm}/client-scopes/{scope_id}/protocol-mappers/models",
        token,
        {
            "name": "groups",
            "protocol": "openid-connect",
            "protocolMapper": "oidc-group-membership-mapper",
            "config": {
                "claim.name": "groups",
                "full.path": "false",
                "id.token.claim": "true",
                "access.token.claim": "true",
                "userinfo.token.claim": "true",
            },
        },
    )
request("PUT", f"/admin/realms/{realm}/default-default-client-scopes/{scope_id}", token, ok=(200, 201, 204, 409))

def ensure_group(name):
    _, found = request("GET", f"/admin/realms/{realm}/groups?search={urllib.parse.quote(name)}&exact=true", token)
    match = next((item for item in found or [] if item.get("name") == name), None)
    if match:
        return match["id"]
    request("POST", f"/admin/realms/{realm}/groups", token, {"name": name})
    _, found = request("GET", f"/admin/realms/{realm}/groups?search={urllib.parse.quote(name)}&exact=true", token)
    return next(item["id"] for item in found if item.get("name") == name)

group_ids = {name: ensure_group(name) for name in groups}

def ensure_client(client_id, body):
    _, found = request("GET", f"/admin/realms/{realm}/clients?clientId={urllib.parse.quote(client_id)}", token)
    match = next((item for item in found or [] if item.get("clientId") == client_id), None)
    if match is None:
        request("POST", f"/admin/realms/{realm}/clients", token, body)
        _, found = request("GET", f"/admin/realms/{realm}/clients?clientId={urllib.parse.quote(client_id)}", token)
        match = next(item for item in found if item.get("clientId") == client_id)
        print(f"Created client {client_id}")
    else:
        body["id"] = match["id"]
        request("PUT", f"/admin/realms/{realm}/clients/{match['id']}", token, body)
        print(f"Updated client {client_id}")
    request(
        "PUT",
        f"/admin/realms/{realm}/clients/{match['id']}/default-client-scopes/{scope_id}",
        token,
        ok=(200, 201, 204, 409),
    )
    return match["id"]

web_client = {
    "clientId": "mcp-gateway-web",
    "enabled": True,
    "protocol": "openid-connect",
    "publicClient": False,
    "secret": web_secret,
    "standardFlowEnabled": True,
    "directAccessGrantsEnabled": False,
    "serviceAccountsEnabled": False,
    "redirectUris": redirect_uris,
    "webOrigins": ["+"],
    "attributes": {
        "post.logout.redirect.uris": "http://127.0.0.1:19080/*##http://localhost:19080/*",
    },
}
m2m_client = {
    "clientId": "mcp-gateway-m2m",
    "enabled": True,
    "protocol": "openid-connect",
    "publicClient": False,
    "secret": m2m_secret,
    "standardFlowEnabled": False,
    "directAccessGrantsEnabled": False,
    "serviceAccountsEnabled": True,
    "redirectUris": [],
    "webOrigins": [],
}
ensure_client("mcp-gateway-web", web_client)
ensure_client("mcp-gateway-m2m", m2m_client)

query = urllib.parse.urlencode({"username": realm_user, "exact": "true"})
_, users = request("GET", f"/admin/realms/{realm}/users?{query}", token)
user = next((item for item in users or [] if item.get("username") == realm_user), None)
if user is None:
    request(
        "POST",
        f"/admin/realms/{realm}/users",
        token,
        {
            "username": realm_user,
            "enabled": True,
            "email": "admin@localhost",
            "emailVerified": True,
            "firstName": "Admin",
            "lastName": "User",
            "credentials": [{"type": "password", "value": realm_password, "temporary": False}],
        },
    )
    _, users = request("GET", f"/admin/realms/{realm}/users?{query}", token)
    user = next(item for item in users if item.get("username") == realm_user)
    print(f"Created user {realm_user}")
else:
    request(
        "PUT",
        f"/admin/realms/{realm}/users/{user['id']}/reset-password",
        token,
        {"type": "password", "value": realm_password, "temporary": False},
    )
    print(f"User {realm_user} already exists")

request(
    "PUT",
    f"/admin/realms/{realm}/users/{user['id']}/groups/{group_ids['jarvis-registry-admin']}",
    token,
    ok=(200, 201, 204, 409),
)
print(f"Realm {realm} is ready. Sign in to Jarvis as {realm_user}.")
PY

unset web_secret m2m_secret
