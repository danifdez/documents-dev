# Infrastructure Services

The development environment relies on two infrastructure services managed via Docker Compose. Both run as standalone containers with persistent named volumes.

## PostgreSQL 17.6

Relational database used by the backend for document metadata, job queues, and application state.

|              | Development          | E2E Testing            |
|--------------|----------------------|------------------------|
| **Host port**| 5432                 | 5433                   |
| **Database** | `documents`          | `documents_e2e`        |
| **User**     | `postgres`           | `postgres`             |
| **Password** | `example`            | `example`              |
| **Volume**   | `database-data`      | —                      |

### Connect Manually

```bash
psql -h localhost -p 5432 -U postgres -d documents
```

### View Logs

```bash
docker compose logs database
```

## Qdrant v1.14.1

Vector database used for storing and querying document embeddings (semantic search).

|              | Development          | E2E Testing            |
|--------------|----------------------|------------------------|
| **HTTP port**| 6333                 | 6334                   |
| **gRPC port**| 6334                 | —                      |
| **Volume**   | `qdrant_data`        | —                      |

### Query Collections

```bash
curl http://localhost:6333/collections
```

### View Logs

```bash
docker compose logs qdrant
```

### Documentation

See the [Qdrant official documentation](https://qdrant.tech/documentation/) for API details.

## Shared Document Storage

The `./documents/` directory at the repository root is mounted into both `backend` and `models` containers. It stores uploaded and processed documents, organized by resource/job IDs. This directory is gitignored.

## Named Volumes

| Volume          | Service    | Mount Point                    |
|-----------------|------------|--------------------------------|
| `database-data` | database   | `/var/lib/postgresql/data`     |
| `qdrant_data`   | qdrant     | `/qdrant/storage`              |

These volumes persist data across container restarts. To fully reset them, use the [reset script](scripts.md) or remove them manually with `docker volume rm`.
