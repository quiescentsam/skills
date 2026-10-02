# Keycloak

Local Keycloak on Rancher Desktop, in namespace `security-keycloak`. Kubernetes namespace names cannot contain `_`, so this is not `security_keycloak`.

The service is published on [http://localhost:18080](http://localhost:18080), the port the Jarvis auth server already uses. The admin console is [http://localhost:18080/admin](http://localhost:18080/admin). The bootstrap user is `admin` / `admin`.

```bash
bash security/keycloak/start.sh
bash security/keycloak/setup-realm.sh
bash security/keycloak/stop.sh
bash security/keycloak/cleanup.sh
```

`start` applies the manifest, scales the deployment to one, and port-forwards `18080` to the Keycloak service. Run `setup-realm.sh` after that. It creates the `mcp-gateway` realm Jarvis expects: clients `mcp-gateway-web` and `mcp-gateway-m2m` use the secrets already stored in `jarvis/registry-env`, and user `admin` / `admin` is placed in group `jarvis-registry-admin`.

`stop` ends that forward and scales the deployment to zero. The namespace and data volume remain.

`cleanup` stops the port-forward and deletes the entire `security-keycloak` namespace, including the deployment, service, secret, persistent volume claim, and all Keycloak data.
