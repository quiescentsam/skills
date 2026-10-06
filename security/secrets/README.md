# Secrets

Local [OpenBao](https://openbao.org/) on Rancher Desktop, in namespace `security-secrets`. Kubernetes namespace names cannot contain `_`, so this is not `security_secrets`.

OpenBao is the source of truth. [External Secrets Operator](https://external-secrets.io/) logs in with its own Kubernetes service account and copies selected values into ordinary Kubernetes Secrets. A workload reads those with `secretKeyRef` or `envFrom`. It does not talk to OpenBao itself.

The UI and API are published on [http://localhost:18200](http://localhost:18200). The UI is [http://localhost:18200/ui](http://localhost:18200/ui). This is a local install: the listener inside the cluster does not use TLS, and the root token is stored in `security/secrets/.bao-init.json`, which is gitignored.

```bash
bash security/secrets/start.sh
bash security/secrets/publish-secret.sh default demo-credentials password=change-me
kubectl apply -f security/secrets/example-workload.yaml
bash security/secrets/stop.sh
bash security/secrets/cleanup.sh
```

`start` installs OpenBao chart `0.30.1` and External Secrets chart `2.11.0`. OpenBao runs as a single Raft node on a `local-path` volume. The first run initializes and unseals it, enables the KV v2 engine at `secret/`, and configures Kubernetes auth so External Secrets can read it. Later runs unseal the same volume. The port-forward is `18200` to the OpenBao service.

`publish-secret.sh` writes `key=value` pairs to `secret/workloads/<namespace>/<secret-name>` and creates an `ExternalSecret` of the same name. That object materializes a Kubernetes Secret. Re-run the script to change a value; running pods keep the previous environment until they restart.

`stop` ends the port-forward and scales OpenBao and External Secrets to zero. The namespace, data volume, and init file remain. The next `start` unseals the same data.

`cleanup` removes the port-forward, both Helm releases, the `security-secrets` namespace, the External Secrets CRDs, and `.bao-init.json`.

A workload mounts the synced Secret like this:

```yaml
env:
  - name: DEMO_PASSWORD
    valueFrom:
      secretKeyRef:
        name: demo-credentials
        key: password
```

`example-workload.yaml` is that pattern against `default/demo-credentials`.
