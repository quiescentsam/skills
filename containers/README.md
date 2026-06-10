# Local dev containers

Docker Compose stacks for backing services used by projects in this repo. Each service lives in its own subdirectory so you can start only what you need.

**Requirements:** [Docker Desktop](https://www.docker.com/products/docker-desktop/) (or Docker Engine + Compose plugin).

## Services

| Service | Directory | Host port | Used by |
|---------|-----------|-----------|---------|
| Redis | [`redis/`](redis/) | `6380` | Maverick MCP cache (`mcps/maverick-mcp/.env`) |

Port `6380` is used instead of the default `6379` so this Redis does not clash with other local stacks (for example Langfuse) that may already bind `6379`.

## Redis

Matches Maverick MCP `.env` Redis settings:

```env
REDIS_HOST=localhost
REDIS_PORT=6380
REDIS_DB=0
REDIS_PASSWORD=
REDIS_SSL=false
```

### Start

```bash
cd containers/redis
docker compose up -d
```

### Stop

```bash
cd containers/redis
docker compose down
```

### Verify

```bash
docker compose -f containers/redis/docker-compose.yml ps
redis-cli -h localhost -p 6380 ping   # expect PONG
```

Data is persisted in the `redis_redis-data` Docker volume.

### Connect with Redis Insight

[Redis Insight](https://redis.io/insight/) is a desktop GUI for browsing keys, running commands, and inspecting memory. Install it on macOS with Homebrew (see [`laptop/mac_setup.sh`](../laptop/mac_setup.sh)):

```bash
brew install --cask redis-insight
```

Start Redis first (`docker compose up -d` in `containers/redis`), then open **Redis Insight** and add a database connection with these values:

| Field | Value |
|-------|-------|
| Host | `localhost` (or `127.0.0.1`) |
| Port | `6380` |
| Database index | `0` |
| Username | *(leave empty)* |
| Password | *(leave empty)* |
| Use TLS | off |

In the UI: **+ Add Redis database** → **Add database manually** → fill in the fields above → **Add Redis Database**.

If connection fails, confirm the container is up:

```bash
docker compose -f containers/redis/docker-compose.yml ps
redis-cli -h localhost -p 6380 ping
```

## Adding a service

Create a new subdirectory under `containers/` with its own `docker-compose.yml`, document the host port and matching env vars here, and avoid binding well-known ports if another stack on the machine may already use them.
