# Standalone Mode

## Overview

Standalone mode allows the application to run entirely on a local machine without
requiring an external server or Docker. The Electron installer is lightweight
(~150 MB) and downloads the necessary services the first time the user starts a
local workspace.

The installer and the release assets needed for standalone mode are produced by
the `build-standalone` script at the root of the repository.

## How It Works

When a user opens the application for the first time and has no workspace
configured, they are presented with two options:

- **Standalone** — run everything locally on the machine.
- **Connect to server** — point the app to an existing Documents server on the
  network.

Choosing **Standalone** triggers an automatic setup that downloads and starts all
required services in the background.

## Services Downloaded at First Launch

The following components are downloaded from their official sources when the user
selects standalone mode for the first time. No additional action is required.

| Service | Approximate size | Source |
|---------|-----------------|--------|
| Backend (NestJS API) | ~50 MB | GitHub Releases |
| PostgreSQL 17.6 | ~200 MB | repo1.maven.org (zonky binaries) |
| Qdrant 1.14.1 | ~40 MB | github.com/qdrant/qdrant |
| Neo4j 5 | ~60 MB | dist.neo4j.org |

**Total: ~350 MB.** The download happens once and the files are stored in the
application's user-data directory.

## Optional AI Features

The AI/ML processing capabilities (transcription, summarisation, translation,
semantic search) are provided by a separate models service. This component is
**not installed by default** due to its size:

| Variant | Approximate size | Description |
|---------|-----------------|-------------|
| CPU | ~2 GB | Compatible with any machine |
| GPU (CUDA) | ~5 GB | Requires an NVIDIA GPU; significantly faster |

AI features can be installed later from **Settings → Local Server → AI Features**.
The application detects whether a compatible GPU is available and offers the
appropriate variant automatically.

## Start-up Sequence

When a local workspace is started the services are launched in this order:

1. **PostgreSQL** — relational database for application data (required).
2. **Qdrant** — vector database for semantic search (started if installed).
3. **Neo4j** — graph database for knowledge relationships (started if installed).
4. **Backend** — REST API that connects the frontend to the databases.

The application is ready when the backend reports that it is running. All services
are stopped automatically when the application is closed.

## Managing the Local Server

Once installed, the local server is controlled from **Settings → Local Server**:

- View the installation status of each component.
- Start or stop the local server manually.
- Install or uninstall the AI features (models service).
- Uninstall all local services to free disk space.

## Building Standalone Assets

To produce the Electron installer and the backend release asset, run
`build-standalone` from the repository root:

```bash
# Build backend asset and Electron installer
./build-standalone all

# Build only the lightweight installer (~150 MB)
./build-standalone installer

# Build the backend release asset (~50 MB)
./build-standalone backend

# Build the models service (CPU variant, ~2 GB)
./build-standalone models-cpu

# Build the models service (GPU/CUDA variant, ~5 GB)
./build-standalone models-gpu
```

### Recommended Release Workflow

1. Run `./build-standalone backend` to produce the backend archive.
2. Upload the files in `release-assets/` to a GitHub Release.
3. Run `./build-standalone installer` to produce the platform installer.
4. Distribute the installer found in `frontend/out/make/`.

The installer itself is small because the databases and backend are fetched at
runtime directly from their official sources or from GitHub Releases — nothing
except the Electron shell is bundled in the installer.

## Supported Platforms

| Platform | Architecture |
|----------|-------------|
| Linux | x64, arm64 |
| macOS | x64 (Intel), arm64 (Apple Silicon) |
| Windows | x64 |
