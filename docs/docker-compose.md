# Docker Compose

The development environment uses Docker Compose to manage infrastructure services. Application services (backend, frontend, models) run locally using the `manage` script.

## Development (`docker-compose.yml`)

Starts the infrastructure dependencies shared by all application services.

### Services

| Service | Image | Port(s) | Description |
|---------|-------|---------|-------------|
| `database` | `postgres:17.6` | 5432 | PostgreSQL relational database |
| `qdrant` | `qdrant/qdrant:v1.14.1` | 6333, 6334 | Vector database for embeddings |

### Volumes

| Volume | Service | Mount |
|--------|---------|-------|
| `database-data` | database | `/var/lib/postgresql/data` |
| `qdrant_data` | qdrant | `/qdrant/storage` |

Volumes persist data across container restarts. To remove them manually:

```bash
docker volume rm documents_database-data documents_qdrant_data
```

### Usage

The `manage start` command starts the infrastructure automatically. To manage it directly:

```bash
docker compose up -d         # start in the background
docker compose down          # stop containers (volumes are preserved)
docker compose logs database
docker compose logs qdrant
```

## E2E Testing (`docker-compose.e2e.yml`)

Launches an isolated environment for end-to-end tests using separate ports to avoid conflicts with a running development environment.

### Services

| Service | Port(s) | Notes |
|---------|---------|-------|
| `database-e2e` | 5433 | PostgreSQL, database `documents_e2e` |
| `qdrant-e2e` | 6334 | Qdrant vector database |
| `backend-e2e` | 3000, 9229 | Built from `backend/Dockerfile` |
| `models-e2e` | — | Built from `models/Dockerfile` |
| `frontend-e2e` | — | Runs the E2E test suite (`tests/Dockerfile`) |

The frontend service waits for the backend health check (`GET /`) to pass before running tests.

### Usage

```bash
docker compose -f docker-compose.e2e.yml up --build

# View logs
docker compose -f docker-compose.e2e.yml logs <service-name>
```

## Environment Variables

Both compose files read environment variables from the `.env` file at the repository root. Copy the provided example and adjust as needed:

```bash
cp .env.example .env
```

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_HOST` | `localhost` | PostgreSQL host |
| `POSTGRES_PORT` | `5432` | PostgreSQL port |
| `POSTGRES_DB` | `documents` | Database name |
| `POSTGRES_USER` | `postgres` | Database user |
| `POSTGRES_PASSWORD` | `example` | Database password |
| `AUTH_ENABLED` | `false` | Enable JWT authentication |
| `JWT_SECRET` | `change-me-in-production` | JWT signing secret |
| `OFFLINE_ENABLED` | `false` | Enable offline/cache support |
| `OFFLINE_FILE_SIZE_LIMIT` | `10485760` | Max cached file size (bytes) |

> **Security note:** Change `POSTGRES_PASSWORD` and `JWT_SECRET` before running in any non-local environment.

The `manage install` command configures `.env` files for all services interactively. See [scripts.md](scripts.md) for details.
