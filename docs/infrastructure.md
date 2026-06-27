# Infrastructure Services

The development environment relies on a single infrastructure service managed via Docker Compose. It runs as a standalone container with a persistent named volume.

## PostgreSQL 17 (pgvector)

Relational database used by the backend for document metadata, job queues, and application state. The image is `pgvector/pgvector:pg17`, which bundles the `vector` (pgvector) extension used for storing and querying document embeddings — there is no separate vector database.

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

## Vector Storage (pgvector)

Document embeddings (semantic search and RAG) live in PostgreSQL via the `vector` (pgvector) extension — there is no separate vector service. Embeddings are E5 multilingual vectors (384 dimensions, cosine distance) stored across three tables, each scoped to a different domain for physical isolation:

| Table | Scope |
|-------|-------|
| `rag_chunks` | Workspace RAG (resources, docs, knowledge) |
| `indexed_file_chunks` | Files in the assistant's working folder |
| `memory_vectors` | Assistant memory (1-to-1 with memory entries) |

The extension and the tables are created by a backend TypeORM migration (`CreateVectorTables`), following the migration-first schema rule. The models worker reads and writes these tables directly with `psycopg` and the `pgvector` package.

## Shared Document Storage

The `./documents/` directory at the repository root is mounted into both `backend` and `models` containers. It stores uploaded and processed documents, organized by resource/job IDs. This directory is gitignored.

## Named Volumes

| Volume          | Service    | Mount Point                    |
|-----------------|------------|--------------------------------|
| `database-data` | database   | `/var/lib/postgresql/data`     |

These volumes persist data across container restarts. To fully reset them, use the [reset script](scripts.md) or remove them manually with `docker volume rm`.
