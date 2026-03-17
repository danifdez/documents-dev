# Documents dev — Development Environment

Enterprise-scale intelligent document processing platform. Combines AI/LLM microservices with a desktop application for document management, extraction, analysis, and semantic search.

Note: This repository and the Docker Compose orchestration configuration are intended for development environments only and to simplify running the services together. It is not required to use this composition to install the services; each service can be installed and deployed independently following its own instructions.

## Architecture

The project is a monorepo with three main services as Git submodules, orchestrated with Docker Compose:

```
documents-dev/
├── backend/              # NestJS API service (Git submodule)
├── frontend/             # Electron + Vue desktop app (Git submodule)
├── models/               # Python AI/ML microservices (Git submodule)
├── playground/           # Jupyter notebooks for experimentation
├── documents/            # Processed document storage
├── docker-compose.yml    # Development environment
├── docker-compose.e2e.yml # End-to-end testing
└── reset-dev.sh          # Development reset script
```

### Tech Stack

| Service | Technologies |
|---------|-------------|
| **Backend** | NestJS, TypeORM, PostgreSQL 17.6, Socket.io |
| **Frontend** | Electron, Vue 3, Vite, Tailwind CSS v4, TipTap |
| **Models** | Python 3.11, Mistral-7B (llama-cpp), spaCy, sentence-transformers, Qdrant |
| **Playground** | Python 3.12, Jupyter Notebook |

### Data Flow

Documents flow through a job queue in PostgreSQL. The backend orchestrates jobs and the models service processes them asynchronously. Embeddings are stored in Qdrant for semantic search, and real-time notifications are delivered via WebSocket.

## Features

- **Multi-format ingestion**: PDF, DOC, DOCX, TXT, HTML
- **Extraction and normalization** to HTML
- **Automatic language detection**
- **Multi-language translation**
- **Summarization** with LLM (Mistral-7B)
- **Named entity extraction** (NER with spaCy): persons, organizations, locations
- **Semantic search** with vector embeddings (BAAI/bge-small-en-v1.5)
- **RAG** (Retrieval-Augmented Generation): question answering over documents
- **Keyword and key point extraction**
- **Real-time notifications** via WebSocket
- **Modular job orchestration** extensible with custom types and processors

## Installation

### Prerequisites

- Docker and Docker Compose
- Git (with submodule support)

### Clone the Repository

```bash
git clone --recurse-submodules https://github.com/danifdez/documents-dev.git
cd documents-dev
```

### Start All Services

```bash
docker compose up --build
```

This builds and launches the backend, frontend, models, and dependencies (PostgreSQL, Qdrant).

### Ports

| Service | Port |
|---------|------|
| Backend API | 3000 |
| Backend Debug | 9229 |
| PostgreSQL | 5432 |
| Qdrant | 6333 |
| Playground (Jupyter) | 8888 |

## Usage

### Electron App

Start the app locally. To open DevTools: `Ctrl+Shift+I` (Windows/Linux) or `Cmd+Opt+I` (Mac).

### Service Logs

```bash
docker compose logs <service-name>
```

### Connect to PostgreSQL

```bash
psql -h localhost -p 5432 -U postgres -d documents
```

Credentials: user `postgres`, password `example`.

### Connect to Qdrant

```bash
curl http://localhost:6333/collections
```

See the [Qdrant documentation](https://qdrant.tech/documentation/) for more details.

### Document Storage

Uploaded and processed documents are stored in `documents/`, organized by resource/job IDs. Each subfolder contains normalized content and metadata.

### AI Models

Language models and embeddings are stored in `models/models/` and `playground/models/`. Main configuration in `models/config.py`:

- **LLM**: Mistral-7B-Instruct-v0.3 (quantized GGUF)
- **Embeddings**: BAAI/bge-small-en-v1.5
- **Context**: 32,768 tokens
- **RAG**: 5 results, 1000 max tokens by default

## Playground

Experimentation environment with Jupyter for prototyping document processing workflows.

```bash
docker compose up playground
```

Access the web interface at http://localhost:8888.

## Testing

### End-to-End Tests

```bash
docker compose -f docker-compose.e2e.yml up --build
```

Launches isolated containers with separate ports (PostgreSQL on 5433, Qdrant on 6334). Backend and frontend wait for healthy dependencies before running tests.

### E2E Test Logs

```bash
docker compose -f docker-compose.e2e.yml logs <service-name>
```

## Development Reset

To reset the project to a clean state (local development only):

```bash
bash ./reset-dev.sh --yes
```

This deletes documents, PostgreSQL tables, Qdrant collections, frontend config (`~/.config/documents-frontend`), and re-runs migrations and seeders. **Destructive operation**: use with care.

## License

This project is licensed under the Apache License, Version 2.0. See the LICENSE file for details.
