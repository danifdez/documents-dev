# Documents Dev

Development monorepo for the **Documents** platform — an intelligent document processing application that combines AI/LLM microservices with a desktop application for document management, extraction, transcription, analysis, and semantic search.

> **Note:** This repository is intended for development environments only. Each service is an independent Git submodule with its own repository and documentation. It is not required to use this orchestration; each service can be installed and run independently.

## Services

| Service | Description | Technologies |
|---------|-------------|-------------|
| **Backend** | REST API and job orchestration | NestJS, TypeORM, PostgreSQL, Socket.io |
| **Frontend** | Desktop application | Electron, Vue 3, Vite, Tailwind CSS |
| **Models** | AI/ML processing workers | Python, Whisper, Mistral-7B, spaCy, Qdrant |

## Quick Start

### Prerequisites

- Docker and Docker Compose (v2 plugin or standalone `docker-compose`)
- Git with submodule support
- Node.js and npm
- Python 3

### Clone

```bash
git clone --recurse-submodules https://github.com/danifdez/documents-dev.git
cd documents-dev
```

### Install and start

The `manage` script handles environment setup, dependency installation, and service lifecycle:

```bash
bash manage install   # configure .env files, install dependencies
bash manage start     # start all services
```

See [docs/scripts.md](docs/scripts.md) for all available commands.

## Documentation

- [Infrastructure](docs/infrastructure.md) — PostgreSQL and Qdrant configuration
- [Docker Compose](docs/docker-compose.md) — Development and E2E compose files
- [Playground](docs/playground.md) — Jupyter experimentation environment
- [Scripts](docs/scripts.md) — `manage` script reference

## License

Apache License 2.0 — see [LICENSE](LICENSE).
