# Langfuse

Local [Langfuse](https://langfuse.com/self-hosting/deployment/docker-compose) v4 on Docker Compose: web, worker, Postgres, ClickHouse, Redis, and MinIO. The UI is [http://localhost:3100](http://localhost:3100). Every published port is bound to `127.0.0.1`.

Host ports are shifted off the upstream defaults. `3000`, `5432`, `6379`, and `9090` are often already taken on this machine, including by an SSH tunnel, and the repo Redis in `containers/redis` uses `6380`.

```bash
bash observability/langfuse/start.sh
bash observability/langfuse/stop.sh
bash observability/langfuse/cleanup.sh
```

`start` writes `observability/langfuse/.env` the first time, starts the stack, and waits until `http://localhost:3100/api/public/health` returns 200. That file holds the generated passwords, the login, and the project API keys. Langfuse creates the `local` organization, the `local` project, and user `admin@langfuse.local` when those records are not already there. There is no built-in admin account beyond that.

`stop` removes the containers and keeps the volumes and `.env`.

`cleanup` removes the containers and volumes. `.env` stays, so the next start recreates the same user and API keys. Delete `.env` as well if you want new secrets. Do not delete `.env` while volumes still exist: Postgres and the encryption key would no longer match.

Give Docker Desktop at least 8 GB of memory. ClickHouse and the Langfuse images are large; the first start spends most of its time pulling them.

## Ports

| Host port | Container port | Service |
|-----------|----------------|---------|
| 3100 | 3000 | Langfuse UI |
| 3130 | 3030 | Langfuse worker |
| 5433 | 5432 | Postgres |
| 6381 | 6379 | Redis (the repo Redis in `containers/redis` stays on 6380) |
| 8124 | 8123 | ClickHouse HTTP |
| 9001 | 9000 | ClickHouse native |
| 9190 | 9000 | MinIO API |
| 9191 | 9001 | MinIO console (user `minio`, password `MINIO_ROOT_PASSWORD` in `.env`) |

## Send traces

```bash
export LANGFUSE_HOST=http://localhost:3100
export LANGFUSE_PUBLIC_KEY=pk-lf-...   # LANGFUSE_INIT_PROJECT_PUBLIC_KEY in .env
export LANGFUSE_SECRET_KEY=sk-lf-...   # LANGFUSE_INIT_PROJECT_SECRET_KEY in .env
```

## Upgrade

```bash
bash observability/langfuse/stop.sh
docker compose --project-directory observability/langfuse pull
bash observability/langfuse/start.sh
```
