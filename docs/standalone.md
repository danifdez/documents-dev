# Standalone Mode

## Overview

Standalone mode allows the application to run entirely on a local machine without
requiring an external server or Docker. The Electron installer is lightweight
(~150 MB) and downloads the necessary services the first time the user starts a
local workspace.

The installer and the release assets needed for standalone mode are produced by
the `build-release` script at the root of the repository. Every build receives
an explicit product version and produces a `release.json` manifest plus SHA-256
checksums.

## How It Works

When a user opens the application for the first time and has no workspace
configured, they are presented with two options:

- **Standalone** — run everything locally on the machine.
- **Connect to server** — point the app to an existing Documents server on the
  network.

Choosing **Standalone** triggers an automatic setup that downloads and starts all
required services in the background.

## Services Downloaded at First Launch

The following components are downloaded from the Documents release selected by
`release.json` when the user selects standalone mode for the first time. Every
archive is checked against the size and SHA-256 recorded in that manifest.

| Service | Approximate size | Source |
|---------|-----------------|--------|
| Node.js runtime | ~30 MB | Documents release assets |
| Backend (NestJS API) | ~50 MB | GitHub Releases |
| PostgreSQL 17.6 + pgvector + Apache AGE | ~10 MB | Documents release assets |

**Total: depends on the Models variant.** The download happens once and the files are stored in the
application's user-data directory.

Document embeddings (semantic search / RAG) are stored in PostgreSQL via the
`vector` (pgvector) extension — there is no separate vector service. The
embedded PostgreSQL is compiled with pgvector and Apache AGE from pinned,
checksum-verified source archives (`./build-release postgres --version <version>`),
so the server has both extensions out of the box.
The same database includes Apache AGE for the entity graph.

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

1. **PostgreSQL** — relational database for application data, including document
   embeddings via pgvector and the entity graph via Apache AGE (required).
2. **Backend** — REST API that owns and exposes the database state.

The application is ready when the backend reports that it is running. All services
are stopped automatically when the application is closed.

## Managing the Local Server

Once installed, the local server is controlled from **Settings → Local Server**:

- View the installation status of each component.
- Start or stop the local server manually.
- Install or uninstall the AI features (models service).
- Uninstall all local services to free disk space.

## Building Standalone Assets

Run `build-release` from the repository root. The Frontend is copied to an
isolated staging directory and versioned there, so the release build never
modifies `frontend/package.json` or its lockfile:

```bash
# Build the complete standalone target
./build-release all --version 1.0.0

# Build an installer that uses this local release directory at runtime
./build-release all --version 1.0.0 --standalone-local

# Build only the lightweight installer (~150 MB)
./build-release frontend --version 1.0.0

# Build the backend release asset (~50 MB)
./build-release backend --version 1.0.0

# Build the pinned Node.js runtime
./build-release node --version 1.0.0

# Build the models service (CPU variant, ~2 GB)
./build-release models --version 1.0.0 --variant cpu

# Build the models service (GPU/CUDA variant, ~5 GB)
./build-release models --version 1.0.0 --variant cuda
```

The Node source checksum is pinned per target in `release.config.json`;
`NODE_ARCHIVE_SHA256` may override it for a controlled build.
The PostgreSQL build compiles PostgreSQL, pgvector and Apache AGE from the
pinned source archives declared in `release.config.json`. If the host lacks
the native toolchain, it uses the pinned Debian builder image through Docker.
Models compiles its pinned `llama.cpp` revision automatically.

`--standalone-local` keeps the installer lightweight and configures it to copy
the generated Node, Backend, PostgreSQL and Models archives from its local
`release-output/<version>/` directory. The first-run setup verifies and installs
them into the normal user-data paths without GitHub, HTTP or environment
variables. The output directory must remain available on that machine.

### Recommended Release Workflow

1. Build each component on a host matching its target platform.
2. Run `./build-release verify --version <version>` against the assembled
   `release-output/<version>/` directory.
3. Upload the complete release directory without changing its relative paths.
4. Distribute the installer from `release-output/<version>/installers/`.

The installer itself is small because Node.js, PostgreSQL, Backend and Models are
fetched from the release channel at runtime; only the Electron application is
bundled in the installer.

## Supported Build Target

| Platform | Architecture |
|----------|-------------|
| Linux | x64 |

Linux arm64, Windows, and macOS remain planned targets. They are not considered
standalone-capable until native Backend, PostgreSQL, Models, and Frontend assets
pass the complete release verification on that target.
