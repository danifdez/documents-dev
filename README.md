# documents-dev

## Overview

documents-dev is a monorepo for intelligent document processing and search, designed for enterprise-scale workflows. It consists of three main services:

- **backend/**: A NestJS API for job orchestration, resource management, and real-time notifications via WebSocket.
- **models/**: Python microservices for document extraction, language detection, summarization, translation, and vector search.
- **frontend/**: An Electron + Vue desktop app for user interaction, built with Vite and Tailwind.

The system supports multi-format document ingestion (PDF, DOC, TXT, HTML), automated extraction and normalization, language detection, semantic search, and real-time updates. Data flows between services using MongoDB for job/resource state, Qdrant for vector search, and WebSocket for notifications.

All services can be run independently or together via Docker Compose for streamlined development and deployment.

Additionally, the repository includes a **playground/** project for running experiments, prototyping, and testing document processing workflows in isolation.

## Features

- Multi-format document ingestion: PDF, DOC, TXT, HTML
- Automated extraction and normalization to HTML
- Language detection and translation
- Entity extraction and summarization
- Semantic search with vector embeddings
- Real-time notifications via WebSocket
- Modular job orchestration and resource management
- Extensible architecture for custom job types and processors
- Experimentation and prototyping in playground/

## Installation

### Run All Services

To start all services together, use Docker Compose from the repository root:

```bash
docker-compose up --build
```

This will build and launch the backend, frontend, models, and playground containers. You can access the Electron app locally and interact with all features.

### Run End-to-End Tests

To run the full end-to-end test suite, use the dedicated Docker Compose file:

```bash
docker-compose -f docker-compose.e2e.yml up --build
```

This will start isolated containers for MongoDB, Qdrant, backend, models, and frontend (in testing mode). The backend and frontend will wait for healthy dependencies before starting tests. All test results and logs will be available in the container output.

## Getting Started

### Electron App

Start the Electron app via Docker Compose or locally. To open DevTools, use `Ctrl+Shift+I` (Windows/Linux) or `Cmd+Opt+I` (Mac) inside the app window.

### Viewing Docker Logs

To view logs for any service, run:

```bash
docker-compose logs <service-name>
```

For end-to-end tests:

```bash
docker-compose -f docker-compose.e2e.yml logs <service-name>
```

### Connecting to Qdrant

Qdrant runs on port 6333 (or 6334 for e2e). Use the [Qdrant REST API](https://qdrant.tech/documentation/) or [Qdrant UI](https://github.com/qdrant/qdrant-ui) to inspect and query vectors:

```bash
curl http://localhost:6333/collections
```

### Connecting to MongoDB

MongoDB runs on port 27017 (or 27018 for e2e). Use MongoDB Compass or the CLI:

```bash
mongosh --host localhost --port 27017
```

Credentials: username `root`, password `example`.

### Using the Playground

The `playground/` folder contains notebooks and scripts for experiments. It runs a Jupyter notebook server, allowing you to execute notebooks either via the web interface or by connecting a notebook client to the running server.

### Document Storage

Uploaded and processed documents are stored in the `documents/` folder, organized by resource/job IDs. Each subfolder contains normalized content and metadata.

### AI Model Storage

Large language models and embeddings are stored in `models/models/` and `playground/models/`. These are used for extraction, summarization, and semantic search tasks.

## License

This project is licensed under the Apache License, Version 2.0. See the LICENSE file for details.
