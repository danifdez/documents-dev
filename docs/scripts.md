# Scripts

## manage

The `manage` script is the primary development tool for the repository. It handles environment setup, service lifecycle, and data management.

### Requirements

- **Docker** and **Docker Compose** (v2 plugin or standalone `docker-compose`) — auto-detected
- **Node.js** and **npm** — for backend and frontend
- **Python 3** and `python3 -m venv` — for models and playground
- `curl` — for Qdrant operations
- `pg_dump` / `psql` — for `export` and `import` commands (must be available on the host)

### Commands

#### `install`

Sets up the full development environment from scratch.

```bash
bash manage install
```

Steps performed:

1. Interactively configures `.env` files for the root, backend, models, and frontend
2. Starts PostgreSQL and Qdrant via Docker Compose
3. Runs backend database migrations and seeders
4. Creates a Python virtual environment and installs dependencies for models
5. Installs frontend npm dependencies

#### `start`

Starts all services using locally installed dependencies.

```bash
bash manage start
```

- Starts PostgreSQL and Qdrant (Docker)
- Launches the backend (`npm run start:dev`) in the background
- Launches the models worker (`python jobs.py`) in the background
- Saves process IDs to `.pids` and rotates log files if they exceed 10 MB

The frontend is not started automatically; run it separately:

```bash
cd frontend && npm start
```

#### `stop`

Stops all running services.

```bash
bash manage stop
```

Kills tracked process groups from `.pids`, cleans up orphan processes, and stops the Docker containers.

#### `reset [--yes]`

Permanently deletes all project data and re-initializes the environment.

```bash
bash manage reset          # prompts for confirmation (type RESET)
bash manage reset --yes    # skips confirmation
```

Actions performed:

1. Stops all running services
2. Drops all PostgreSQL tables (`DROP SCHEMA public CASCADE`)
3. Deletes all files in `./documents/`
4. Deletes all Qdrant collections
5. Removes the frontend user configuration (`~/.config/documents-frontend`)
6. Re-runs database migrations

> **Destructive operation** — use with care.

#### `playground:start` / `playground:stop`

Starts or stops the Jupyter notebook server. See [playground.md](playground.md) for details.

```bash
bash manage playground:start
bash manage playground:stop
```

#### `logs <service>`

Tails the log file for a running service.

```bash
bash manage logs backend
bash manage logs models
bash manage logs playground
```

Log files are stored as hidden files in the repository root (`.backend.log`, `.models.log`, `.playground.log`). They are rotated automatically at 10 MB, keeping up to 3 backups in `.logs/`.

#### `export [output_file]`

Creates a compressed backup of the PostgreSQL database and the `documents/` folder.

```bash
bash manage export                              # auto-named backup_YYYYMMDD_HHMMSS.tar.gz
bash manage export /path/to/my_backup.tar.gz
```

The archive contains `database.sql`, the `documents/` directory, and `backup_metadata.json`.

#### `import <backup_file>`

Restores a backup created by `export`.

```bash
bash manage import backup_20260101_120000.tar.gz
```

> **Destructive operation** — replaces the current database and documents. Prompts for confirmation (type IMPORT).

#### `help`

Displays usage information.

```bash
bash manage help
```
