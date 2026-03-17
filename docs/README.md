# Documents dev — Development Environment

This repository serves as the development monorepo for the Documents platform. It orchestrates multiple services via Docker Compose, providing a unified local development environment and an experimentation playground. It does not contain application code directly — each service lives in its own Git submodule.

## Documentation

- [Infrastructure Services](infrastructure.md) — PostgreSQL, Qdrant, shared volumes, and connection details
- [Playground](playground.md) — Jupyter experimentation environment, notebooks, and dependencies
- [Scripts](scripts.md) — Development utilities (`reset-dev.sh`)

## Project Structure

```
documents-dev/
├── backend/                  # Git submodule — API service
├── frontend/                 # Git submodule — Desktop application
├── models/                   # Git submodule — AI/ML microservices
├── playground/               # Jupyter experimentation environment
├── documents/                # Shared document storage (gitignored)
├── docker-compose.yml        # Development environment
├── docker-compose.e2e.yml    # End-to-end testing environment
├── reset-dev.sh              # Development state reset script
├── .env                      # Docker user context variables
├── .gitmodules               # Submodule definitions
├── .gitignore                # Version control exclusions
└── LICENSE                   # Apache License 2.0
```

## Prerequisites

- **Docker** and **Docker Compose** (v2 plugin or standalone `docker-compose`)
- **Git** with submodule support

## Getting Started

### Clone the Repository

```bash
git clone --recurse-submodules https://github.com/danifdez/documents-dev.git
cd documents-dev
```

### Start All Services

```bash
docker compose up --build
```

This builds and starts the application services (backend, models) and their [infrastructure](infrastructure.md) dependencies (PostgreSQL, Qdrant).

### Port Map

| Service         | Port |
|-----------------|------|
| Backend API     | 3000 |
| Backend Debug   | 9229 |
| PostgreSQL      | 5432 |
| Qdrant HTTP     | 6333 |
| Qdrant gRPC     | 6334 |
| Playground      | 8888 |

## Docker Compose Environments

### Development — `docker-compose.yml`

The default compose file defines five services:

| Service      | Description                                      |
|--------------|--------------------------------------------------|
| `backend`    | Application API. Mounts `./backend` and `./documents` as volumes. Runs as `${UID}:${GID}`. Depends on `database`. |
| `models`     | AI/ML processing. Mounts `./models` and `./documents`. Depends on `qdrant` and `database`. |
| `database`   | PostgreSQL 17.6. Data persisted in a named volume. See [infrastructure](infrastructure.md). |
| `qdrant`     | Qdrant v1.14.1 vector database. See [infrastructure](infrastructure.md). |
| `playground` | Jupyter notebook server. See [playground](playground.md). |

All application services inject the `.env` file and run with `restart: unless-stopped`.

### End-to-End Testing — `docker-compose.e2e.yml`

An isolated environment for running automated tests. Services use the `-e2e` suffix to avoid conflicts with the development stack:

| Service         | Notes                                                    |
|-----------------|----------------------------------------------------------|
| `database-e2e`  | PostgreSQL 17.6 on host port **5433**. Database: `documents_e2e`. |
| `qdrant-e2e`    | Qdrant on host port **6334**.                            |
| `backend-e2e`   | Includes a health check (`curl http://localhost:3000/`). |
| `models-e2e`    | Configured to connect to the e2e database and Qdrant.   |
| `frontend-e2e`  | Runs from `frontend/tests/Dockerfile`. Requires `SYS_ADMIN` capability. Waits for `backend-e2e` to be healthy before starting. |

Run the e2e suite:

```bash
docker compose -f docker-compose.e2e.yml up --build
```

## Environment Configuration

### `.env`

Contains Docker user context variables used to run containers with the host user's UID/GID:

```
UID=1000
GID=1000
WAYLAND_DISPLAY=wayland-0
```

### `.gitignore`

The following paths are excluded from version control:

- `documents/**` — processed document storage
- `playground/**` — notebook outputs, checkpoints, and local models
- `**/__pycache__/**` — Python bytecode cache
- `.github/**` — GitHub workflows

## Git Submodules

The three application services are managed as Git submodules, each tracking their `main` branch:

| Submodule  | Repository                                              |
|------------|---------------------------------------------------------|
| `backend`  | https://github.com/danifdez/documents-backend.git      |
| `frontend` | https://github.com/danifdez/documents-frontend.git     |
| `models`   | https://github.com/danifdez/documents-models.git       |

### Common Commands

```bash
# Initialize and fetch submodules after cloning without --recurse-submodules
git submodule update --init --recursive

# Pull latest changes for all submodules
git submodule update --remote --merge

# Check submodule status
git submodule status
```

Each submodule has its own README with setup instructions and documentation specific to that service.
